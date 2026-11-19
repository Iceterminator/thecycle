extends RefCounted
## Emplacements de l'onglet Équipement : "start", "kit", "w0".."w3", "g0".."g3".
## Lit et modifie l'état de l'équipement porté par LobbyUi.


static func slot_id(lobby: LobbyUi, slot: String) -> String:
	match slot:
		"start":
			return lobby._start_weapon
		"kit":
			return lobby._kit_id
	var index := int(slot.substr(1))
	return String(lobby._shop_weapons[index] if slot.begins_with("w") else lobby._shop_gadgets[index])


static func slot_title(slot: String) -> String:
	match slot:
		"start":
			return "arme de départ"
		"kit":
			return "combinaison"
	return "arme" if slot.begins_with("w") else "gadget ou capacité"


## Catégories du catalogue acceptées par l'emplacement.
static func slot_cats(slot: String) -> Array:
	match slot:
		"start":
			return [LobbyUi.Cat.SECONDARY]
		"kit":
			return [LobbyUi.Cat.KIT]
	return [LobbyUi.Cat.PRIMARY, LobbyUi.Cat.SECONDARY] if slot.begins_with("w") else [LobbyUi.Cat.GADGET, LobbyUi.Cat.ABILITY]


static func equip(lobby: LobbyUi, slot: String, id: String) -> void:
	match slot:
		"start":
			lobby._start_weapon = id
		"kit":
			lobby._kit_id = id
		_:
			var list: Array = lobby._shop_weapons if slot.begins_with("w") else lobby._shop_gadgets
			var index := int(slot.substr(1))
			var already := list.find(id)
			if already >= 0:
				list[already] = list[index]  # déjà dans une autre case : on échange
			list[index] = id
	lobby._changed()
