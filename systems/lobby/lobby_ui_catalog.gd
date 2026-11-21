extends RefCounted
## Catalogue du lobby (armes, gadgets, capacités, kits) et table des déblocages par faction.
## Entrée : { id, cat, name, faction, level, price, weapon, kit } ; cat = LobbyUi.Cat.


static func build() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	for item in Items.get_items_of_kind(ItemData.Kind.WEAPON):
		var w := item.weapon
		if w == null:
			continue
		var cat := LobbyUi.Cat.GADGET if w.gadget != WeaponData.GadgetKind.NONE \
				else (LobbyUi.Cat.SECONDARY if w.slot == WeaponData.Slot.SECONDARY else LobbyUi.Cat.PRIMARY)
		catalog.append({"id": String(item.id), "cat": cat, "name": item.display_name, "faction": int(w.faction),
				"level": w.faction_level, "price": item.price, "weapon": w, "kit": null})
	for a in AbilityController.list_abilities():
		catalog.append({"id": String(a.id), "cat": LobbyUi.Cat.ABILITY, "name": a.get_display_name(), "faction": int(a.faction),
				"level": a.faction_level, "price": Config.economy.ability_price, "weapon": null, "kit": null})
	for k in KitController.list_kits():
		catalog.append({"id": String(k.id), "cat": LobbyUi.Cat.KIT, "name": KitController.kit_name(k), "faction": int(k.faction),
				"level": k.faction_level, "price": 0, "weapon": null, "kit": k})
	return catalog


## faction -> niveau -> noms des objets débloqués (armes, kits, capacités, mods de kit).
static func unlock_table(catalog: Array[Dictionary]) -> Dictionary:
	var table := {}
	var entries: Array = []  # [faction, niveau, texte]
	for e in catalog:
		entries.append([e["faction"], e["level"], ("kit " if e["cat"] == LobbyUi.Cat.KIT else "") + String(e["name"])])
		if e["cat"] == LobbyUi.Cat.KIT:
			for m: Dictionary in (e["kit"] as KitData).mods:
				entries.append([e["faction"], int(m.get("unlock_level", 0)), "mod " + String(e["name"])])
	for e: Array in entries:
		var faction: int = e[0]
		var level: int = e[1]
		if faction <= 0 or level <= 0:
			continue
		if not table.has(faction):
			table[faction] = {}
		if not table[faction].has(level):
			table[faction][level] = []
		table[faction][level].append(e[2])
	return table
