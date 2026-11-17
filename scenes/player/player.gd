extends CharacterBody3D
## Joueur FPS répliqué en réseau.
## - Le nom du nœud = l'id réseau du joueur (donné par world.gd).
## - Ce client a l'autorité sur SON joueur : il lit les touches et bouge.
## - Le MultiplayerSynchronizer envoie position/rotation aux autres.
## Étape 2 : santé, bouclier et dégâts seront décidés par le serveur.

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var collision: CollisionShape3D = $CollisionShape3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_crouching := false

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const HEAD_OFFSET := 0.2  # distance entre le haut de la capsule et les yeux


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	var is_local := is_multiplayer_authority()
	print("[Player] Joueur %s apparu chez le peer %d (local : %s)" % [name, multiplayer.get_unique_id(), is_local])
	camera.current = is_local
	# On ne voit pas son propre corps (évite que la capsule bouche la vue).
	body_mesh.visible = not is_local
	if is_local:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_physics_process(is_local)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * Config.MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * Config.MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	elif event.is_action_pressed("toggle_mouse"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = Config.JUMP_VELOCITY

	_update_crouch(delta)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := _current_speed(input_dir)

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()


func _current_speed(input_dir: Vector2) -> float:
	if is_crouching:
		return Config.CROUCH_SPEED
	# Sprint seulement en avançant.
	if Input.is_action_pressed("sprint") and input_dir.y < 0:
		return Config.SPRINT_SPEED
	return Config.WALK_SPEED


func _update_crouch(delta: float) -> void:
	is_crouching = Input.is_action_pressed("crouch")
	var target := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	var shape := collision.shape as CapsuleShape3D
	shape.height = lerpf(shape.height, target, 12.0 * delta)
	collision.position.y = shape.height / 2.0
	head.position.y = shape.height - HEAD_OFFSET
