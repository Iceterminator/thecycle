class_name DropPodVisual
extends Node3D
## Capsule de largage transparente (visuel seulement, enfant du joueur) : verre bleuté,
## deux anneaux lumineux, poussière à l'atterrissage, fondu à l'ouverture.
## Piloté par DropPodRide : land() au sol, open() à l'ouverture.

const GLASS_COLOR := Color(0.45, 0.75, 1.0, 0.22)
const RING_COLOR := Color(0.4, 0.85, 1.0)
const POD_RADIUS := 1.15
const POD_HEIGHT := 2.7
const FADE_TIME := 1.2

var _glass: StandardMaterial3D
var _ring: StandardMaterial3D
var _dust: CPUParticles3D


func _ready() -> void:
	_glass = StandardMaterial3D.new()
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.albedo_color = GLASS_COLOR
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glass.roughness = 0.05
	_glass.metallic_specular = 1.0
	_ring = StandardMaterial3D.new()
	_ring.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.albedo_color = RING_COLOR
	_ring.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = POD_RADIUS
	capsule.height = POD_HEIGHT
	body.mesh = capsule
	body.material_override = _glass
	body.position.y = POD_HEIGHT / 2.0
	add_child(body)
	for y in [0.15, POD_HEIGHT - 0.15]:
		var torus := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = POD_RADIUS - 0.03
		mesh.outer_radius = POD_RADIUS + 0.07
		torus.mesh = mesh
		torus.material_override = _ring
		torus.position.y = y
		torus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(torus)


## Capsule posée : un nuage de poussière.
func land() -> void:
	_dust = CPUParticles3D.new()
	_dust.one_shot = true
	_dust.amount = 40
	_dust.lifetime = 1.6
	_dust.explosiveness = 1.0
	_dust.direction = Vector3.UP
	_dust.spread = 80.0
	_dust.initial_velocity_min = 3.0
	_dust.initial_velocity_max = 7.0
	_dust.gravity = Vector3(0, -2, 0)
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.2
	var puff := SphereMesh.new()
	puff.radius = 0.35
	puff.height = 0.7
	var puff_material := StandardMaterial3D.new()
	puff_material.albedo_color = Color(0.7, 0.65, 0.55, 0.5)
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = puff_material
	_dust.mesh = puff
	_dust.top_level = true
	add_child(_dust)
	_dust.global_position = global_position
	_dust.emitting = true


## Ouverture : le verre et les anneaux disparaissent en fondu, puis la capsule disparaît.
func open() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_glass, "albedo_color:a", 0.0, FADE_TIME)
	tween.tween_property(_ring, "albedo_color:a", 0.0, FADE_TIME)
	tween.chain().tween_callback(queue_free)
