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
const ADMIN_SCRIPT := preload("res://systems/admin/admin.gd")
const MAP_OVERLAY_SCRIPT := preload("res://systems/map/map_overlay.gd")
const KIT_SCRIPT := preload("res://systems/kits/kit_controller.gd")
const MOVEMENT_SCRIPT := preload("res://systems/kits/kit_movement.gd")
const BUFFS_SCRIPT := preload("res://systems/abilities/buff_controller.gd")
const ABILITIES_SCRIPT := preload("res://systems/abilities/ability_controller.gd")
const PACT_UI_SCRIPT := preload("res://systems/pacts/pact_ui.gd")
const LOBBY_UI_SCRIPT := preload("res://systems/lobby/lobby_ui.gd")

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

## Menu admin (touche 0) : créé en code sur tous les peers, même chemin partout (RPC).
var admin: Admin
## Kit (PV, bouclier, vitesse, niveau ; autorité serveur) et capacités de mouvement :
## créés en code sur tous les peers (nœuds « Kit » et « Movement »).
var kit: KitController
var movement: KitMovement
## Bonus / malus temporaires et capacités Q / F (étape 8c, autorité serveur).
var buffs: BuffController
var abilities: AbilityController
var held_weapon: WeaponModel
## Recul subi (coup de poing chargé), qui s'estompe.
var _knockback := Vector3.ZERO

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
## Synchronisé : le serveur doit connaître la hauteur de la capsule pour les tirs.
var is_crouching: bool = false
## En l'air (saut, chute, jetpack) : synchronisé pour l'animation vue par les autres.
var is_airborne: bool = false
var avatar: PlayerAvatar
## À bord de l'évac (décidé par le serveur, envoyé par set_evacuated) : spectateur
## intouchable, ne tire plus, n'interagit plus, vole librement.
var is_evacuated: bool = false

signal evacuated_changed(evacuated: bool)

## Hauteur ajoutée quand on passe spectateur (vue d'ensemble de la carte).
const SPECTATOR_LIFT := 20.0

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
	admin = ADMIN_SCRIPT.new()
	admin.name = "Admin"
	add_child(admin)
	kit = KIT_SCRIPT.new()
	kit.name = "Kit"
	kit.set_multiplayer_authority(1)  # le serveur décide du kit, du niveau et de l'XP
	add_child(kit)
	movement = MOVEMENT_SCRIPT.new()
	movement.name = "Movement"
	add_child(movement)
	buffs = BUFFS_SCRIPT.new()
	buffs.name = "Buffs"
	buffs.set_multiplayer_authority(1)
	add_child(buffs)
	abilities = ABILITIES_SCRIPT.new()
	abilities.name = "Abilities"
	abilities.set_multiplayer_authority(1)
	add_child(abilities)
	# Arme tenue en main (modèle 3D), visible par tous : à la première personne pour le joueur local.
	held_weapon = WeaponModel.new()
	held_weapon.name = "HeldWeapon"
	head.add_child(held_weapon)
	held_weapon.setup(self)
	# Corps animé, pour les autres joueurs seulement (le joueur local ne voit pas son corps).
	if not is_local and not Net.is_dedicated_server:
		avatar = PlayerAvatar.new()
		avatar.name = "Avatar"
		body_mesh.add_child(avatar)
		avatar.setup(self, body_mesh)
	if not is_local:
		_build_beacon()
	if is_local:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var hud: CombatHud = HUD_SCRIPT.new()
		add_child(hud)
		hud.setup(self)
		var map_overlay: MapOverlay = MAP_OVERLAY_SCRIPT.new()
		map_overlay.name = "MapOverlay"
		add_child(map_overlay)
		map_overlay.setup(self)
		# Profil : le serveur charge réputation et équipement de ce pseudo.
		var profiles := get_parent().get_parent().get_node_or_null("ProfileManager")
		if profiles:
			profiles.request_register.rpc_id(1, Net.player_name)
		var pact_ui: PactUi = PACT_UI_SCRIPT.new()
		pact_ui.name = "PactUi"
		add_child(pact_ui)
		pact_ui.setup(self)
		var lobby_ui: LobbyUi = LOBBY_UI_SCRIPT.new()
		lobby_ui.name = "LobbyUi"
		add_child(lobby_ui)
		lobby_ui.setup(self)
	health.downed_changed.connect(_on_downed_changed)
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
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		# Un vrai clic recapture la souris ; pas la molette (sinon, défiler dans un menu
		# ouvert recapturait la souris par-dessus le menu).
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	_apply_crouch_shape(delta)
	# Camouflage vu par les autres : le corps devient transparent.
	if buffs and body_mesh.visible:
		var speed := Vector2(velocity.x, velocity.z).length()
		body_mesh.transparency = buffs.get_cloak(speed)


