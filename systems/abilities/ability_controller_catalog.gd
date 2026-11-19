extends RefCounted
## Accès aux données de capacités et de gadgets (fonctions statiques) pour AbilityController.

const ABILITIES_DIR := "res://data/abilities/"


static func get_ability(id: String) -> AbilityData:
	if id == "" or not ResourceLoader.exists(ABILITIES_DIR + id + ".tres"):
		return null
	return load(ABILITIES_DIR + id + ".tres") as AbilityData


static func list_abilities() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for file in ResourceLoader.list_directory(ABILITIES_DIR):
		var a: AbilityData = load(ABILITIES_DIR + file) as AbilityData if file.ends_with(".tres") else null
		if a:
			result.append(a)
	result.sort_custom(func(x: AbilityData, y: AbilityData) -> bool: return x.get_display_name() < y.get_display_name())
	return result


## Un gadget (objet arme de type gadget) ?
static func is_gadget(id: String) -> bool:
	var item := Items.get_item(StringName(id)) if id != "" else null
	return item != null and item.weapon != null and item.weapon.gadget != WeaponData.GadgetKind.NONE
