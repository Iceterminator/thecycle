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
## loadout["kit_mod"] : { "core", "1", "2", "3" } -> id des mods du kit choisi.
static func check_request(peer: int, loadout: Dictionary, stored_kit_mods: Dictionary) -> Dictionary:
	var kit_id := String(loadout.get("kit", ""))
	var kit := kit_data(kit_id)
	if kit == null or not ProfileManager.is_unlocked(peer, kit.faction, kit.faction_level):
		return {"error": "Kit verrouillé"}
	var kit_slots_asked := kit_slots(loadout.get("kit_mod", {}))
	var mod_error := kit_mods_error(peer, kit, kit_slots_asked)
	if mod_error != "":
		return {"error": mod_error}
	var start := String(loadout.get("start_weapon", Config.start_loadout.base_weapon))
	if not start_weapon_ok(peer, start):
		return {"error": "Arme de départ verrouillée (ou pas une arme secondaire)"}
	var shop := clean_shop(peer, loadout.get("shop", {}))
	if shop.is_empty():
		return {"error": "Boutique refusée : objet verrouillé, en double ou mauvaise case"}
	var weapon_mods := clean_weapon_mods(peer, loadout.get("weapon_mods", {}))
	var kit_mods := {}
	for stored_kit: String in stored_kit_mods:
		kit_mods[stored_kit] = kit_slots(stored_kit_mods[stored_kit])
	kit_mods[kit_id] = kit_slots_asked
	return {"loadout": {
		"kit": kit_id,
		"kit_mods": kit_mods,
		"weapon_mods": weapon_mods,
		"start_weapon": start,
		"shop": shop,
		"appearance": appearance_ok(String(loadout.get("appearance", ""))),
	}}


## Apparence valable (id d'un fichier de data/appearances/), sinon "" (choix automatique).
static func appearance_ok(id: String) -> String:
	return id if AppearanceData.get_by_id(id) != null else ""


## Mods d'arme valables : { id_arme: { "emplacement": id_mod } }. Un mod doit exister, appartenir
## à l'arme et à l'emplacement de sa clé, et l'arme doit être débloquée. Ancien format
## (valeur texte) et entrées invalides : ignorés.
static func clean_weapon_mods(peer: int, asked: Dictionary) -> Dictionary:
	var out := {}
	for weapon_id: String in asked:
		var item := Items.get_item(StringName(weapon_id))
		var slots: Variant = asked[weapon_id]
		if item == null or item.weapon == null or not slots is Dictionary:
			continue
		if not ProfileManager.is_unlocked(peer, item.weapon.faction, item.weapon.faction_level):
			continue
		var kept := {}
		for slot_key: String in slots:
			var mod := WeaponModData.get_mod(String(slots[slot_key]))
			if mod and mod.weapon_id == StringName(weapon_id) and str(int(mod.slot)) == slot_key:
				kept[slot_key] = String(mod.id)
		if not kept.is_empty():
			out[weapon_id] = kept
	return out


## Mods d'un kit : { "core": id, "1": id, "2": id, "3": id } (emplacements vides absents).
## Ancien format (un seul id en texte) : c'était le cœur. Tout le reste est ignoré.
static func kit_slots(raw: Variant) -> Dictionary:
	var out := {}
	if raw is String or raw is StringName:
		if String(raw) != "":
			out["core"] = String(raw)
	elif raw is Dictionary:
		for key: String in KitModData.SLOTS:
			var value: Variant = raw.get(key, "")
			if value is String and value != "":
				out[key] = value
	return out


## Message d'erreur si un mod demandé est refusé (cœur verrouillé, mod inconnu ou au mauvais
## niveau), "" sinon. Les mods de niveau 1 à 3 sont ouverts à tous.
static func kit_mods_error(peer: int, kit: KitData, slots: Dictionary) -> String:
	if slots.has("core") and not KitController.mod_unlocked(peer, kit, String(slots["core"])):
		return "Mod de kit verrouillé"
	for tier in range(1, KitModData.TIERS + 1):
		if slots.has(str(tier)):
			var mod := KitModData.get_mod(String(slots[str(tier)]))
			if mod == null or mod.tier != tier:
				return "Mod de kit inconnu"
	return ""
