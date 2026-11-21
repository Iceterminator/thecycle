extends RefCounted
## Visuel d'un monstre (tous les peers) : modèle ou capsule, barre de PV, flash de
## préparation du coup et animation d'après le déplacement observé.

var _m: Monster
var _mat: StandardMaterial3D
var _bar: Label3D
var _model_meshes: Array[MeshInstance3D] = []
var _anim: AnimationPlayer
var _anim_last_pos: Vector3
var _anim_speed := 0.0
var _anim_last_health := -1.0
var _hit_left := 0.0
var _idle_name := "Idle"  ## certains modèles (aliens) n'ont que « Alien_Idle »
## Loin de la caméra (au-delà de ANIM_DISTANCE, vérifié toutes les ANIM_CHECK s) : animation en pause.
const ANIM_DISTANCE := 70.0
const ANIM_CHECK := 0.5
var _anim_check_left := randf() * ANIM_CHECK  ## décalé : pas tous les monstres sur la même image


func _init(monster: Monster) -> void:
	_m = monster


func build() -> void:
	var data := _m.data
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = data.color
	if data.model:
		_build_model()
	else:
		_build_capsule()
	_bar = Label3D.new()
	_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bar.font_size = 36
	_bar.outline_size = 8
	_bar.pixel_size = 0.004
	_bar.position.y = data.height + 0.45
	_m.add_child(_bar)


## Animation du modèle d'après le déplacement observé et l'état synchronisé (tous les peers).
func animate(delta: float) -> void:
	if _anim == null or delta <= 0.0:
		return
	_anim_check_left -= delta
	if _anim_check_left <= 0.0:
		_anim_check_left = ANIM_CHECK
		var cam := _m.get_viewport().get_camera_3d()
		_anim.active = cam == null or cam.global_position.distance_squared_to(_m.global_position) < ANIM_DISTANCE * ANIM_DISTANCE
	if not _anim.active:
		return
	var pos := _m.global_position
	var moved := pos - _anim_last_pos
	var first := _anim_last_pos == Vector3.ZERO
	_anim_last_pos = pos
	if first:
		return
	_anim_speed = lerpf(_anim_speed, Vector2(moved.x, moved.z).length() / delta, clampf(delta * 6.0, 0.0, 1.0))
	if _anim_last_health >= 0.0 and _m.health < _anim_last_health:
		_hit_left = 0.3
	_anim_last_health = _m.health
	_hit_left -= delta
	var anim_name := _idle_name
	if _m.state == Monster.State.WINDUP:
		anim_name = "Attack"
	elif _hit_left > 0.0:
		anim_name = "Hit"
	elif _anim_speed > _m.data.walk_speed * 1.3:
		anim_name = "Run"
	elif _anim_speed > 0.3:
		anim_name = "Walk"
	if not _anim.has_animation(anim_name):
		anim_name = _idle_name
	if _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.15)


## Barre de PV au-dessus du monstre, visible seulement s'il est blessé.
func update_bar() -> void:
	if _bar == null or _m.data == null:
		return
	var ratio := clampf(_m.health / maxf(_m.max_health, 1.0), 0.0, 1.0)
	_bar.visible = ratio < 1.0 and ratio > 0.0
	var filled := ceili(ratio * 10.0)
	var display_name := _m.data.display_name
	var title := display_name if _m.level <= 1 else "%s (niv. %d)" % [display_name, _m.level]
	_bar.text = "%s\n%s%s" % [title, "■".repeat(filled), "□".repeat(10 - filled)]
	_bar.modulate = Color(1.0, 0.35, 0.3).lerp(Color(0.4, 1.0, 0.4), ratio)


## Flash rouge pendant la préparation du coup (pour pouvoir l'esquiver).
func update_look() -> void:
	if _mat == null:
		return
	var winding_up := _m.state == Monster.State.WINDUP
	for mi in _model_meshes:
		mi.material_overlay = _mat if winding_up else null
	_mat.emission_enabled = winding_up
	_mat.emission = Color(1.0, 0.1, 0.05)
	_mat.emission_energy_multiplier = 2.0


## Modèle animé (MonsterData.model), mis à la hauteur du monstre.
func _build_model() -> void:
	var data := _m.data
	var model := data.model.instantiate() as Node3D
	_m.add_child(model)
	model.rotation.y = deg_to_rad(data.model_yaw_deg)
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		_model_meshes.append(mi)
		box = mi.get_aabb() if first else box.merge(mi.get_aabb())
		first = false
	if not first and box.size.y > 0.0:
		model.scale = Vector3.ONE * data.height * data.model_height_mult / box.size.y
		model.position.y = -box.position.y * model.scale.y
	var found := model.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		_anim = found[0] as AnimationPlayer
		for anim_name: String in ["Idle", "Walk", "Run"]:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		if not _anim.has_animation(_idle_name) and _anim.has_animation("Alien_Idle"):
			_idle_name = "Alien_Idle"
			_anim.get_animation(_idle_name).loop_mode = Animation.LOOP_LINEAR
		_anim.play(_idle_name)
	# Flash de préparation du coup : voile rouge par-dessus le modèle.
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(1.0, 0.1, 0.05, 0.45)


func _build_capsule() -> void:
	var data := _m.data
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = data.radius
	capsule.height = data.height
	capsule.radial_segments = 8
	capsule.rings = 2
	body.mesh = capsule
	body.material_override = _mat
	body.position.y = data.height / 2.0
	_m.add_child(body)

	# Des « yeux » à l'avant (-Z) pour voir où il regarde.
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(1.0, 0.85, 0.2)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_box := BoxMesh.new()
		eye_box.size = Vector3.ONE * data.radius * 0.3
		eye.mesh = eye_box
		eye.material_override = eye_mat
		eye.position = Vector3(side * data.radius * 0.4, data.height * 0.78, -data.radius * 0.9)
		_m.add_child(eye)
