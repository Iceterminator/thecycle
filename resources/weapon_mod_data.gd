class_name WeaponModData
extends Resource
## Mod d'arme (étape 9). Un fichier .tres par mod dans data/weapon_mods/. Choisi hors
## partie (lobby), un par arme, débloqué par la réputation (faction, faction_level).
## Absent de la référence : valeurs de départ à équilibrer.

const MODS_DIR := "res://data/weapon_mods/"

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var faction: int = 0
@export var faction_level: int = 0

@export_group("Effets")
@export var magazine_mult: float = 1.0      ## chargeur étendu
@export var shield_damage_mult: float = 1.0 ## électrique : dégâts sur le bouclier
## Dégâts sur la durée, en part des dégâts du tir : feu (passe par le bouclier) ou poison
## (ignore le bouclier).
@export var burn_ratio: float = 0.0
@export var burn_time: float = 0.0
@export var poison_ratio: float = 0.0
@export var poison_time: float = 0.0

static var _cache: Dictionary = {}


static func get_mod(mod_id: String) -> WeaponModData:
	if mod_id == "":
		return null
	if not _cache.has(mod_id):
		var path := MODS_DIR + mod_id + ".tres"
		_cache[mod_id] = load(path) as WeaponModData if ResourceLoader.exists(path) else null
	return _cache[mod_id]


static func all() -> Array[WeaponModData]:
	var result: Array[WeaponModData] = []
	for file in ResourceLoader.list_directory(MODS_DIR):
		if file.ends_with(".tres"):
			var m := get_mod(file.get_basename())
			if m:
				result.append(m)
	return result
