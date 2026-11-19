extends RefCounted
## Règles de la boutique, partagées client / serveur : ce qu'un clic fait maintenant (offre),
## raisons de refus, et application d'un achat côté serveur. Appelé depuis Shop.

## { action: "buy" | "upgrade" | "refill" | "pending", price, text, refusal }
## (le palier d'une arme est à part : upgrade_offer)
static func offer(player: Player, id: String) -> Dictionary:
	var peer := player.get_peer_id()
	var kind := Shop.entry_kind(id)
	var result := {"action": "buy", "price": Shop.entry_price(id), "text": "", "refusal": ""}
	if kind == Shop.Entry.NONE or (kind != Shop.Entry.ABILITY and int(result["price"]) <= 0):
		result["refusal"] = "Pas en vente"
		return result
	var shop := ProfileManager.shop_of(peer)
	var list: Array = shop.get("weapons" if kind == Shop.Entry.WEAPON else "gadgets", [])
	if not id in list:
		result["refusal"] = "Pas dans votre boutique"
		return result
	if not Shop.entry_unlocked(peer, id):
		var lock := Shop.entry_lock(id)
		result["refusal"] = "Verrouillé : " + FactionData.lock_text(lock[0], lock[1])
		return result
	match kind:
		Shop.Entry.GADGET, Shop.Entry.ABILITY:
			var key_slot := Array(player.abilities.loadout).find(id)
			if key_slot >= 0:
				if kind == Shop.Entry.ABILITY:
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
					result["refusal"] = "Équipez d'abord %s (Q ou F)" % Shop.entry_name(player.abilities.pending)
	if result["refusal"] == "":
		result["refusal"] = state_refusal(player, int(result["price"]))
	return result


static func state_refusal(player: Player, price: int) -> String:
	if MatchManager.is_lobby():
		return "Indisponible dans le lobby"
	if player.health.is_dead:
		return "Indisponible : vous êtes mort"
	if player.is_evacuated or player.is_dropping():
		return "Indisponible : vous êtes à bord"
	if player.health.is_downed:
		return "Indisponible : vous êtes à terre"
	if player.inventory.credits < price:
		return "Pas assez de crédits"
	return ""


## Serveur : applique l'achat `o` (issu de offer) de `item_id` et renvoie le message pour le joueur.
static func apply(player: Player, item_id: String, o: Dictionary) -> String:
	var name := Shop.entry_name(item_id)
	match String(o["action"]):
		"buy":
			var forward := -player.global_basis.z
			forward.y = 0.0
			var pos := player.global_position + forward.normalized() * Config.DROP_POD_DISTANCE
			Events.drop_pod_requested.emit(StringName(item_id), pos, WeaponUpgrades.delivery_amount(player.inventory, item_id))  # livrée déjà améliorée
			return "%s : largage en approche !" % name
		"upgrade":
			player.abilities.server_upgrade(Array(player.abilities.loadout).find(item_id))
			return "%s : %s" % [name, o["text"]]
		"refill":
			player.inventory.server_refill_gadget(Array(player.abilities.loadout).find(item_id))
			return "%s rechargé" % name
		"pending":
			player.abilities.server_offer(item_id)
			return "%s acheté : appuyez sur Q ou F pour l'équiper" % name
	return ""
