class_name WeaponModData
extends Resource
## Mod d'arme. Un fichier .tres par mod dans data/weapon_mods/ (générés par
## tools/wiki_2019/make_weapon_mods.mjs : ne pas les modifier à la main).
## Un mod appartient à UNE arme et à UN emplacement ; le joueur en choisit au plus un par
## emplacement et par arme, dans le lobby. Disponible dès que l'arme est débloquée.
## Les effets sont appliqués par WeaponModApply.

enum Slot { RAIL, STOCK, BODY, MAGAZINE }

const MODS_DIR := "res://data/weapon_mods/"
const SLOT_NAMES: Array[String] = ["Viseur", "Crosse", "Corps", "Chargeur"]

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var weapon_id: StringName
@export var slot: Slot = Slot.RAIL

@export_group("Effets")
@export var mult: Dictionary = {}   ## clé -> facteur (1.5 = +50 %)
@export var add: Dictionary = {}    ## clé -> valeur ajoutée
@export var overrides: Dictionary = {}    ## clé -> valeur imposée (ex. scope_zoom)
@export var flags: PackedStringArray = PackedStringArray()

@export_group("Référence")
@export var reference_name: String = ""
@export_multiline var notes: String = ""

static var _cache: Dictionary = {}
static var _all: Array[WeaponModData] = []


static func get_mod(mod_id: String) -> WeaponModData:
	if mod_id == "":
		return null
	if not _cache.has(mod_id):
		var path := MODS_DIR + mod_id + ".tres"
		_cache[mod_id] = load(path) as WeaponModData if ResourceLoader.exists(path) else null
	return _cache[mod_id]


static func all() -> Array[WeaponModData]:
	if _all.is_empty():
		for file in ResourceLoader.list_directory(MODS_DIR):
			if file.ends_with(".tres"):
				var m := get_mod(file.get_basename())
				if m:
					_all.append(m)
	return _all


## Mods d'une arme, triés par emplacement puis par id.
static func for_weapon(weapon_id_wanted: StringName) -> Array[WeaponModData]:
	var result: Array[WeaponModData] = []
	for m in all():
		if m.weapon_id == weapon_id_wanted:
			result.append(m)
	result.sort_custom(func(a: WeaponModData, b: WeaponModData) -> bool:
		return a.slot < b.slot or (a.slot == b.slot and String(a.id) < String(b.id)))
	return result