func _physics_process(delta: float) -> void:
	if is_evacuated:
		_spectator_move(delta)
		return
	var on_floor := is_on_floor()
	is_airborne = not on_floor
	if not on_floor:
		velocity.y -= gravity * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# À terre : on rampe, rien d'autre (pas de saut ni de capacité).
	if health.is_downed:
		is_crouching = true
		_apply_crouch_shape(delta)
		var crawl := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized() * Config.combat.downed_speed
		velocity.x = crawl.x
		velocity.z = crawl.z
		move_and_slide()
		return
	# Saut, glissade et capacités du kit (jetpack, esquive, super saut…).
	movement.pre_physics(delta, input_dir)
	is_crouching = Input.is_action_pressed("crouch") or movement.is_sliding()
	_apply_crouch_shape(delta)

	if movement.overrides_horizontal():
		var forced := movement.forced_horizontal()
		velocity.x = forced.x
		velocity.z = forced.z
	else:
		var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		var target := direction * _current_speed(input_dir)
		if on_floor:
			if direction:
				velocity.x = target.x
				velocity.z = target.z
			else:
				var speed := _current_speed(input_dir)
				velocity.x = move_toward(velocity.x, 0, speed)
				velocity.z = move_toward(velocity.z, 0, speed)
		else:
			# En l'air : contrôle partiel (Config.combat.air_control), total pendant le jetpack.
			var weight := clampf(movement.air_control() * 10.0 * delta, 0.0, 1.0)
			velocity.x = lerpf(velocity.x, target.x, weight)
			velocity.z = lerpf(velocity.z, target.z, weight)

	# Recul : ajouté au sol (où la vitesse horizontale est réimposée à chaque image).
	if on_floor:
		velocity += _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	move_and_slide()
	movement.post_physics()


## Vitesse au sol : celle du kit ; sprint (en avançant) x Config.combat.sprint_multiplier.
func _current_speed(input_dir: Vector2) -> float:
	var buff := buffs.get_mult("speed_mult") if buffs else 1.0
	if is_crouching:
		return Config.combat.crouch_speed * buff
	if Input.is_action_pressed("sprint") and input_dir.y < 0:
		return kit.move_speed() * Config.combat.sprint_multiplier * buff
	return kit.move_speed() * buff


## Mod d'arme choisi par ce joueur pour cette arme (lobby, étape 9), ou null.
func weapon_mod(wdata: WeaponData) -> WeaponModData:
	if wdata == null:
		return null
	return WeaponModData.get_mod(String(ProfileManager.weapon_mods(get_peer_id()).get(String(wdata.id), "")))


## Arme de départ (profil, choisie dans le lobby) ; Config.start_loadout.base_weapon sinon.
func start_weapon_id() -> StringName:
	return ProfileManager.start_weapon(get_peer_id())


## Taille de chargeur de cette arme pour ce joueur (mod « chargeur étendu » compris).
func magazine_for(wdata: WeaponData) -> int:
	if wdata == null:
		return 0
	var mod := weapon_mod(wdata)
	return maxi(roundi(wdata.magazine * (mod.magazine_mult if mod else 1.0)), 1)


## À terre : un allié peut nous relever (interaction E maintenue) ; tous les peers.
func _on_downed_changed(downed: bool) -> void:
	if downed:
		add_to_group("downed_players")
		add_to_group("interactable")
	else:
		remove_from_group("downed_players")
		remove_from_group("interactable")


