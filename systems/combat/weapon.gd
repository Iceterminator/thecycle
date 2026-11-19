class_name Weapon
extends Node
## Système de tir générique du joueur, piloté par un WeaponData (.tres) ; modes de tir : voir weapon_client.gd.
## Client propriétaire : cadence, charge, rafale, chargeur, recul, visée (ressenti), puis DEMANDE au serveur
## (request_trigger, request_fire une demande par balle) ; il n'annonce jamais « j'ai touché X ».
## Serveur : revérifie tout (propriétaire, vivant, cadence, charge, munitions, origine), ajoute la
## dispersion, fait le raycast ou simule le projectile, applique les dégâts.
## Autorité client (héritée du Player) : les RPC venant du serveur sont "any_peer" et vérifient l'expéditeur 1.
## Découpage : état, signaux et TOUS les @rpc restent ici (résolus par chemin) ; logique dans weapon_*.gd.

signal ammo_changed(ammo: int, magazine_size: int, reloading: bool)
signal hit_confirmed(headshot: bool, killed: bool)
## Charge ou montée en régime en cours (0 à 1), pour le HUD.
signal charge_changed(ratio: float)

enum HitKind { NONE, WORLD, TARGET }

## Explosions : dégâts au bord de la zone (part des dégâts au centre).
const EXPLOSION_EDGE_RATIO := 0.25

const WeaponClient := preload("res://systems/combat/weapon_client.gd")
const WeaponServerFire := preload("res://systems/combat/weapon_server_fire.gd")
const WeaponDamage := preload("res://systems/combat/weapon_damage.gd")
const WeaponProjectiles := preload("res://systems/combat/weapon_projectiles.gd")
const WeaponGadgets := preload("res://systems/combat/weapon_gadgets.gd")
const WeaponEffects := preload("res://systems/combat/weapon_effects.gd")
const WeaponEquip := preload("res://systems/combat/weapon_equip.gd")
const WeaponServerState := preload("res://systems/combat/weapon_server_state.gd")

## Arme en main : suit l'emplacement actif de l'Inventory (synchronisé par le serveur).
var data: WeaponData

@onready var player: Player = get_parent()
@onready var head: Node3D = $"../Head"
@onready var camera: Camera3D = $"../Head/Camera3D"
@onready var health: Health = $"../Health"
@onready var inventory: Inventory = $"../Inventory"

# --- État client (prédiction locale, pour le ressenti) ---
var ammo: int = 0
var is_reloading: bool = false
var is_aiming: bool = false
var _fire_cooldown: float = 0.0
var _reload_left: float = 0.0
var _burst_left: int = 0          # tirs restants dans la rafale en cours
var _burst_timer: float = 0.0     # s avant le prochain tir de la rafale
var _holding: bool = false        # charge ou rayon en cours (gâchette maintenue)
var _hold_time: float = 0.0       # s depuis le début de la charge / du rayon
var _hold_hp: float = 0.0         # PV + bouclier au début de la charge (balise de rappel)

# --- État serveur (c'est lui qui fait foi ; le chargeur est dans Inventory.slot_ammo) ---
var _srv := WeaponServerState.new()

var _client := WeaponClient.new(self)
var _server_fire := WeaponServerFire.new(self)
var _damage := WeaponDamage.new(self)
var _projectiles := WeaponProjectiles.new(self)
var _gadgets := WeaponGadgets.new(self)
var _effects := WeaponEffects.new(self)
var _equip := WeaponEquip.new(self)


func _ready() -> void:
	data = inventory.get_active_weapon()
	ammo = inventory.get_active_ammo()
	_srv.tokens = _server_fire.token_capacity()
	_srv.last_ms = Time.get_ticks_msec()
	inventory.active_weapon_changed.connect(_equip.on_active_weapon_changed)
	inventory.changed.connect(_equip.on_inventory_changed)
	set_process(player.is_multiplayer_authority())
	set_physics_process(multiplayer.is_server())


func _process(delta: float) -> void:
	if data == null: return
	_client.update(delta)


