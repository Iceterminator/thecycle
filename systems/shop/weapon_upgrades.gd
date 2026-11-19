class_name WeaponUpgrades
extends RefCounted
## Améliorations d'arme par type (boutique, colonne 3). Le palier acheté pour un id d'arme est
## gardé pour la partie (Inventory.weapon_upgrades, remis à zéro avec l'équipement). Il s'applique
## à l'exemplaire équipé et aux exemplaires achetés ensuite (livrés boostés, voir delivery_amount).
## Une arme ramassée garde ses propres paliers. Prix : Config.economy.weapon_boost_prices.


static func level_of(inv: Inventory, weapon_id: String) -> int:
	return int(inv.weapon_upgrades.get(weapon_id, 0))


static func max_level(weapon: WeaponData) -> int:
	return mini(weapon.boosts.size(), Config.economy.weapon_boost_prices.size())


## Quantité de l'objet livré en capsule : 1 + palier (le palier voyage dans la quantité au sol).
static func delivery_amount(inv: Inventory, weapon_id: String) -> int:
	return 1 + level_of(inv, weapon_id)


## { price, text, refusal, level, max } du palier suivant d'une arme de la boutique du joueur
## (hors conditions de partie : voir Shop.upgrade_offer).
static func offer(player: Player, weapon_id: String) -> Dictionary:
	var result := {"price": 0, "text": "", "refusal": "", "level": 0, "max": 0}
	var item := Items.get_item(StringName(weapon_id))
	if item == null or item.weapon == null or Shop.entry_kind(weapon_id) != Shop.Entry.WEAPON:
		result["refusal"] = "Pas une arme"
		return result
	var peer := player.get_peer_id()
	if not weapon_id in ProfileManager.shop_of(peer).get("weapons", []):
		result["refusal"] = "Pas dans votre boutique"
		return result
	if not Shop.entry_unlocked(peer, weapon_id):
		var lock := Shop.entry_lock(weapon_id)
		result["refusal"] = "Verrouillé : " + FactionData.lock_text(lock[0], lock[1])
		return result
	var level := level_of(player.inventory, weapon_id)
	result["level"] = level
	result["max"] = max_level(item.weapon)
	if level >= int(result["max"]):
		result["refusal"] = "Palier maximum"
		return result
	result["price"] = Config.economy.weapon_boost_prices[level]
	result["text"] = "Palier %d : %s" % [level + 1, Shop.boost_text(item.weapon, level)]
	return result


## Serveur : monte d'un palier et applique à l'exemplaire équipé s'il est moins amélioré.
static func server_apply(player: Player, weapon_id: String) -> void:
	var inv := player.inventory
	var level := level_of(inv, weapon_id) + 1
	var upgrades := inv.weapon_upgrades.duplicate()
	upgrades[weapon_id] = level
	inv.weapon_upgrades = upgrades
	for slot in Inventory.WEAPON_SLOTS:
		if inv.slot_ids[slot] == weapon_id and inv.slot_boosts[slot] < level:
			var boosts := inv.slot_boosts
			boosts[slot] = level
			inv.slot_boosts = boosts
