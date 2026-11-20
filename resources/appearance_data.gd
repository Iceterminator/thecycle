class_name AppearanceData
extends Resource
## Une apparence de personnage, au choix dans le lobby. Un fichier .tres par apparence dans
## data/appearances/ (id = nom du fichier). Tous les modèles partagent le squelette Superhero
## (animations adaptées par systems/avatar/avatar_retarget.gd). "" = choix automatique.

const APPEARANCES_DIR := "res://data/appearances/"

@export var display_name: String = ""
@export var model: PackedScene
@export var order: int = 0  ## ordre d'affichage dans le lobby

static var _cache: Dictionary = {}


## Apparence `id`, ou null (id inconnu ou "").
static func get_by_id(id: String) -> AppearanceData:
	_load_all()
	return _cache.get(id)


## Toutes les apparences, dans l'ordre d'affichage.
static func all() -> Array[AppearanceData]:
	_load_all()
	var result: Array[AppearanceData] = []
	for a: AppearanceData in _cache.values():
		result.append(a)
	result.sort_custom(func(x: AppearanceData, y: AppearanceData) -> bool: return x.order < y.order)
	return result


## Id d'une apparence (nom du fichier).
static func id_of(appearance: AppearanceData) -> String:
	return appearance.resource_path.get_file().get_basename()


static func _load_all() -> void:
	if not _cache.is_empty():
		return
	for file in ResourceLoader.list_directory(APPEARANCES_DIR):
		if file.ends_with(".tres"):
			var a := load(APPEARANCES_DIR + file) as AppearanceData
			if a:
				_cache[file.get_basename()] = a
