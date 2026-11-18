class_name AbilityObject
extends StaticBody3D
## Objet posé par une capacité (étape 8c). Créé par le serveur (AbilityManager ->
## AbilitySpawner, spawn_function) et recréé à l'identique chez tous à partir des mêmes
## données ; les clients ne font que l'afficher (âge compté localement depuis l'apparition).
##
## kind (données « kind ») :
## - grenade : vole en arc (start, vel, land_time) puis devient un champ à l'atterrissage :
##   dégâts aux autres (damage_per_s) et / ou soin du propriétaire (heal_per_s), rayon radius_m ;
## - turret : tourelle (health PV, touchable) qui tire sur les ennemis à portée ;
## - barrier : mur. Mur cinétique : bloque tout (le propriétaire tire à travers) ;
##   Paravent : bloque les tirs de tous mais se traverse ;
## - strike : marqueur visible de tous, puis missiles (ou un seul impact) après delay_s ;
## - portal : entrée devant soi, sortie plus loin ; qui entre ressort de l'autre côté ;
## - ward : balise (touchable) qui révèle au propriétaire les joueurs proches sur sa carte.

const TICK := 0.25                 ## champs : dégâts / soins tous les TICK s
const MISSILE_RADIUS := 2.5        ## rayon d'explosion d'un missile de frappe (m)
const PORTAL_RADIUS := 1.3

var kind: String = ""
var ability: AbilityData
var owner_id: int = 0
var spawn_data: Dictionary = {}
var age: float = 0.0
## Synchronisé (tourelle, balise).
var health: float = 0.0:
	set(value):
		health = value
		if _bar:
			_bar.text = "%d PV" % ceili(health)

# --- Serveur ---
var _tick_left: float = 0.0
var _fire_left: float = 0.0
var _missile_times: Array[float] = []
var _struck: bool = false
var _teleported: Dictionary = {}   # nœud -> âge du dernier passage
# --- Visuels ---
var _ball: MeshInstance3D
var _field: MeshInstance3D
var _bar: Label3D


## Appelé par la spawn_function, sur tous les peers, avant l'entrée dans l'arbre.
func setup(data: Dictionary) -> void:
	spawn_data = data
	kind = data["kind"]
	owner_id = data["owner"]
	ability = AbilityController.get_ability(data.get("ability", ""))
	collision_layer = 0
	collision_mask = 0
	match kind:
		"beacon":
			# Balise de rappel (gadget) : chiffres dans les données, pas d'AbilityData.
			health = float(data["health"])  # WeaponData.beacon_health (Weapon)
			_add_box_shape(Vector3(0.6, 1.0, 0.6), 1)
			_build_sync()
		"turret", "ward":
			health = ability.health if ability.health > 0.0 else Config.combat.ward_health
			_add_box_shape(Vector3(1.2, 1.6, 1.2) if kind == "turret" else Vector3(0.5, 1.4, 0.5), 1)
			_build_sync()
		"barrier":
			var w := ability.width_m
			var h := ability.height_m
			# Paravent : couche à part, que les corps ne touchent pas mais que les tirs touchent.
			_add_box_shape(Vector3(w, h, 0.3), Config.SHOT_ONLY_LAYER if ability.id == &"safeguard" else 1)
	_build_visual()


func _ready() -> void:
	if kind == "turret" or kind == "ward" or kind == "beacon":
		add_to_group("damageable")
	if kind == "beacon":
		add_to_group("recall_beacon")  # retrouvée par l'arme (gadget) de son propriétaire
	if kind == "barrier" and ability.id == &"kinetic_barrier":
		add_to_group("owner_shots_pass")  # le propriétaire tire à travers (voir Weapon)
	set_physics_process(multiplayer.is_server())
	if multiplayer.is_server() and kind == "strike":
		_plan_missiles()


func life() -> float:
	match kind:
		"grenade":
			return float(spawn_data["land_time"]) + maxf(ability.duration_s, 0.1)
		"turret", "barrier", "portal":
			return maxf(ability.duration_s, 1.0)
		"strike":
			return maxf(ability.delay_s, 0.0) + maxf(ability.duration_s, 0.0) + 1.0
		"ward", "beacon":
			return Config.combat.ward_lifetime
		"frag":
			return float(spawn_data["fuse"]) + 0.2
	return 5.0


