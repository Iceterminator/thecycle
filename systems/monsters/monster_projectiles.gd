extends RefCounted
## Projectiles d'un monstre à distance : simulation serveur et orbes visibles chez tous.
## Les @rpc (_show_projectile, _end_projectile) restent dans monster.gd et appellent ce script.

const BURST_SPREAD_DEG := 1.5  ## dispersion max d'un projectile de salve (°)

var _m: Monster
var _burst_left: int = 0        ## projectiles restant à tirer dans la salve
var _burst_wait: float = 0.0
var _projectiles: Array[Dictionary] = []  ## { id, pos, dir, travelled, max_dist }
var _next_projectile_id: int = 0
var _visual_projectiles: Dictionary[int, Node3D] = {}


func _init(monster: Monster) -> void:
	_m = monster


func is_empty() -> bool:
	return _projectiles.is_empty() and _burst_left <= 0


## Lance une attaque à distance : data.ranged_burst_count projectiles espacés dans le temps.
func fire() -> void:
	_burst_left = _m.data.ranged_burst_count
	_burst_wait = 0.0


## Tire les projectiles restants de la salve, au rythme de data.ranged_burst_interval_s.
func _step_burst(delta: float) -> void:
	if _burst_left <= 0:
		return
	_burst_wait -= delta
	if _burst_wait > 0.0:
		return
	if not is_instance_valid(_m._target):
		_burst_left = 0
		return
	_fire_one(_m.data.ranged_burst_count > 1)
	_burst_left -= 1
	_burst_wait = _m.data.ranged_burst_interval_s


## Un projectile vers le torse de la cible (pas d'anticipation : on peut l'esquiver).
## `spread` : petite dispersion aléatoire (± BURST_SPREAD_DEG) pour les salves.
func _fire_one(spread: bool) -> void:
	var data := _m.data
	var forward := -_m.global_basis.z
	var from := _m.global_position + Vector3.UP * data.height * 0.75 + forward * data.radius
	var aim := _m._target.global_position + Vector3.UP * 1.0
	var dir := (aim - from).normalized()
	if spread:
		var angle := deg_to_rad(BURST_SPREAD_DEG)
		dir = dir.rotated(Vector3.UP, randf_range(-angle, angle))
		dir = dir.rotated(dir.cross(Vector3.UP).normalized(), randf_range(-angle, angle))
	_next_projectile_id += 1
	var max_dist := data.attack_range * 1.6
	_projectiles.append({"id": _next_projectile_id, "pos": from, "dir": dir, "travelled": 0.0, "max_dist": max_dist})
	_m._show_projectile.rpc(_next_projectile_id, from, dir, data.projectile_speed, max_dist)


## Un raycast par image sur le segment parcouru : décor (couche 1) et joueurs (couche 2).
## Touche aussi une foreuse (décor avec server_receive_hit).
func step(delta: float) -> void:
	_step_burst(delta)
	var space := _m.get_world_3d().direct_space_state
	for i in range(_projectiles.size() - 1, -1, -1):
		var p := _projectiles[i]
		var step_len := minf(_m.data.projectile_speed * delta, p["max_dist"] - p["travelled"])
		var from: Vector3 = p["pos"]
		var to: Vector3 = from + p["dir"] * step_len
		var query := PhysicsRayQueryParameters3D.create(from, to, 1 | (1 << 1) | Config.SHOT_ONLY_LAYER)
		query.exclude = [_m.get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var target := hit["collider"] as Node
			if target and target.has_method("server_receive_hit") and target.has_method("can_be_hit") and target.can_be_hit():
				target.server_receive_hit(_m.data.attack_damage * _m.damage_mult, Config.MONSTER_KILLER_ID)
			_m._end_projectile.rpc(p["id"], hit["position"])
			_projectiles.remove_at(i)
			continue
		p["pos"] = to
		p["travelled"] += step_len
		if p["travelled"] >= p["max_dist"]:
			_m._end_projectile.rpc(p["id"], to)
			_projectiles.remove_at(i)


## Tous les peers : crée l'orbe visible et le fait avancer.
func show_visual(id: int, from: Vector3, dir: Vector3, speed: float, max_dist: float) -> void:
	if Net.is_dedicated_server:
		return
	var world := _m.get_parent().get_parent() as Node3D
	if world == null:
		return
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _m.data.color.lightened(0.4)
	sphere.material = mat
	orb.mesh = sphere
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(orb)
	orb.global_position = from
	_visual_projectiles[id] = orb
	var tween := orb.create_tween()
	tween.tween_property(orb, "global_position", from + dir * max_dist, max_dist / speed)
	tween.finished.connect(free_visual.bind(id))


func free_visual(id: int) -> void:
	var orb: Node3D = _visual_projectiles.get(id)
	_visual_projectiles.erase(id)
	if is_instance_valid(orb):
		orb.queue_free()


## Le monstre disparaît : ses projectiles visibles aussi.
func free_all_visuals() -> void:
	for id: int in _visual_projectiles.keys():
		free_visual(id)
