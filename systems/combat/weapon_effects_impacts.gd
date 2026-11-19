extends RefCounted
## Effets visuels de Weapon : impacts (éclats, point rouge sur une cible) et explosions.
## Utilise les outils de dessin de WeaponEffects (matières, formes temporaires).

var _w: Weapon
var _fx: RefCounted  # WeaponEffects


func _init(weapon: Weapon, effects: RefCounted) -> void:
	_w = weapon
	_fx = effects


func spawn_impact(world: Node3D, point: Vector3, kind: int) -> void:
	if kind == Weapon.HitKind.NONE:
		return
	var data := _w.data
	var sphere := SphereMesh.new()
	sphere.radius = 0.06 * data.impact_scale
	sphere.height = sphere.radius * 2.0
	var color := Color(1.0, 0.15, 0.1) if kind == Weapon.HitKind.TARGET else data.tracer_color
	_fx._spawn_mesh(world, sphere, color, point, 0.15)
	# Éclats qui jaillissent puis retombent.
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 10
	sparks.lifetime = 0.35
	var chip := BoxMesh.new()
	chip.size = Vector3.ONE * 0.025 * data.impact_scale
	sparks.mesh = chip
	sparks.material_override = _fx._mat(color.lightened(0.2))
	sparks.direction = Vector3.UP
	sparks.spread = 80.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 5.0
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.5
	sparks.finished.connect(sparks.queue_free)
	world.add_child(sparks)
	sparks.global_position = point
	sparks.emitting = true


## Explosion : boule de feu qui gonfle jusqu'au rayon de la zone puis s'efface.
func show_explosion(point: Vector3, radius: float) -> void:
	var world: Node3D = _fx._effects_parent()
	if world == null:
		return
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.55, 0.15, 0.7)
	var ball := MeshInstance3D.new()
	ball.mesh = sphere
	ball.material_override = mat
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ball)
	ball.global_position = point
	ball.scale = Vector3.ONE * 0.2
	Events.camera_shake_requested.emit(point, 0.9, radius * 4.0)
	var tween := ball.create_tween().set_parallel()
	tween.tween_property(ball, "scale", Vector3.ONE * radius, 0.25)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(ball.queue_free)
