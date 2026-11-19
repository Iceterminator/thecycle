class_name DropPodVisual
extends Node3D
## Capsule de largage (visuel seulement, créée comme enfant du joueur) : modèle 3D avec
## hublots, intérieur éclairé, propulseurs allumés pendant la chute, poussière à l'atterrissage,
## porte qui s'abaisse en rampe à l'ouverture, puis la capsule s'enfonce dans le sol.
## Suit la position du joueur mais pas sa rotation (la souris tourne le joueur, pas la capsule).
## Piloté par DropPodRide : land() au sol, open() à l'ouverture.

const MODEL: PackedScene = preload("res://assets/models/props/capsule_largage.gltf")
const DOOR_ANGLE := -110.0   ## porte pivotant vers l'extérieur sur sa charnière (degrés autour de Y)
const DOOR_TIME := 0.9       ## durée de l'ouverture de la porte (s)
const LINGER_TIME := 12.0    ## capsule ouverte laissée au sol avant de disparaître (s)
const SINK_DEPTH := 5.0      ## profondeur d'enfoncement à la disparition (m)
const SINK_TIME := 2.5       ## durée de l'enfoncement (s)

var _door: Node3D
var _thrust_light: OmniLight3D
var _following := true


func _ready() -> void:
	top_level = true
	var host := get_parent() as Node3D
	if host:
		# Porte face au regard du joueur au moment du largage.
		global_transform = Transform3D(Basis(Vector3.UP, host.global_rotation.y), host.global_position)
	add_child(MODEL.instantiate())
	_door = find_child("Porte", true, false) as Node3D
	var cabin := OmniLight3D.new()   # éclairage intérieur
	cabin.light_color = Color(0.75, 0.92, 1.0)
	cabin.light_energy = 0.9
	cabin.omni_range = 2.8
	cabin.position.y = 2.9
	add_child(cabin)
	_thrust_light = OmniLight3D.new()   # lueur des propulseurs sous la capsule
	_thrust_light.light_color = Color(1.0, 0.5, 0.15)
	_thrust_light.light_energy = 3.0
	_thrust_light.omni_range = 3.0
	_thrust_light.position.y = -2.6   # assez bas pour ne pas teinter l'intérieur
	add_child(_thrust_light)


func _process(_delta: float) -> void:
	if not _following:
		return
	var host := get_parent() as Node3D
	if host:
		global_position = host.global_position


## Capsule posée : propulseurs coupés, nuage de poussière.
func land() -> void:
	if _thrust_light:
		create_tween().tween_property(_thrust_light, "light_energy", 0.0, 0.6)
	var dust := CPUParticles3D.new()
	dust.one_shot = true
	dust.amount = 40
	dust.lifetime = 1.6
	dust.explosiveness = 1.0
	dust.direction = Vector3.UP
	dust.spread = 80.0
	dust.initial_velocity_min = 3.0
	dust.initial_velocity_max = 7.0
	dust.gravity = Vector3(0, -2, 0)
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.2
	var puff := SphereMesh.new()
	puff.radius = 0.35
	puff.height = 0.7
	var puff_material := StandardMaterial3D.new()
	puff_material.albedo_color = Color(0.7, 0.65, 0.55, 0.5)
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = puff_material
	dust.mesh = puff
	add_child(dust)
	dust.emitting = true


## Ouverture : la porte s'abaisse en rampe ; la capsule reste au sol puis s'enfonce et disparaît.
## Détachée du joueur : elle ne le suit plus (il sort par la porte).
func open() -> void:
	_following = false
	var tween := create_tween()
	if _door:
		tween.tween_property(_door, "rotation:y", deg_to_rad(DOOR_ANGLE), DOOR_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(LINGER_TIME)
	tween.tween_property(self, "global_position:y", global_position.y - SINK_DEPTH, SINK_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
