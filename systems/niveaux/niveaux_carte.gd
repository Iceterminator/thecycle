extends RefCounted
## Construction asynchrone de la carte d'une partie (Niveaux, sur chaque peer) : relief
## (MapTerrainBuild), puis décor (MapDecor), puis particules d'ambiance. Les calculs lourds sont
## dans des threads, les nœuds sont créés par tranches (aucune image longue). Une instance par
## construction : annuler() l'arrête au prochain point d'attente (le travail des threads en cours
## est simplement jeté). Objet RefCounted : il survit à la libération de la carte.

const MapTerrainBuild := preload("res://systems/map/map_terrain_build.gd")

var _map: Node
var _annule: bool = false
var _tree: SceneTree
var _derniere_image: int = 0
var _image_max: int = 0


func annuler() -> void:
	_annule = true


func actif() -> bool:
	return not _annule and is_instance_valid(_map)


## Coroutine (à lancer sans await) : appelle `terminee` quand la carte est prête (jamais si annulée).
func lancer(world: Node, map: Node, terminee: Callable) -> void:
	_map = map
	_tree = map.get_tree()
	var debut := Time.get_ticks_msec()
	_derniere_image = debut
	_tree.process_frame.connect(_mesurer_image)
	var ok := await _construire(world, map)
	if _tree.process_frame.is_connected(_mesurer_image):
		_tree.process_frame.disconnect(_mesurer_image)
	if not ok or not actif():
		return
	print("[Carte] prête en %d ms, image max %d ms" % [Time.get_ticks_msec() - debut, _image_max])
	if terminee.is_valid():
		terminee.call()


func _construire(world: Node, map: Node) -> bool:
	var terrain := map.get_node_or_null("Terrain") as MapTerrain
	if terrain == null:
		return true  # pas de relief (ancienne carte) : rien à construire
	if not await MapTerrainBuild.new().construire(terrain, actif):
		return false
	var decor_node := Node3D.new()
	decor_node.name = "Decor"
	map.add_child(decor_node)
	if not await MapDecor.new().construire(decor_node, world, actif):
		return false
	if DisplayServer.get_name() != "headless":  # pollen, poussière, flocons, lucioles
		var ambiance := AmbianceParticules.new()
		ambiance.name = "Ambiance"
		map.add_child(ambiance)
	return true


## Durée de l'image la plus longue pendant la construction (journal « [Carte] prête… »).
func _mesurer_image() -> void:
	var maintenant := Time.get_ticks_msec()
	_image_max = maxi(_image_max, maintenant - _derniere_image)
	_derniere_image = maintenant
