extends Node
## Registre des objets : charge tous les ItemData de data/items/ au démarrage.
## Le réseau n'envoie que des ids (StringName) ; on retrouve la ressource ici.
## Exemple : Items.get_item(&"s76_pdw").weapon
##
## Chaque arme de data/weapons/ sans fichier dans data/items/ reçoit un objet créé en
## mémoire (même id que l'arme, pas en vente) : toutes les armes peuvent être au sol.
## Tous les peers construisent le même registre, les ids restent donc valables en réseau.

const ITEMS_DIR := "res://data/items/"
const WEAPONS_DIR := "res://data/weapons/"

## Couleur au sol des armes sans fichier d'objet, par faction (WeaponData.Faction).
const FACTION_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.85),  # départ
	Color(0.95, 0.45, 0.25),  # lourde
	Color(0.45, 0.75, 1.0),   # techno
	Color(0.55, 0.95, 0.5),   # équilibre
]

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
	_add_missing_weapons()
	if Config.SHOW_REFERENCE_WEAPON_NAMES:
		_use_reference_names()
	print("[Items] %d objets chargés" % _items.size())


## Temporaire (Config.SHOW_REFERENCE_WEAPON_NAMES) : les armes s'affichent partout sous leur
## nom d'origine. Les ressources sont partagées : changer le nom ici le change pour tout
## le jeu (HUD, boutique, objets au sol, menu admin), sans toucher aux fichiers.
func _use_reference_names() -> void:
	for item: ItemData in _items.values():
		if item.weapon and item.weapon.reference_name != "":
			item.display_name = item.weapon.reference_name
			item.weapon.display_name = item.weapon.reference_name


func _add_missing_weapons() -> void:
	for file in ResourceLoader.list_directory(WEAPONS_DIR):
		if not file.ends_with(".tres"):
			continue
		var weapon := load(WEAPONS_DIR + file) as WeaponData
		if weapon == null or weapon.id == &"" or _items.has(weapon.id):
			continue
		var item := ItemData.new()
		item.id = weapon.id
		item.display_name = weapon.display_name
		item.kind = ItemData.Kind.WEAPON
		item.weapon = weapon
		item.color = FACTION_COLORS[clampi(weapon.faction, 0, FACTION_COLORS.size() - 1)]
		_items[item.id] = item


## Renvoie null si l'id est inconnu (donnée venant du réseau : toujours vérifier).
func get_item(id: StringName) -> ItemData:
	return _items.get(id)


## Tous les objets d'un type, triés par nom affiché.
func get_items_of_kind(kind: ItemData.Kind) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item: ItemData in _items.values():
		if item.kind == kind:
			result.append(item)
	result.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.display_name < b.display_name)
	return result


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