## Interaction (relever) : seulement pour un allié, et seulement si on est à terre.
func get_prompt(viewer: Player) -> String:
	if not health.is_downed or viewer == self or not Allies.can_revive(viewer.get_peer_id(), get_peer_id()):
		return ""
	return "Maintenir E : relever %s" % ProfileManager.name_of(get_peer_id())


func get_hold_time(_viewer: Player) -> float:
	return Config.combat.revive_time


func server_interact(viewer: Player) -> void:
	if health.is_downed and Allies.can_revive(viewer.get_peer_id(), get_peer_id()) and not viewer.health.is_downed:
		health.server_revive_downed(viewer.get_peer_id())


## Serveur -> joueur touché : recul (coup de poing chargé).
@rpc("any_peer", "call_local", "reliable")
func apply_knockback(impulse: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1 or not impulse.is_finite():
		return
	_knockback = impulse.limit_length(20.0)


func _apply_crouch_shape(delta: float) -> void:
	var target := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	var shape := collision.shape as CapsuleShape3D
	shape.height = lerpf(shape.height, target, 12.0 * delta)
	collision.position.y = shape.height / 2.0
	head.position.y = shape.height - HEAD_OFFSET


## Spectateur (embarqué) : vol libre sans collision. Espace monte, Ctrl descend, Maj accélère.
func _spectator_move(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := head.global_basis * Vector3(input_dir.x, 0, input_dir.y)
	if Input.is_action_pressed("jump"):
		direction += Vector3.UP
	if Input.is_action_pressed("crouch"):
		direction += Vector3.DOWN
	if direction.length_squared() > 0.0:
		var speed := Config.SPECTATOR_SPEED * (2.0 if Input.is_action_pressed("sprint") else 1.0)
		global_position += direction.normalized() * speed * delta


## Envoyé par le serveur à tous (embarquement, nouvelle partie).
@rpc("any_peer", "call_local", "reliable")
func set_evacuated(value: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1 or value == is_evacuated:
		return
	is_evacuated = value
	collision.set_deferred("disabled", value or health.is_dead)
	body_mesh.visible = not value and not health.is_dead and not is_multiplayer_authority()
	if is_multiplayer_authority():
		velocity = Vector3.ZERO
		is_crouching = false
		if value:
			global_position += Vector3.UP * SPECTATOR_LIFT
	evacuated_changed.emit(value)


## Interface « damageable » (armes, monstres) — côté serveur.
func can_be_hit() -> bool:
	return not health.is_dead and not is_evacuated


## Renvoie true si le coup tue le joueur. attacker_id = Config.MONSTER_KILLER_ID pour un monstre.
func server_receive_hit(amount: float, attacker_id: int) -> bool:
	return health.apply_damage(amount, attacker_id)


## Vrai si un point d'impact (coordonnées monde) est dans la zone de la tête.
func is_headshot(point: Vector3) -> bool:
	var top := global_position.y + (collision.shape as CapsuleShape3D).height
	return point.y >= top - Config.HEAD_ZONE_HEIGHT


## Balise au-dessus des AUTRES joueurs, visible de loin et à travers le décor,
## quand leur Score.beacon n'est pas vide (porteur du Cœur stellaire, prime…).
func _build_beacon() -> void:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0009
	label.font_size = 30
	label.outline_size = 8
	label.modulate = Color(1, 0.85, 0.2)
	label.position.y = 2.4
	add_child(label)
	var refresh := func() -> void:
		label.text = score.beacon
		label.visible = score.beacon != "" and not health.is_dead
	score.changed.connect(refresh)
	health.dead_changed.connect(func(_d: bool) -> void: refresh.call())
	refresh.call()


func _on_dead_changed(dead: bool) -> void:
	# Un mort ne bloque pas les tirs ; son corps reste visible (animation de mort) jusqu'à la réapparition.
	collision.set_deferred("disabled", dead)
	body_mesh.visible = not is_multiplayer_authority()
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
