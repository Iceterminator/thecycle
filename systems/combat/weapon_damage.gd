extends RefCounted
## Serveur : raycast de tir, impact direct (distance, point faible), dégâts bouclier / PV,
## explosions.

## Explosions : dégâts au bord de la zone (part des dégâts au centre).
const EXPLOSION_EDGE_RATIO := 0.25

var _w: Weapon


func _init(weapon: Weapon) -> void:
	_w = weapon


## Tir instantané : raycast, impact, explosion éventuelle, puis effets chez les clients.
func trace(origin: Vector3, dir: Vector3) -> void:
	var data := _w.data
	var to := origin + dir * data.get_max_range() * _w._boost("range")
	var ray := raycast(origin, to)
	var end := to
	var kind := Weapon.HitKind.NONE
	if not ray.is_empty():
		end = ray["position"]
		kind = hit(ray["collider"] as Node, end, origin.distance_to(end) / _w._boost("range"), data, _w._boost("damage"))
		if data.is_explosive():
			explode(end, data, ray["collider"] as Node, _w._boost("damage"))
	_w._show_shot.rpc(origin, end, kind)


func raycast(from: Vector3, to: Vector3) -> Dictionary:
	var player := _w.player
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var exclude: Array[RID] = [player.get_rid()]
	# Mur cinétique : son propriétaire tire à travers.
	for wall in _w.get_tree().get_nodes_in_group("owner_shots_pass"):
		if wall.owner_id == player.get_peer_id():
			exclude.append(wall.get_rid())
	query.exclude = exclude
	return player.get_world_3d().direct_space_state.intersect_ray(query)


## Applique un impact direct. Cible touchable (joueur, monstre) : groupe "damageable" avec
## can_be_hit(), is_headshot(point) et server_receive_hit(dégâts, attaquant).
func hit(target: Node, point: Vector3, distance: float, wdata: WeaponData, dmg_mult: float = 1.0) -> Weapon.HitKind:
	if target == null or not target.is_in_group("damageable") or not target.can_be_hit():
		return Weapon.HitKind.WORLD
	var headshot: bool = target.is_headshot(point)
	var damage := wdata.get_hit_damage() * wdata.get_falloff_multiplier(distance) * dmg_mult
	if headshot:
		damage *= wdata.weakspot_multiplier
	var killed := _damage(target, damage, wdata)
	_w._confirm_hit.rpc_id(_w.player.get_peer_id(), headshot, killed)
	return Weapon.HitKind.TARGET


## Dégâts sur une cible. Un joueur prend les multiplicateurs bouclier / PV de l'arme et son
## bonus « contre les joueurs » ; un monstre, le bonus « contre les créatures » de l'arme
## (mods) et du kit du tireur.
func _damage(target: Node, amount: float, wdata: WeaponData) -> bool:
	var player := _w.player
	if target is Monster:
		amount *= wdata.damage_vs_creatures_multiplier
		if player.kit:
			amount *= 1.0 + player.kit.get_effect("creature_damage")
	var victim := target as Player
	if victim:
		amount *= wdata.damage_vs_players_multiplier
	if player.kit:
		amount *= player.kit.combat.damage_dealt_mult(victim != null)  # mods : cumuls d'éliminations, en l'air
	var shield_mult := wdata.damage_vs_shield_multiplier
	if victim and (shield_mult != 1.0 or wdata.damage_vs_health_multiplier != 1.0):
		return victim.health.apply_damage(amount, player.get_peer_id(),
				shield_mult, wdata.damage_vs_health_multiplier)
	return target.server_receive_hit(amount, player.get_peer_id())


## Explosion : aoe_damage au centre, EXPLOSION_EDGE_RATIO au bord, sur tout ce qui est
## touchable dans le rayon (le tireur compris), sauf derrière un mur. La cible touchée
## directement a déjà pris ses dégâts directs et ne reprend pas la zone.
func explode(point: Vector3, wdata: WeaponData, direct: Node, dmg_mult: float = 1.0) -> void:
	var player := _w.player
	var radius := wdata.aoe_radius_m
	var space := player.get_world_3d().direct_space_state
	for node in _w.get_tree().get_nodes_in_group("damageable"):
		var target := node as Node3D
		if target == null or target == direct or not target.can_be_hit():
			continue
		var center := target.global_position + Vector3.UP * 0.9
		var dist := point.distance_to(center)
		if dist > radius:
			continue
		var query := PhysicsRayQueryParameters3D.create(point + (center - point).normalized() * 0.2, center, 1)
		var wall := space.intersect_ray(query)
		if not wall.is_empty() and wall["collider"] != target:
			continue
		var damage := wdata.aoe_damage * lerpf(1.0, EXPLOSION_EDGE_RATIO, dist / radius) * dmg_mult
		var killed := _damage(target, damage, wdata)
		if target != player:
			_w._confirm_hit.rpc_id(player.get_peer_id(), false, killed)
	_w._show_explosion.rpc(point, radius)
