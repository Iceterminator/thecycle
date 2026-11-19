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

const PlayerSetup := preload("res://scenes/player/player_setup.gd")
const PlayerMotion := preload("res://scenes/player/player_motion.gd")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var health: Health = $Health
@onready var inventory: Inventory = $Inventory
@onready var weapon: Weapon = $Weapon
@onready var interactor: Interactor = $Interactor
@onready var weapon_pickup: WeaponPickup = $WeaponPickup
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
var drop: DropPodRide  ## largage en capsule (serveur autoritaire, voir DropPodRide)
var held_weapon: WeaponModel
var _motion: PlayerMotion
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
	_motion = PlayerMotion.new(self)
	PlayerSetup.build_components(self, is_local)
	if is_local:
		PlayerSetup.build_local_ui(self)
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
	_motion.handle_input(event)


func _process(delta: float) -> void:
	_motion.apply_crouch_shape(delta)
	# Camouflage vu par les autres : le corps devient transparent.
	if buffs and body_mesh.visible:
		var speed := Vector2(velocity.x, velocity.z).length()
		body_mesh.transparency = buffs.get_cloak(speed)


func _physics_process(delta: float) -> void:
	# Largage (écran de départ ou capsule) : figé, la trajectoire vient de DropPodRide.
	if is_dropping():
		drop.step()
		return
	if is_evacuated:
		_motion.spectator_move(delta)
		return
	# Vol admin (local, menu admin) : remplace tout le déplacement.
	if admin != null and admin.fly.active and is_multiplayer_authority():
		admin.fly.step(self, delta)
		return
	_motion.step(delta)


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
## Largage en cours (écran de départ ou capsule) : ni déplacement, ni action, ni dégâts.
func is_dropping() -> bool:
	return drop != null and (drop.is_active() or MatchManager.is_drop_phase())


func can_be_hit() -> bool:
	return not health.is_dead and not is_evacuated and not is_dropping()


## Renvoie true si le coup tue le joueur. attacker_id = Config.MONSTER_KILLER_ID pour un monstre.
func server_receive_hit(amount: float, attacker_id: int) -> bool:
	return health.apply_damage(amount, attacker_id)


## Vrai si un point d'impact (coordonnées monde) est dans la zone de la tête.
func is_headshot(point: Vector3) -> bool:
	var top := global_position.y + (collision.shape as CapsuleShape3D).height
	return point.y >= top - Config.HEAD_ZONE_HEIGHT


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
