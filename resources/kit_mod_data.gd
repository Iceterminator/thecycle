class_name KitModData
extends Resource
## Mod de niveau d'un kit (niveaux 1 à 3), commun à tous les kits et disponible pour tous.
## Un fichier .tres par mod dans data/kit_mods/<id>.tres. Le cœur de kit, lui, est propre
## au kit (KitData.mods). Effets : mêmes clés que KitData.level_perk_effects (voir KitController).

const MODS_DIR := "res://data/kit_mods/"
const TIERS := 3

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_range(1, 3) var tier: int = 1
@export var effects: Dictionary = {}

static var _cache: Dictionary = {}
static var _all: Array[KitModData] = []


static func get_mod(mod_id: String) -> KitModData:
	if mod_id == "":
		return null
	if not _cache.has(mod_id):
		var path := MODS_DIR + mod_id + ".tres"
		_cache[mod_id] = load(path) as KitModData if ResourceLoader.exists(path) else null
	return _cache[mod_id]


static func all() -> Array[KitModData]:
	if _all.is_empty():
		for file in ResourceLoader.list_directory(MODS_DIR):
			if file.ends_with(".tres"):
				var m := get_mod(file.get_basename())
				if m:
					_all.append(m)
		_all.sort_custom(func(a: KitModData, b: KitModData) -> bool:
			return a.tier < b.tier or (a.tier == b.tier and String(a.id) < String(b.id)))
	return _all


## Mods d'un niveau (1 à 3).
static func for_tier(wanted: int) -> Array[KitModData]:
	var result: Array[KitModData] = []
	for m in all():
		if m.tier == wanted:
			result.append(m)
	return result


## Emplacements d'un kit : le cœur (propre au kit, KitData.mods) puis les niveaux 1 à 3.
const SLOTS: Array[String] = ["core", "1", "2", "3"]
const SLOT_LABELS: Array[String] = ["Cœur", "Niveau 1", "Niveau 2", "Niveau 3"]


## { emplacement: id } -> "cœur,n1,n2,n3" (texte synchronisé par le KitController).
static func slots_to_text(slots: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in SLOTS:
		parts.append(String(slots.get(key, "")))
	return ",".join(parts)


static func slots_from_text(text: String) -> Dictionary:
	var out := {}
	var parts := text.split(",")
	for i in mini(parts.size(), SLOTS.size()):
		if parts[i] != "":
			out[SLOTS[i]] = parts[i]
	return out