# =========================================================================
# Interface « damageable » (tourelle, balise)
# =========================================================================

func can_be_hit() -> bool:
	return health > 0.0


func is_headshot(_point: Vector3) -> bool:
	return false


func server_receive_hit(amount: float, attacker_id: int) -> bool:
	if health <= 0.0 or attacker_id == owner_id:
		return false
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		queue_free()
		return true
	return false


# =========================================================================
# Serveur
# =========================================================================

func _physics_process(delta: float) -> void:
	age += delta
	if age >= life():
		queue_free()
		return
	match kind:
		"grenade":
			if age >= float(spawn_data["land_time"]):
				_server_field(delta)
		"frag":
			# Grenade à fragmentation : explose à la fin de la mèche, où qu'elle soit.
			if not _struck and age >= float(spawn_data["fuse"]):
				_struck = true
				_explode(_arc_pos(float(spawn_data["fuse"])), float(spawn_data["radius"]),
						float(spawn_data["damage"]), float(spawn_data.get("falloff_start", -1.0)))
		"turret":
			_server_turret(delta)
		"strike":
			_server_strike()
		"portal":
			_server_portal()
		"ward":
			_server_ward(delta)


func _owner() -> Player:
	var players := get_parent().get_parent().get_node_or_null("Players")
	return players.get_node_or_null(str(owner_id)) as Player if players else null


