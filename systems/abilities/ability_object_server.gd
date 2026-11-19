extends RefCounted
## Comportements serveur d'un AbilityObject : champs, tourelle, frappe, explosion, portail, balise.
## Appelé par AbilityObject._physics_process (serveur uniquement). Les RPC restent sur l'objet.

const Utility := preload("res://systems/abilities/ability_object_server_utility.gd")
const TICK := 0.25                 ## champs : dégâts / soins tous les TICK s
const MISSILE_RADIUS := 2.5        ## rayon d'explosion d'un missile de frappe (m)
const PORTAL_RADIUS := 1.3

var o: AbilityObject
var _tick_left: float = 0.0
var _fire_left: float = 0.0
var _missile_times: Array[float] = []
var _struck: bool = false
var _teleported: Dictionary = {}   # nœud -> âge du dernier passage


func _init(owner_object: AbilityObject) -> void:
	o = owner_object


## Un pas de simulation selon le type d'objet.
func update(delta: float) -> void:
	match o.kind:
		"grenade":
			if o.age >= float(o.spawn_data["land_time"]):
				_field(delta)
		"frag":
			# Grenade à fragmentation : explose à la fin de la mèche, où qu'elle soit.
			if not _struck and o.age >= float(o.spawn_data["fuse"]):
				_struck = true
				_explode(o._arc_pos(float(o.spawn_data["fuse"])), float(o.spawn_data["radius"]),
						float(o.spawn_data["damage"]), float(o.spawn_data.get("falloff_start", -1.0)))
		"turret":
			_turret(delta)
		"strike":
			_strike()
		"portal":
			_portal()
		"ward":
			_ward(delta)


func _world() -> Node:
	return o.get_parent().get_parent()


func _owner_player() -> Player:
	var players := _world().get_node_or_null("Players")
	return players.get_node_or_null(str(o.owner_id)) as Player if players else null


## Cibles touchables (pas le propriétaire, pas les objets de capacité) dans un rayon.
func _targets_in(center: Vector3, radius: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in o.get_tree().get_nodes_in_group("damageable"):
		var target := node as Node3D
		if target == null or target == o or target is AbilityObject or not target.can_be_hit():
			continue
		if target is Player and (target as Player).get_peer_id() == o.owner_id:
			continue
		if target.global_position.distance_to(center) <= radius:
			result.append(target)
	return result


func _field(delta: float) -> void:
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = TICK
	var center := o._land_pos()
	var radius := maxf(o.ability.radius_m, 1.0)
	if o.ability.damage_per_s > 0.0:
		for target in _targets_in(center, radius):
			target.server_receive_hit(o.ability.damage_per_s * TICK, o.owner_id)
	if o.ability.heal_per_s > 0.0:
		var me := _owner_player()
		if me and not me.health.is_dead and me.global_position.distance_to(center) <= radius:
			me.health.heal(o.ability.heal_per_s * TICK)


func _turret(delta: float) -> void:
	_fire_left -= delta
	if _fire_left > 0.0:
		return
	_fire_left = 60.0 / maxf(o.ability.rpm, 1.0)
	var muzzle := o.global_position + Vector3.UP * 1.4
	var best: Node3D = null
	var best_dist := maxf(o.ability.range_m, 5.0)
	var space := o.get_world_3d().direct_space_state
	for target in _targets_in(o.global_position, best_dist):
		var aim := target.global_position + Vector3.UP * 0.9
		var query := PhysicsRayQueryParameters3D.create(muzzle, aim, 1)
		query.exclude = [o.get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and hit["collider"] != target:
			continue
		var d := muzzle.distance_to(aim)
		if d < best_dist:
			best = target
			best_dist = d
	if best == null:
		return
	best.server_receive_hit(o.ability.damage, o.owner_id)
	o._show_tracer.rpc(muzzle, best.global_position + Vector3.UP * 0.9)


## Moments des missiles (en âge de l'objet) : tous au délai, ou étalés sur duration_s.
func plan_missiles() -> void:
	var n := maxi(o.ability.missiles, 1)
	var delay := maxf(o.ability.delay_s, 0.0)
	for i in n:
		var spread := maxf(o.ability.duration_s, 0.0) * (float(i) / n)
		_missile_times.append(delay + spread)


func _strike() -> void:
	while not _missile_times.is_empty() and o.age >= _missile_times[0]:
		_missile_times.pop_front()
		var radius := maxf(o.ability.radius_m, 1.0)
		if maxi(o.ability.missiles, 1) == 1:
			# Un seul gros impact sur toute la zone (frappe ciblée, bombe de distorsion).
			_explode(o.global_position, radius, o.ability.damage)
		else:
			var offset := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius
			_explode(o.global_position + Vector3(offset.x, 0, offset.y), MISSILE_RADIUS, o.ability.damage_per_missile)


## Explosion : touche tout ce qui est touchable dans le rayon (le propriétaire aussi :
## on sort du cercle), pas à travers les murs ; moins au bord.
## `falloff_start` (grenade à fragmentation) : dégâts pleins jusqu'à cette distance.
func _explode(point: Vector3, radius: float, damage: float, falloff_start: float = -1.0) -> void:
	var space := o.get_world_3d().direct_space_state
	for node in o.get_tree().get_nodes_in_group("damageable"):
		var target := node as Node3D
		if target == null or target is AbilityObject or not target.can_be_hit():
			continue
		var center := target.global_position + Vector3.UP * 0.9
		var dist := point.distance_to(center)
		if dist > radius + 0.9:
			continue
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.3, center, 1)
		var wall := space.intersect_ray(query)
		if not wall.is_empty() and wall["collider"] != target:
			continue
		var t := clampf(dist / (radius + 0.9), 0.0, 1.0)
		if falloff_start >= 0.0:
			t = clampf((dist - falloff_start) / maxf(radius + 0.9 - falloff_start, 0.01), 0.0, 1.0)
		target.server_receive_hit(damage * lerpf(1.0, 0.4, t), o.owner_id)
	o._show_boom.rpc(point, radius)


func _portal() -> void:
	Utility.portal(o, _teleported)


func _ward(delta: float) -> void:
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = maxf(o.ability.scan_interval_s, 1.0)
	Utility.ward_scan(o)
