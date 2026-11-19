class_name Inventory
extends Node
## Inventaire d'un joueur : 2 emplacements d'arme (0, 1), 2 de gadget (2 = Q, 3 = F, remplis par
## AbilityController), ressources portées, crédits. SEUL LE SERVEUR le modifie ; InventorySync
## (autorité 1, voir player.gd::_enter_tree) l'envoie à tous. Le client propriétaire lit les touches
## (1 / 2 / molette) et envoie des demandes. Ramassage d'armes : WeaponPickup. Règles provisoires.

signal changed
signal active_weapon_changed

const WEAPON_SLOTS := 2  ## emplacements 0 et 1 ; 2 et 3 = gadgets de Q et F

## Ids d'objet des 2 emplacements ("" = vide). Toujours réassigner le tableau entier
## (via server_set_slot) pour que le setter et la synchro voient le changement.
var slot_ids: PackedStringArray = PackedStringArray([String(Config.start_loadout.base_weapon), "", "", ""]):
	set(value):
		slot_ids = value
		_slots.after_change()
## Chargeur de chaque emplacement (c'est le compteur du serveur qui fait foi).
var slot_ammo: PackedInt32Array = PackedInt32Array([0, 0, 0, 0]):
	set(value):
		slot_ammo = value
		changed.emit()
## Palier de boost de chaque emplacement (0 à 3, voir WeaponData.boosts). Synchronisé par
## BoostSync (créé en code). Une arme lâchée garde son palier (quantité au sol = 1 + palier).
var slot_boosts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0]):
	set(value):
		slot_boosts = value
		changed.emit()
## Palier d'amélioration acheté en boutique, par id d'arme (voir WeaponUpgrades). Synchronisé
## par BoostSync ; toujours réassigner le dictionnaire entier. Remis à zéro avec l'équipement.
var weapon_upgrades: Dictionary = {}:
	set(value):
		weapon_upgrades = value
		changed.emit()
var active_slot: int = 0:
	set(value):
		active_slot = value
		_slots.after_change()
var credits: int = 0:
	set(value):
		credits = value
		changed.emit()
## Ressources de contrat portées (id -> quantité), ex. biomasse, Lumicèpes.
## Toujours réassigner le dictionnaire entier pour la synchro.
var carried: Dictionary = {}:
	set(value):
		carried = value
		changed.emit()

@onready var player: Player = get_parent()
@onready var health: Health = $"../Health"

const InventoryGadgets := preload("res://systems/inventory/inventory_gadgets.gd")
const InventorySlots := preload("res://systems/inventory/inventory_slots.gd")
const InventoryDeath := preload("res://systems/inventory/inventory_death.gd")
const InventoryPickup := preload("res://systems/inventory/inventory_pickup.gd")
const InventoryBoostSync := preload("res://systems/inventory/inventory_boost_sync.gd")

var _last_active_id: String = ""

var _gadgets: InventoryGadgets
var _death: InventoryDeath
var _pickup: InventoryPickup
var _slots: InventorySlots

func _ready() -> void:
	_last_active_id = "%d:%s" % [active_slot, slot_ids[active_slot]]
	if multiplayer.is_server():
		reset_loadout()
		health.dead_changed.connect(_death.on_dead_changed)
	set_process_unhandled_input(player.is_multiplayer_authority())

func get_active_id() -> StringName:
	return StringName(slot_ids[active_slot])

func get_active_weapon() -> WeaponData:
	var item := Items.get_item(get_active_id())
	return item.weapon if item else null

func get_active_ammo() -> int:
	return slot_ammo[active_slot]

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or health.is_dead:
		return
	_slots.handle_input(event)

@rpc("any_peer", "call_local", "reliable")
func request_switch(slot: int) -> void:
	if not multiplayer.is_server() or not _sender_is_owner() or health.is_dead:
		return
	if slot < 0 or slot >= slot_ids.size() or slot == active_slot or slot_ids[slot] == "":
		return
	active_slot = slot

## Serveur : équipement de base (réapparition). Les crédits sont conservés.
## L'arme de départ est celle du profil (choisie dans le lobby parmi les armes secondaires).
func reset_loadout() -> void:
	_slots.reset_loadout()

## Serveur : met à jour le chargeur de l'arme en main.
func set_active_ammo(value: int) -> void:
	_slots.set_active_ammo(value)

## Serveur : essaie de prendre un objet ramassé. Renvoie false si impossible (plein).
func server_take(item: ItemData, amount: int, ammo: int) -> bool:
	return _pickup.take(item, amount, ammo)

func get_resource(item_id: StringName) -> int:
	return carried.get(String(item_id), 0)

## Serveur : retire toute une ressource portée (dépôt à un collecteur). Renvoie la quantité.
func take_resource(item_id: StringName) -> int:
	return _pickup.take_resource(item_id)

## Serveur : dépense des crédits (achat). Renvoie false si pas assez.
func spend_credits(amount: int) -> bool:
	if amount < 0 or credits < amount:
		return false
	credits -= amount
	Events.credits_changed.emit(player.get_peer_id(), credits)
	return true

func add_credits(amount: int) -> void:
	credits += amount
	Events.credits_changed.emit(player.get_peer_id(), credits)

func server_set_slot(slot: int, item_id: StringName, ammo: int, boost: int = 0) -> void:
	_slots.set_slot(slot, item_id, ammo, boost)

func _sender_is_owner() -> bool:
	return multiplayer.get_remote_sender_id() == player.get_peer_id()

## Serveur : nouvelle partie. Équipement de base, plus de crédits ni de ressources.
func server_reset() -> void:
	reset_loadout()
	carried = {}
	credits = 0
	Events.credits_changed.emit(player.get_peer_id(), credits)

func _init() -> void:
	_gadgets = InventoryGadgets.new(self)
	_death = InventoryDeath.new(self)
	_pickup = InventoryPickup.new(self)
	_slots = InventorySlots.new(self)
	add_child(InventoryBoostSync.create())

func get_active_boost() -> int:
	return slot_boosts[active_slot] if active_slot < slot_boosts.size() else 0

## Serveur : monte d'un palier le boost de l'arme en main.
func server_boost_active() -> void:
	_slots.boost_slot(active_slot)

## Serveur : retire l'arme en main (gadget épuisé), voir InventoryGadgets.
func server_remove_active() -> void:
	_gadgets.remove_active()

## Serveur : met un gadget dans l'emplacement de Q (0) ou F (1), chargeur plein.
func server_set_gadget(key_slot: int, item_id: StringName) -> void:
	_gadgets.set_gadget(key_slot, item_id)

## Serveur : vide l'emplacement de gadget de Q (0) ou F (1) ; s'il était en main, on reprend l'arme 1.
func server_clear_gadget(key_slot: int) -> void:
	_gadgets.clear_gadget(key_slot)

## Serveur : recharge le gadget de Q (0) ou F (1) (rachat en boutique).
func server_refill_gadget(key_slot: int) -> void:
	_gadgets.refill_gadget(key_slot)

## Serveur : monte d'un palier le boost de l'arme d'un emplacement (rachat en boutique).
func server_boost_slot(slot: int) -> void:
	_slots.boost_slot(slot)

## Emplacement d'arme (0 / 1) qui contient cet objet, -1 sinon.
func weapon_slot_of(item_id: StringName) -> int:
	for i in WEAPON_SLOTS:
		if StringName(slot_ids[i]) == item_id:
			return i
	return -1
