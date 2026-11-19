extends RefCounted
## Règles de validation de l'équipement de ProfileManager (kit, arme de départ, boutique, mods).

const ProfileStorage := preload("res://systems/profiles/profile_storage.gd")


static func kit_data(id: String) -> KitData:
	var path := KitController.KITS_DIR + id + ".tres"
	return load(path) as KitData if id != "" and ResourceLoader.exists(path) else null


## Arme de départ valable : une arme secondaire (pas un gadget) débloquée.
static func start_weapon_ok(peer: int, id: String) -> bool:
	var item := Items.get_item(StringName(id))
	if item == null or item.weapon == null or item.weapon.gadget != WeaponData.GadgetKind.NONE:
		return false
	return item.weapon.slot == WeaponData.Slot.SECONDARY and ProfileManager.is_unlocked(peer, item.weapon.faction, item.weapon.faction_level)


## Boutique valable : 4 armes max et 4 gadgets / capacités max, sans doublon, tout débloqué.
## Renvoie la boutique nettoyée, ou {} si refusée.
static func clean_shop(peer: int, shop: Dictionary) -> Dictionary:
	var weapons: Array = shop.get("weapons", [])
	var gadgets: Array = shop.get("gadgets", [])
	if weapons.size() > Config.SHOP_WEAPON_SLOTS or gadgets.size() > Config.SHOP_GADGET_SLOTS:
		return {}
	var out := {"weapons": [], "gadgets": []}
	for key: String in ["weapons", "gadgets"]:
		var size: int = Config.SHOP_WEAPON_SLOTS if key == "weapons" else Config.SHOP_GADGET_SLOTS
		var list: Array = shop.get(key, [])
		for i in size:
			var id := String(list[i]) if i < list.size() else ""
			if id != "":
				var kind := Shop.entry_kind(id)
				var wanted := kind == Shop.Entry.WEAPON if key == "weapons" else kind in [Shop.Entry.GADGET, Shop.Entry.ABILITY]
				if not wanted or id in out[key] or not Shop.entry_unlocked(peer, id):
					return {}
			out[key].append(id)
	return out


## Vérifie la demande d'équipement du lobby. Renvoie { "error": texte } ou
## { "loadout": {...} } prêt à être stocké (kit_mods = ceux déjà enregistrés).
static func check_request(peer: int, loadout: Dictionary, stored_kit_mods: Dictionary) -> Dictionary:
	var kit_id := String(loadout.get("kit", ""))
	var kit := kit_data(kit_id)
	if kit == null or not ProfileManager.is_unlocked(peer, kit.faction, kit.faction_level):
		return {"error": "Kit verrouillé"}
	var kit_mod := String(loadout.get("kit_mod", ""))
	if kit_mod != "" and not KitController.mod_unlocked(peer, kit, kit_mod):
		return {"error": "Mod de kit verrouillé"}
	var start := String(loadout.get("start_weapon", Config.start_loadout.base_weapon))
	if not start_weapon_ok(peer, start):
		return {"error": "Arme de départ verrouillée (ou pas une arme secondaire)"}
	var shop := clean_shop(peer, loadout.get("shop", {}))
	if shop.is_empty():
		return {"error": "Boutique refusée : objet verrouillé, en double ou mauvaise case"}
	var weapon_mods := {}
	var asked: Dictionary = loadout.get("weapon_mods", {})
	for weapon_id: String in asked:
		var mod := WeaponModData.get_mod(String(asked[weapon_id]))
		var item := Items.get_item(StringName(weapon_id))
		if mod and item and item.weapon and ProfileManager.is_unlocked(peer, mod.faction, mod.faction_level):
			weapon_mods[weapon_id] = String(mod.id)
	var kit_mods := stored_kit_mods.duplicate()
	kit_mods[kit_id] = kit_mod
	return {"loadout": {
		"kit": kit_id,
		"kit_mods": kit_mods,
		"weapon_mods": weapon_mods,
		"start_weapon": start,
		"shop": shop,
	}}