func _emit_ammo() -> void:
	ammo_changed.emit(ammo, player.magazine_for(data), is_reloading)


## Le serveur corrige le chargeur du client (refus de tir, réapparition).
@rpc("any_peer", "call_local", "reliable")
func _sync_ammo(value: int) -> void:
	if multiplayer.get_remote_sender_id() != 1: return
	ammo = value
	is_reloading = false
	_burst_left = 0
	_emit_ammo()


@rpc("any_peer", "call_local", "reliable")
func _confirm_hit(headshot: bool, killed: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1: return
	hit_confirmed.emit(headshot, killed)


@rpc("any_peer", "call_local", "reliable")
func request_reload() -> void:
	if not multiplayer.is_server() or not _sender_is_owner(): return
	if health.is_dead or _srv.reload_end_ms > 0 or inventory.get_active_ammo() >= player.magazine_for(data):
		return
	_equip.server_start_reload()


## Début (pressed = true) ou fin d'une charge / d'un rayon : le serveur chronomètre lui-même.
@rpc("any_peer", "call_local", "reliable")
func request_trigger(pressed: bool) -> void:
	if not multiplayer.is_server() or not _sender_is_owner(): return
	_srv.set_trigger(pressed)


## Une demande = une balle (une rafale de 3 envoie 3 demandes, un rayon une par tick).
@rpc("any_peer", "call_local", "reliable")
func request_fire(origin: Vector3, direction: Vector3, aiming: bool) -> void:
	if not multiplayer.is_server():
		return
	if not _sender_is_owner():
		push_warning("[Weapon] Tir refusé : le peer %d tire avec l'arme du joueur %d" % [multiplayer.get_remote_sender_id(), player.get_peer_id()])
		return
	if health.is_dead or health.is_downed or player.is_evacuated or player.is_dropping():
		return
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.01:
		return
	_server_fire.handle_fire(origin, direction, aiming)


## Fait avancer les projectiles (serveur uniquement).
func _physics_process(delta: float) -> void:
	if _srv.projectiles.is_empty():
		return
	_projectiles.update(delta)


## Réapparition : à appeler après Inventory.reset_loadout().
func server_refill() -> void:
	_equip.server_refill()


func _sender_is_owner() -> bool:
	return multiplayer.get_remote_sender_id() == player.get_peer_id()


## Boost de l'arme en main (palier acheté en boutique) : 1.0 = aucun.
func _boost(key: String) -> float:
	return data.get_boost(key, inventory.get_active_boost()) if data else 1.0


## Rayon vital : clic droit = se soigner (coûte Config.combat.heal_beam_self_cost charges).
@rpc("any_peer", "call_local", "reliable")
func request_gadget_alt() -> void:
	if not multiplayer.is_server() or not _sender_is_owner() or health.is_dead or player.is_evacuated or player.is_dropping(): return
	_gadgets.self_heal()


# --- Effets visuels (tous les clients), dessin dans weapon_effects.gd ---

@rpc("any_peer", "call_local", "unreliable")
func _show_shot(origin: Vector3, end: Vector3, kind: int) -> void:
	if multiplayer.get_remote_sender_id() != 1: return
	_effects.show_shot(origin, end, kind)


@rpc("any_peer", "call_local", "reliable")
func _show_projectile(id: int, origin: Vector3, dir: Vector3, speed: float, max_dist: float) -> void:
	if multiplayer.get_remote_sender_id() != 1: return
	_effects.show_projectile(id, origin, dir, speed, max_dist)


@rpc("any_peer", "call_local", "reliable")
func _show_projectile_end(id: int, point: Vector3, kind: int) -> void:
	if multiplayer.get_remote_sender_id() != 1: return
	_effects.show_projectile_end(id, point, kind)


@rpc("any_peer", "call_local", "unreliable")
func _show_explosion(point: Vector3, radius: float) -> void:
	if multiplayer.get_remote_sender_id() != 1: return
	_effects.show_explosion(point, radius)
