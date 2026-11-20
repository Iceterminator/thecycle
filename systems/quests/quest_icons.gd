class_name QuestIcons
extends RefCounted
## Logos des quêtes (assets/icons/quests/<id>.png, blancs, teintés à l'affichage).
## L'id est le nom du fichier de données : data/contracts/uplink.tres -> uplink ;
## les cristaux (data/quests/crystal_*.tres) partagent le logo « crystal ».

const DIR := "res://assets/icons/quests/"

static var _cache: Dictionary = {}


## Logo d'une donnée de quête ou de tirage (chemin res:// du .tres, ou id). null si absent.
static func of(path_or_id: String) -> Texture2D:
	var id := path_or_id.get_file().get_basename()
	if id.begins_with("crystal"):
		id = "crystal"
	if not _cache.has(id):
		var file := DIR + id + ".png"
		_cache[id] = load(file) as Texture2D if ResourceLoader.exists(file) else null
	return _cache[id]


## Logo prêt pour l'interface : carré de `size` px, teinté à `color`.
static func rect(icon: Texture2D, color: Color, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon
	r.modulate = color
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
