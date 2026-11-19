extends RefCounted
## Effets visuels de Weapon chez tous les clients : traçants, flash de bouche, impacts,
## projectiles visibles, fumée. Impacts et explosions : weapon_effects_impacts.gd. Réglages « Ressenti » du WeaponData.

const WeaponEffectsImpacts := preload("res://systems/combat/weapon_effects_impacts.gd")

var _w: Weapon
var _visual_projectiles: Dictionary[int, Node3D] = {}
var _materials: Dictionary = {}   # Color -> StandardMaterial3D (une matière par couleur)
var _impacts: WeaponEffectsImpacts


func _init(weapon: Weapon) -> void:
	_w = weapon
	_impacts = WeaponEffectsImpacts.new(weapon, self)


func _effects_parent() -> Node3D:
	if Net.is_dedicated_server:
		return null
	return _w.player.get_parent().get_parent() as Node3D


## Point de départ visuel « du canon » (un peu à droite et en dessous des yeux).
func _muzzle(origin: Vector3) -> Vector3:
	var held := _w.player.held_weapon
	if held and held.has_model():
		return held.muzzle_position()
	return origin + _w.camera.global_basis * Vector3(0.18, -0.15, -0.4)


func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		if color.a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[color] = mat
	return _materials[color]


## Petite forme temporaire dans le monde (flash, impact, traçant).
func _spawn_mesh(world: Node3D, mesh: Mesh, color: Color, pos: Vector3, life: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	mi.global_position = pos
	_w.get_tree().create_timer(life).timeout.connect(mi.queue_free)
	return mi


func show_shot(origin: Vector3, end: Vector3, kind: int) -> void:
	var data := _w.data
	var world := _effects_parent()
	if world == null or data == null:
		return
	var from := _muzzle(origin)
	# Traçant : une barre fine entre le canon et l'impact (épaisseur et durée selon l'arme).
	var length := from.distance_to(end)
	if length > 0.05:
		var bar := BoxMesh.new()
		bar.size = Vector3(data.tracer_width, data.tracer_width, length)
		var tracer := _spawn_mesh(world, bar, data.tracer_color, (from + end) / 2.0, data.tracer_time)
		tracer.look_at(end, Vector3.UP if absf((end - from).normalized().y) < 0.99 else Vector3.RIGHT)
	_muzzle_flash(world, from)
	_impacts.spawn_impact(world, end, kind)
	if _w.player.avatar:
		_w.player.avatar.play_shot()


func _muzzle_flash(world: Node3D, pos: Vector3) -> void:
	var data := _w.data
	var sphere := SphereMesh.new()
	sphere.radius = 0.05 * data.muzzle_flash_scale
	sphere.height = sphere.radius * 2.0
	_spawn_mesh(world, sphere, data.tracer_color.lightened(0.4), pos, 0.05)
	# Éclair de lumière bref : éclaire l'arme et les murs proches.
	var light := OmniLight3D.new()
	light.light_color = data.tracer_color.lightened(0.5)
	light.light_energy = 2.5 * data.muzzle_flash_scale
	light.omni_range = 4.0
	world.add_child(light)
	light.global_position = pos
	_w.get_tree().create_timer(0.06).timeout.connect(light.queue_free)


## Projectile visible : il avance seul à la vitesse donnée ; le serveur annonce sa fin.
func show_projectile(id: int, origin: Vector3, dir: Vector3, speed: float, max_dist: float) -> void:
	var data := _w.data
	var world := _effects_parent()
	if world == null or data == null:
		return
	var start := _muzzle(origin)
	var target := origin + dir * max_dist
	var bolt := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(data.projectile_size, data.projectile_size, maxf(data.projectile_size * 4.0, 0.5))
	bolt.mesh = box
	bolt.material_override = _mat(data.tracer_color)
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(bolt)
	bolt.global_position = start
	bolt.look_at_from_position(start, target, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	if data.smoke_trail:
		bolt.add_child(_make_smoke())
	_visual_projectiles[id] = bolt
	_muzzle_flash(world, start)
	if _w.player.avatar:
		_w.player.avatar.play_shot()
	var tween := bolt.create_tween()
	tween.tween_property(bolt, "global_position", target, start.distance_to(target) / speed)
	tween.finished.connect(free_visual_projectile.bind(id))


## Traînée de fumée (roquettes, obus) : particules laissées dans le monde.
func _make_smoke() -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.local_coords = false
	smoke.amount = 40
	smoke.lifetime = 0.8
	var puff := SphereMesh.new()
	puff.radius = 0.12
	puff.height = 0.24
	smoke.mesh = puff
	smoke.material_override = _mat(Color(0.55, 0.55, 0.55, 0.5))
	smoke.direction = Vector3.UP
	smoke.spread = 30.0
	smoke.initial_velocity_min = 0.2
	smoke.initial_velocity_max = 0.6
	smoke.gravity = Vector3.ZERO
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.6
	return smoke


func show_projectile_end(id: int, point: Vector3, kind: int) -> void:
	free_visual_projectile(id)
	var world := _effects_parent()
	if world and _w.data and not _w.data.is_explosive():
		_impacts.spawn_impact(world, point, kind)


func free_visual_projectile(id: int) -> void:
	var bolt: Node3D = _visual_projectiles.get(id)
	_visual_projectiles.erase(id)
	if is_instance_valid(bolt):
		bolt.queue_free()



func show_explosion(point: Vector3, radius: float) -> void:
	_impacts.show_explosion(point, radius)
