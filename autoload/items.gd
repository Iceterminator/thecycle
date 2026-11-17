extends Node
## Registre des objets : charge tous les ItemData de data/items/ au démarrage.
## Le réseau n'envoie que des ids (StringName) ; on retrouve la ressource ici.
## Exemple : Items.get_item(&"smg").weapon

const ITEMS_DIR := "res://data/items/"

var _items: Dictionary[StringName, ItemData] = {}


func _ready() -> void:
	for file in ResourceLoader.list_directory(ITEMS_DIR):
		if not file.ends_with(".tres"):
			continue
		var item := load(ITEMS_DIR + file) as ItemData
		if item == null or item.id == &"":
			push_error("[Items] Objet invalide : %s" % file)
			continue
		_items[item.id] = item
	print("[Items] %d objets chargés" % _items.size())


## Renvoie null si l'id est inconnu (donnée venant du réseau : toujours vérifier).
func get_item(id: StringName) -> ItemData:
	return _items.get(id)


## Objets en vente en boutique (price > 0) : armes d'abord, puis par prix croissant.
func get_shop_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: ItemData in _items.values():
		if item.price > 0:
			result.append(item)
	result.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		if a.kind != b.kind:
			return a.kind < b.kind
		return a.price < b.price)
	return result