## Cibles touchables (pas le propriétaire, pas les objets de capacité) dans un rayon.
func _targets_in(center: Vector3, radius: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("damageable"):
		var target := node as Node3D
		if target == null or target == self or target is AbilityObject or not target.can_be_hit():
			continue
		if target is Player and (target as Player).get_peer_id() == owner_id:
			continue
		if target.global_position.distance_to(center) <= radius:
			result.append(target)
	return result


func _land_pos() -> Vector3:
	return spawn_data.get("land_pos", global_position)


func _server_field(delta: float) -> void:
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = TICK
	var center := _land_pos()
	var radius := maxf(ability.radius_m, 1.0)
	if ability.damage_per_s > 0.0:
		for target in _targets_in(center, radius):
			target.server_receive_hit(ability.damage_per_s * TICK, owner_id)
	if ability.heal_per_s > 0.0:
		var me := _owner()
		if me and not me.health.is_dead and me.global_position.distance_to(center) <= radius:
			me.health.heal(ability.heal_per_s * TICK)


func _server_turret(delta: float) -> void:
	_fire_left -= delta
	if _fire_left > 0.0:
		return
	_fire_left = 60.0 / maxf(ability.rpm, 1.0)
	var muzzle := global_position + Vector3.UP * 1.4
	var best: Node3D = null
	var best_dist := maxf(ability.range_m, 5.0)
	var space := get_world_3d().direct_space_state
	for target in _targets_in(global_position, best_dist):
		var aim := target.global_position + Vector3.UP * 0.9
		var query := PhysicsRayQueryParameters3D.create(muzzle, aim, 1)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and hit["collider"] != target:
			continue
		var d := muzzle.distance_to(aim)
		if d < best_dist:
			best = target
			best_dist = d
	if best == null:
		return
	best.server_receive_hit(ability.damage, owner_id)
	_show_tracer.rpc(muzzle, best.global_position + Vector3.UP * 0.9)


## Moments des missiles (en âge de l'objet) : tous au délai, ou étalés sur duration_s.
func _plan_missiles() -> void:
	var n := maxi(ability.missiles, 1)
	var delay := maxf(ability.delay_s, 0.0)
	for i in n:
		var spread := maxf(ability.duration_s, 0.0) * (float(i) / n)
		_missile_times.append(delay + spread)


func _server_strike() -> void:
	while not _missile_times.is_empty() and age >= _missile_times[0]:
		_missile_times.pop_front()
		var radius := maxf(ability.radius_m, 1.0)
		if maxi(ability.missiles, 1) == 1:
			# Un seul gros impact sur toute la zone (frappe ciblée, bombe de distorsion).
			_explode(global_position, radius, ability.damage)
		else:
			var offset := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * radius
			_explode(global_position + Vector3(offset.x, 0, offset.y), MISSILE_RADIUS, ability.damage_per_missile)


## Explosion : touche tout ce qui est touchable dans le rayon (le propriétaire aussi :
## on sort du cercle), pas à travers les murs ; moins au bord.
## `falloff_start` (grenade à fragmentation) : dégâts pleins jusqu'à cette distance.
func _explode(point: Vector3, radius: float, damage: float, falloff_start: float = -1.0) -> void:
	var space := get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group("damageable"):
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
		target.server_receive_hit(damage * lerpf(1.0, 0.4, t), owner_id)
	_show_boom.rpc(point, radius)


func _server_portal() -> void:
	var entry := global_position
	var exit: Vector3 = spawn_data["exit"]
	var candidates: Array = []
	var players := get_parent().get_parent().get_node_or_null("Players")
	if players:
		candidates.append_array(players.get_children())
	var monsters := get_parent().get_parent().get_node_or_null("Monsters")
	if monsters:
		candidates.append_array(monsters.get_children())
	for node in candidates:
		var body := node as Node3D
		if body == null or Vector2(body.global_position.x - entry.x, body.global_position.z - entry.z).length() > PORTAL_RADIUS:
			continue
		if age - float(_teleported.get(body, -10.0)) < 1.0:
			continue
		_teleported[body] = age
		var dest := exit + Vector3.UP * 0.3
		body.global_position = dest
		if body is Player:
			(body as Player).teleport.rpc_id((body as Player).get_peer_id(), dest)


func _server_ward(delta: float) -> void:
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = maxf(ability.scan_interval_s, 1.0)
	var spotted: Array = []
	var players := get_parent().get_parent().get_node_or_null("Players")
	if players:
		for node in players.get_children():
			var p := node as Player
			if p and p.get_peer_id() != owner_id and p.can_be_hit() \
					and p.global_position.distance_to(global_position) <= maxf(ability.radius_m, 5.0):
				spotted.append(p.global_position)
	_scan_ping.rpc_id(owner_id, spotted)


# =========================================================================
# Tous les peers : visuels
# =========================================================================

func _process(delta: float) -> void:
	if multiplayer.is_server():
		pass  # l'âge est compté par _physics_process
	else:
		age += delta
	if (kind == "grenade" or kind == "frag") and _ball:
		_ball.global_position = _arc_pos(age) + (Vector3.UP * 0.15 if age >= float(spawn_data["land_time"]) else Vector3.ZERO)
		if _field and age >= float(spawn_data["land_time"]):
			_field.visible = true


## Position sur l'arc du lancer au temps `t`, puis posée au point d'atterrissage.
func _arc_pos(t: float) -> Vector3:
	if t >= float(spawn_data["land_time"]):
		return _land_pos()
	var start: Vector3 = spawn_data["start"]
	var vel: Vector3 = spawn_data["vel"]
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	return start + vel * t + Vector3.DOWN * 0.5 * g * t * t


func _build_visual() -> void:
	if Net.is_dedicated_server:
		return
	var color := _color()
	match kind:
		"frag":
			_ball = _mesh(_sphere(0.12), Color(0.35, 0.4, 0.3), false)
		"beacon":
			var post := _mesh(_box(Vector3(0.4, 1.0, 0.4)), color, false)
			post.position.y = 0.5
			# Colonne de lumière visible de loin.
			var column := _mesh(_box(Vector3(0.15, 12.0, 0.15)), Color(color, 0.35), true)
			column.position.y = 6.0
			_add_bar(1.5)
		"grenade":
			_ball = _mesh(_sphere(0.15), color, false)
			_field = _mesh(_sphere(maxf(ability.radius_m, 1.0)), Color(color, 0.22), true)
			_field.position = _land_pos() - global_position_from_data()
			_field.visible = false
		"turret":
			var base := _mesh(_box(Vector3(1.2, 1.2, 1.2)), color.darkened(0.3), false)
			base.position.y = 0.6
			var barrel := _mesh(_box(Vector3(0.25, 0.25, 1.2)), color, false)
			barrel.position = Vector3(0, 1.4, -0.4)
			_add_bar(2.2)
		"barrier":
			var w := ability.width_m
			var h := ability.height_m
			var wall := _mesh(_box(Vector3(w, h, 0.3)), Color(color, 0.45), true)
			wall.position.y = h / 2.0
		"strike":
			var disc := CylinderMesh.new()
			disc.top_radius = maxf(ability.radius_m, 1.0)
			disc.bottom_radius = disc.top_radius
			disc.height = 0.05
			var marker := _mesh(disc, Color(color, 0.35), true)
			marker.position.y = 0.05
		"portal":
			var ring_in := _mesh(_ring(), color, false)
			ring_in.position.y = 1.0
			var ring_out := _mesh(_ring(), color, false)
			ring_out.position = Vector3(spawn_data["exit"]) - global_position_from_data() + Vector3.UP
		"ward":
			var pylon := _mesh(_box(Vector3(0.3, 1.4, 0.3)), color, false)
			pylon.position.y = 0.7
			_add_bar(1.8)


## Position de l'objet telle que donnée à l'apparition (avant l'entrée dans l'arbre).
func global_position_from_data() -> Vector3:
	return spawn_data.get("pos", spawn_data.get("start", Vector3.ZERO))


func _color() -> Color:
	if ability == null:
		return Color(0.95, 0.8, 0.4)  # gadgets
	match ability.faction:
		WeaponData.Faction.LOURDE:
			return Color(1.0, 0.5, 0.2)
		WeaponData.Faction.TECHNO:
			return Color(0.4, 1.0, 0.55)
		WeaponData.Faction.EQUILIBRE:
			return Color(0.4, 0.7, 1.0)
	return Color(0.5, 0.75, 1.0)


func _mesh(mesh: Mesh, color: Color, transparent: bool) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	return s


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _ring() -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = PORTAL_RADIUS * 0.8
	t.outer_radius = PORTAL_RADIUS
	return t


func _add_bar(height: float) -> void:
	_bar = Label3D.new()
	_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bar.font_size = 32
	_bar.outline_size = 8
	_bar.pixel_size = 0.004
	_bar.position.y = height
	_bar.text = "%d PV" % ceili(health)
	add_child(_bar)


func _add_box_shape(size: Vector3, layer: int) -> void:
	collision_layer = layer
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2.0
	add_child(shape)


func _build_sync() -> void:
	var config := SceneReplicationConfig.new()
	var path := NodePath(".:health")
	config.add_property(path)
	config.property_set_spawn(path, true)
	config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "AbilitySync"
	sync.replication_config = config
	add_child(sync)


@rpc("authority", "call_local", "unreliable")
func _show_tracer(from: Vector3, to: Vector3) -> void:
	if Net.is_dedicated_server:
		return
	var bar := BoxMesh.new()
	bar.size = Vector3(0.05, 0.05, from.distance_to(to))
	var mi := MeshInstance3D.new()
	mi.mesh = bar
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _color()
	mi.material_override = mat
	get_parent().get_parent().add_child(mi)  # dans le monde, pas dans le conteneur du spawner
	mi.global_position = (from + to) / 2.0
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	get_tree().create_timer(0.06).timeout.connect(mi.queue_free)


@rpc("authority", "call_local", "unreliable")
func _show_boom(point: Vector3, radius: float) -> void:
	if Net.is_dedicated_server:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.55, 0.15, 0.7)
	var ball := MeshInstance3D.new()
	ball.mesh = _sphere(1.0)
	ball.material_override = mat
	get_parent().get_parent().add_child(ball)
	ball.global_position = point
	ball.scale = Vector3.ONE * 0.2
	Events.camera_shake_requested.emit(point, 0.9, radius * 4.0)
	var tween := ball.create_tween().set_parallel()
	tween.tween_property(ball, "scale", Vector3.ONE * radius, 0.25)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(ball.queue_free)


## Balise : positions des joueurs repérés, pour la carte du propriétaire seulement.
@rpc("authority", "call_local", "reliable")
func _scan_ping(positions: Array) -> void:
	if multiplayer.get_unique_id() != owner_id:
		return
	Events.scan_revealed.emit(positions)
