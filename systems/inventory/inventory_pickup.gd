extends RefCounted
## Prise d'objets ramassés et ressources portées d'un inventaire. Serveur uniquement.

var _inv: Inventory


func _init(inventory: Inventory) -> void:
	_inv = inventory


## Essaie de prendre un objet ramassé. Renvoie false si impossible (plein).
func take(item: ItemData, amount: int, ammo: int) -> bool:
	match item.kind:
		ItemData.Kind.WEAPON:
			# Gadget ramassé : il attend d'être assigné à Q ou F (comme un achat).
			if item.weapon.gadget != WeaponData.GadgetKind.NONE:
				return _inv.player.abilities.server_offer(String(item.id)) == ""
			_inv.player.weapon_pickup.server_take(item, amount, ammo, -1)
		ItemData.Kind.CREDITS:
			_inv.add_credits(amount)
		ItemData.Kind.SHIELD_UPGRADE:
			return false  # ancien système : le bouclier vient du kit (étape 8b)
		ItemData.Kind.RESOURCE:
			var have := _inv.get_resource(item.id)
			var room := (item.max_carry - have) if item.max_carry > 0 else amount
			if room <= 0:
				return false
			var c := _inv.carried.duplicate()
			c[String(item.id)] = have + mini(amount, room)
			_inv.carried = c
	return true


## Retire toute une ressource portée (dépôt à un collecteur). Renvoie la quantité.
func take_resource(item_id: StringName) -> int:
	var n := _inv.get_resource(item_id)
	if n > 0:
		var c := _inv.carried.duplicate()
		c.erase(String(item_id))
		_inv.carried = c
	return n
