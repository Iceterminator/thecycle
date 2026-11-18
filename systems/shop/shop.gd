class_name Shop
extends Node
## Boutique du joueur (touche T). Elle vend ce que le joueur a configuré dans le lobby :
## 4 cases d'armes et 4 cases de gadgets / capacités (ProfileManager.shop_of), plus les
## consommables (soins, cellules de bouclier), toujours en vente.
## - Arme pas encore possédée : capsule de largage devant le joueur (objet au sol normal).
## - Arme déjà dans l'inventaire : palier de boost suivant (WeaponData.boosts, Config.economy.weapon_boost_prices).
## - Gadget / capacité pas encore sur Q ou F : il attend d'être assigné (touche Q ou F).
## - Déjà sur Q ou F : capacité améliorée (-recharge), gadget rechargé.
## Client propriétaire : affiche l'interface (ShopUi) et DEMANDE un achat ; le serveur vérifie tout.

signal purchase_result(ok: bool, message: String)

enum Entry { NONE, WEAPON, GADGET, ABILITY, CONSUMABLE }

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
		if item.kind in [ItemData.Kind.HEAL, ItemData.Kind.SHIELD_RECHARGE]:
			return Entry.CONSUMABLE
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


## Consommables toujours en vente.
static func consumables() -> Array[String]:
	var out: Array[String] = []
	for item in Items.get_shop_items():
		if entry_kind(String(item.id)) == Entry.CONSUMABLE:
			out.append(String(item.id))
	return out


# =========================================================================
# Achat : ce qu'un clic fait maintenant (client et serveur)
# =========================================================================

## { action: "buy" | "boost" | "upgrade" | "refill" | "pending", price, text, refusal }
func offer(id: String) -> Dictionary:
	var peer := player.get_peer_id()
	var kind := entry_kind(id)
	var result := {"action": "buy", "price": entry_price(id), "text": "", "refusal": ""}
	if kind == Entry.NONE or (kind != Entry.ABILITY and int(result["price"]) <= 0):
		result["refusal"] = "Pas en vente"
		return result
	if kind != Entry.CONSUMABLE:
		var shop := ProfileManager.shop_of(peer)
		var list: Array = shop.get("weapons" if kind == Entry.WEAPON else "gadgets", [])
		if not id in list:
			result["refusal"] = "Pas dans votre boutique"
			return result
		if not entry_unlocked(peer, id):
			var lock := entry_lock(id)
			result["refusal"] = "Verrouillé : " + FactionData.lock_text(lock[0], lock[1])
			return result
	match kind:
		Entry.WEAPON:
			var slot := player.inventory.weapon_slot_of(StringName(id))
			if slot >= 0:
				var weapon := Items.get_item(StringName(id)).weapon
				var level: int = player.inventory.slot_boosts[slot]
				result["action"] = "boost"
				if level >= mini(weapon.boosts.size(), Config.economy.weapon_boost_prices.size()):
					result["refusal"] = "Palier maximum"
					result["price"] = 0
				else:
					result["price"] = Config.economy.weapon_boost_prices[level]
					result["text"] = "Palier %d : %s" % [level + 1, boost_text(weapon, level)]
		Entry.GADGET, Entry.ABILITY:
			var key_slot := Array(player.abilities.loadout).find(id)
			if key_slot >= 0:
				if kind == Entry.ABILITY:
					result["action"] = "upgrade"
					result["price"] = Config.economy.ability_upgrade_price
					var level: int = player.abilities.upgrades[key_slot]
					result["text"] = "Amélioration %d/%d : -%d s de recharge" % [level + 1, Config.economy.ability_max_upgrades, roundi(AbilityController.get_ability(id).upgrade_cooldown_s)]
					if level >= Config.economy.ability_max_upgrades:
						result["refusal"] = "Amélioration maximum"
				else:
					result["action"] = "refill"
					result["text"] = "Recharger les charges"
			else:
				result["action"] = "pending"
				result["text"] = "Puis Q ou F pour l'équiper"
				if player.abilities.pending != "":
					result["refusal"] = "Équipez d'abord %s (Q ou F)" % entry_name(player.abilities.pending)
	if result["refusal"] == "":
		result["refusal"] = _state_refusal(int(result["price"]))
	return result


func _state_refusal(price: int) -> String:
	if MatchManager.is_lobby():
		return "Indisponible dans le lobby"
	if player.health.is_dead:
		return "Indisponible : vous êtes mort"
	if player.is_evacuated:
		return "Indisponible : vous êtes à bord"
	if player.health.is_downed:
		return "Indisponible : vous êtes à terre"
	if player.inventory.credits < price:
		return "Pas assez de crédits"
	return ""


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
	var name := entry_name(item_id)
	var message := ""
	match String(o["action"]):
		"buy":
			var forward := -player.global_basis.z
			forward.y = 0.0
			var pos := player.global_position + forward.normalized() * Config.DROP_POD_DISTANCE
			Events.drop_pod_requested.emit(StringName(item_id), pos)
			message = "%s : largage en approche !" % name
		"boost":
			var slot := player.inventory.weapon_slot_of(StringName(item_id))
			player.inventory.server_boost_slot(slot)
			message = "%s : %s" % [name, o["text"]]
		"upgrade":
			player.abilities.server_upgrade(Array(player.abilities.loadout).find(item_id))
			message = "%s : %s" % [name, o["text"]]
		"refill":
			player.inventory.server_refill_gadget(Array(player.abilities.loadout).find(item_id))
			message = "%s rechargé" % name
		"pending":
			player.abilities.server_offer(item_id)
			message = "%s acheté : appuyez sur Q ou F pour l'équiper" % name
	Events.item_purchased.emit(player.get_peer_id(), StringName(item_id), int(o["price"]))
	print("[Boutique] Joueur %d : %s %s (%d crédits)" % [player.get_peer_id(), o["action"], item_id, o["price"]])
	_purchase_result.rpc_id(player.get_peer_id(), true, message)


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
