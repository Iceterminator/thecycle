class_name Inventory
extends Node
## Inventaire d'un joueur : 2 emplacements d'arme (0, 1), 2 emplacements de gadget (2 = Q, 3 = F,
## remplis par AbilityController quand un gadget est assigné), ressources portées, crédits.
## SEUL LE SERVEUR le modifie ; InventorySync (autorité 1, voir player.gd::_enter_tree)
## l'envoie à tous les clients. Le client propriétaire lit les touches
## (1 / 2 / molette) et envoie des demandes. Le ramassage d'armes est dans WeaponPickup.
## Valeurs et règles provisoires : à revoir avec la boucle de partie complète.

signal changed
signal active_weapon_changed

const WEAPON_SLOTS := 2  ## emplacements 0 et 1 ; 2 et 3 = gadgets de Q et F

## Ids d'objet des 2 emplacements ("" = vide). Toujours réassigner le tableau entier
## (via server_set_slot) pour que le setter et la synchro voient le changement.
var slot_ids: PackedStringArray = PackedStringArray([String(Config.start_loadout.base_weapon), "", "", ""]):
	set(value):
		slot_ids = value
		_after_change()
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
		_after_change()
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
const InventoryDeath := preload("res://systems/inventory/inventory_death.gd")
const InventoryPickup := preload("res://systems/inventory/inventory_pickup.gd")
const InventoryBoostSync := preload("res://systems/inventory/inventory_boost_sync.gd")

var _last_active_id: String = ""

var _gadgets: InventoryGadgets
var _death: InventoryDeath
var _pickup: InventoryPickup


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


func _after_change() -> void:
	changed.emit()
	if slot_ids.size() <= active_slot:
		return
	# Un emplacement actif vide n'est qu'un état transitoire (slot_ids et active_slot
	# changent l'un après l'autre) : on attend la valeur suivante.
	# La clé inclut l'emplacement : passer d'un fusil à un autre fusil est un vrai changement.
	var key := "%d:%s" % [active_slot, slot_ids[active_slot]]
	if slot_ids[active_slot] != "" and key != _last_active_id:
		_last_active_id = key
		active_weapon_changed.emit()


# =========================================================================
# Client propriétaire : touches -> demandes au serveur
# =========================================================================


func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or health.is_dead:
		return
	if event.is_action_pressed("slot_1"):
		_ask_switch(0)
	elif event.is_action_pressed("slot_2"):
		_ask_switch(1)
	elif event.is_action_pressed("next_weapon") or event.is_action_pressed("prev_weapon"):
		_ask_switch(1 - active_slot if active_slot < WEAPON_SLOTS else 0)


func _ask_switch(slot: int) -> void:
	if slot != active_slot and slot_ids[slot] != "":
		request_switch.rpc_id(1, slot)


# =========================================================================
# Serveur
# =========================================================================


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
	slot_boosts = PackedInt32Array([0, 0, 0, 0])
	weapon_upgrades = {}
	var base_id := player.start_weapon_id()
	var base := Items.get_item(base_id)
	slot_ammo = PackedInt32Array([player.magazine_for(base.weapon), 0, 0, 0])
	active_slot = 0
	_last_active_id = ""
	slot_ids = PackedStringArray([String(base_id), "", "", ""])


## Serveur : met à jour le chargeur de l'arme en main.
func set_active_ammo(value: int) -> void:
	var a := slot_ammo
	a[active_slot] = value
	slot_ammo = a


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
	var b := slot_boosts
	b[slot] = boost
	slot_boosts = b
	var a := slot_ammo
	a[slot] = ammo
	slot_ammo = a  # le chargeur d'abord : il est prêt quand l'arme change
	if slot == active_slot:
		_last_active_id = ""  # même modèle d'arme échangé : on force le changement
	var ids := slot_ids
	ids[slot] = String(item_id)
	slot_ids = ids


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
	add_child(InventoryBoostSync.create())


func get_active_boost() -> int:
	return slot_boosts[active_slot] if active_slot < slot_boosts.size() else 0


## Serveur : monte d'un palier le boost de l'arme en main.
func server_boost_active() -> void:
	var b := slot_boosts
	b[active_slot] += 1
	slot_boosts = b


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
	var b := slot_boosts
	b[slot] += 1
	slot_boosts = b


## Emplacement d'arme (0 / 1) qui contient cet objet, -1 sinon.
func weapon_slot_of(item_id: StringName) -> int:
	for i in WEAPON_SLOTS:
		if StringName(slot_ids[i]) == item_id:
			return i
	return -1
