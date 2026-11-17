class_name Player
extends CharacterBody3D
## Joueur FPS répliqué en réseau.
## - Le nom du nœud = l'id réseau du joueur (donné par world.gd).
## - Ce client a l'autorité sur SON joueur : il lit les touches et bouge.
## - Le Synchronizer envoie position/rotation/accroupi aux autres.
## - Santé/bouclier/mort (Health) et inventaire (Inventory) sont décidés par le
##   SERVEUR : ces nœuds et leurs synchronizers gardent l'autorité 1.
## - L'arme (Weapon) et l'interaction (Interactor) DEMANDENT au serveur.
## - Couches : le joueur est sur la couche 2 (« joueurs ») et collisionne avec 1 et 2.

const HUD_SCRIPT := preload("res://systems/combat/hud.gd")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var health: Health = $Health
@onready var inventory: Inventory = $Inventory
@onready var weapon: Weapon = $Weapon
@onready var interactor: Interactor = $Interactor
@onready var shop: Shop = $Shop
@onready var score: Score = $Score

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Synchronisé : le serveur doit connaître la hauteur de la capsule pour les tirs.
var is_crouching: bool = false

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const HEAD_OFFSET := 0.2  # distance entre le haut de la capsule et les yeux


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())
	# Santé et inventaire restent au serveur (récursif : leurs synchronizers aussi).
	$Health.set_multiplayer_authority(1)
	$Inventory.set_multiplayer_authority(1)
	$Score.set_multiplayer_authority(1)


func get_peer_id() -> int:
	return name.to_int()


func _ready() -> void:
	var is_local := is_multiplayer_authority()
	print("[Player] Joueur %s apparu chez le peer %d (local : %s)" % [name, multiplayer.get_unique_id(), is_local])
	camera.current = is_local
	# On ne voit pas son propre corps (évite que la capsule bouche la vue).
	body_mesh.visible = not is_local
	health.dead_changed.connect(_on_dead_changed)
	add_to_group("damageable")
	if is_local:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var hud: CombatHud = HUD_SCRIPT.new()
		add_child(hud)
		hud.setup(self)
	set_physics_process(is_local)
	# Les copies distantes appliquent seulement la hauteur d'accroupi reçue.
	set_process(not is_local)
	# Joueur déjà mort au moment où on le reçoit (connexion en cours de partie).
	if health.is_dead:
		_on_dead_changed(true)


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


func _process(delta: float) -> void:
	_apply_crouch_shape(delta)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = Config.JUMP_VELOCITY

	is_crouching = Input.is_action_pressed("crouch")
	_apply_crouch_shape(delta)

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


func _apply_crouch_shape(delta: float) -> void:
	var target := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	var shape := collision.shape as CapsuleShape3D
	shape.height = lerpf(shape.height, target, 12.0 * delta)
	collision.position.y = shape.height / 2.0
	head.position.y = shape.height - HEAD_OFFSET


## Interface « damageable » (armes, monstres) — côté serveur.
func can_be_hit() -> bool:
	return not health.is_dead


## Renvoie true si le coup tue le joueur. attacker_id = Config.MONSTER_KILLER_ID pour un monstre.
func server_receive_hit(amount: float, attacker_id: int) -> bool:
	return health.apply_damage(amount, attacker_id)


## Vrai si un point d'impact (coordonnées monde) est dans la zone de la tête.
func is_headshot(point: Vector3) -> bool:
	var top := global_position.y + (collision.shape as CapsuleShape3D).height
	return point.y >= top - Config.HEAD_ZONE_HEIGHT


func _on_dead_changed(dead: bool) -> void:
	# Un mort ne bloque pas les tirs et ne se voit pas.
	collision.set_deferred("disabled", dead)
	body_mesh.visible = not dead and not is_multiplayer_authority()
	if is_multiplayer_authority():
		velocity = Vector3.ZERO
		set_physics_process(not dead)


## Envoyé par le serveur au propriétaire pour la réapparition
## (le déplacement est décidé par le client, c'est donc lui qui se place).
@rpc("any_peer", "call_local", "reliable")
func teleport(pos: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	global_position = pos
	velocity = Vector3.ZERO
