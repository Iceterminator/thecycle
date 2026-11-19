class_name Shop
extends Node
## Boutique du joueur (touche T). Elle vend ce que le joueur a configuré dans le lobby :
## 4 cases d'armes et 4 cases de gadgets / capacités (ProfileManager.shop_of).
## - Arme pas encore possédée : capsule de largage devant le joueur (objet au sol normal).
## - Amélioration d'une arme (request_upgrade) : palier suivant, gardé par type d'arme (WeaponUpgrades).
## - Gadget / capacité pas encore sur Q ou F : il attend d'être assigné (touche Q ou F).
## - Déjà sur Q ou F : capacité améliorée (-recharge), gadget rechargé.
## Client propriétaire : affiche l'interface (ShopUi) et DEMANDE un achat ; le serveur vérifie tout.

signal purchase_result(ok: bool, message: String)

enum Entry { NONE, WEAPON, GADGET, ABILITY }

const ShopOffers := preload("res://systems/shop/shop_offers.gd")
const SHOP_UI_SCRIPT := preload("res://systems/shop/shop_ui.gd")

@onready var player: Player = get_parent()

var ui: ShopUi


func _ready() -> void:
	if player.is_multiplayer_authority():
		# Les @onready du Player (inventory, health…) ne sont prêts qu'après ses enfants.
		await player.ready
		ui = SHOP_UI_SCRIPT.new()
		add_child(ui)
		ui.setup(player, self)


# =========================================================================
# Objets de la boutique (statique : lobby, interface, serveur)
# =========================================================================

static func entry_kind(id: String) -> Entry:
	if id == "":
		return Entry.NONE
	var item := Items.get_item(StringName(id))
	if item:
		if item.weapon:
			return Entry.WEAPON if item.weapon.gadget == WeaponData.GadgetKind.NONE else Entry.GADGET
		return Entry.NONE
	return Entry.ABILITY if AbilityController.get_ability(id) != null else Entry.NONE


static func entry_name(id: String) -> String:
	var item := Items.get_item(StringName(id))
	if item:
		return item.display_name
	var ability := AbilityController.get_ability(id)
	return ability.get_display_name() if ability else id


## Prix d'achat (première fois).
static func entry_price(id: String) -> int:
	var item := Items.get_item(StringName(id))
	if item:
		return item.price
	return Config.economy.ability_price if AbilityController.get_ability(id) else 0


## [faction, niveau] requis.
static func entry_lock(id: String) -> Array:
	var item := Items.get_item(StringName(id))
	if item and item.weapon:
		return [int(item.weapon.faction), item.weapon.faction_level]
	var ability := AbilityController.get_ability(id)
	if ability:
		return [int(ability.faction), ability.faction_level]
	return [0, 0]


static func entry_unlocked(peer: int, id: String) -> bool:
	var lock := entry_lock(id)
	return ProfileManager.is_unlocked(peer, lock[0], lock[1])


## Description courte (infobulles).
static func entry_description(id: String) -> String:
	var item := Items.get_item(StringName(id))
	if item and item.weapon:
		var w := item.weapon
		if w.gadget != WeaponData.GadgetKind.NONE:
			return "Gadget — %d charge(s)" % w.magazine
		return "%d dégâts — %d coups/min — chargeur %d" % [roundi(w.damage), roundi(w.rpm), w.magazine]
	var ability := AbilityController.get_ability(id)
	if ability:
		return "Capacité — recharge %d s\n%s" % [roundi(ability.cooldown_s), ability.behavior]
	return ""


# =========================================================================
# Achat : ce qu'un clic fait maintenant (client et serveur)
# =========================================================================

## { action: "buy" | "upgrade" | "refill" | "pending", price, text, refusal }
## (le palier d'une arme est à part : upgrade_offer)
func offer(id: String) -> Dictionary:
	return ShopOffers.offer(player, id)


func _state_refusal(price: int) -> String:
	return ShopOffers.state_refusal(player, price)


@rpc("any_peer", "call_local", "reliable")
func request_buy(item_id: String) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != player.get_peer_id():
		return
	var o := offer(item_id)
	if o["refusal"] != "" or not player.inventory.spend_credits(int(o["price"])):
		_purchase_result.rpc_id(player.get_peer_id(), false, o["refusal"] if o["refusal"] != "" else "Pas assez de crédits")
		return
	var message := ShopOffers.apply(player, item_id, o)
	Events.item_purchased.emit(player.get_peer_id(), StringName(item_id), int(o["price"]))
	print("[Boutique] Joueur %d : %s %s (%d crédits)" % [player.get_peer_id(), o["action"], item_id, o["price"]])
	_purchase_result.rpc_id(player.get_peer_id(), true, message)


## Palier d'amélioration suivant d'une arme (colonne 3 de la boutique) : { price, text, refusal, level, max }.
func upgrade_offer(id: String) -> Dictionary:
	var result := WeaponUpgrades.offer(player, id)
	if result["refusal"] == "":
		result["refusal"] = _state_refusal(int(result["price"]))
	return result


@rpc("any_peer", "call_local", "reliable")
func request_upgrade(item_id: String) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player.get_peer_id():
		return
	var o := upgrade_offer(item_id)
	if o["refusal"] != "" or not player.inventory.spend_credits(int(o["price"])):
		_purchase_result.rpc_id(player.get_peer_id(), false, o["refusal"] if o["refusal"] != "" else "Pas assez de crédits")
		return
	WeaponUpgrades.server_apply(player, item_id)
	Events.item_purchased.emit(player.get_peer_id(), StringName(item_id), int(o["price"]))
	print("[Boutique] Joueur %d : amélioration %s (%d crédits)" % [player.get_peer_id(), item_id, o["price"]])
	_purchase_result.rpc_id(player.get_peer_id(), true, "%s : %s" % [entry_name(item_id), o["text"]])


@rpc("any_peer", "call_local", "reliable")
func _purchase_result(ok: bool, message: String) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	purchase_result.emit(ok, message)


## Texte d'un palier : « +10 % dégâts ».
static func boost_text(weapon: WeaponData, level: int) -> String:
	if weapon == null or level >= weapon.boosts.size():
		return "maximum"
	var names := {"damage": "dégâts", "range": "portée", "fire_rate": "cadence"}
	var parts: PackedStringArray = []
	var tier: Dictionary = weapon.boosts[level]
	for key: String in tier:
		parts.append("+%d %% %s" % [roundi(float(tier[key]) * 100.0), names.get(key, key)])
	return ", ".join(parts)
