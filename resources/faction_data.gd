class_name FactionData
extends Resource
## Une faction (étape 9). Un fichier .tres par faction dans data/factions/.
## id = valeur de WeaponData.Faction (1 lourde, 2 technologie, 3 équilibre) ; 0 = sans faction.
## Nom d'origine affiché tant que Config.SHOW_REFERENCE_WEAPON_NAMES est vrai.

const FACTIONS_DIR := "res://data/factions/"

@export var id: int = 1
@export var display_name: String = ""
@export var reference_name: String = ""
@export var color: Color = Color.WHITE
@export_multiline var style: String = ""

static var _cache: Dictionary = {}


static func get_by_id(faction_id: int) -> FactionData:
	if _cache.is_empty():
		for file in ResourceLoader.list_directory(FACTIONS_DIR):
			var f: FactionData = load(FACTIONS_DIR + file) as FactionData if file.ends_with(".tres") else null
			if f:
				_cache[f.id] = f
	return _cache.get(faction_id)


static func all() -> Array[FactionData]:
	get_by_id(1)
	var result: Array[FactionData] = []
	for key: int in [1, 2, 3]:
		if _cache.has(key):
			result.append(_cache[key])
	return result


static func name_of(faction_id: int) -> String:
	var f := get_by_id(faction_id)
	if f == null:
		return "Départ"
	if Config.SHOW_REFERENCE_WEAPON_NAMES and f.reference_name != "":
		return f.reference_name
	return f.display_name


static func color_of(faction_id: int) -> Color:
	var f := get_by_id(faction_id)
	return f.color if f else Color(0.85, 0.85, 0.85)


## Texte d'un verrou : « Korolev niv. 5 ».
static func lock_text(faction_id: int, level: int) -> String:
	return "%s niv. %d" % [name_of(faction_id), level]
