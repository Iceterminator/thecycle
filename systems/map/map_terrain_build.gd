extends RefCounted
## Construction asynchrone du relief (appelée par NiveauxCarte) : la grille de hauteurs (1 m) et le
## maillage de rendu sont calculés dans le WorkerThreadPool, le fil principal ne fait que poser
## les nœuds. Même résultat que l'ancien calcul d'un bloc : mêmes fonctions de hauteur.

const MapThread := preload("res://systems/map/map_thread.gd")

var _lignes: Array = []  ## une entrée par ligne, remplie par les threads (indices distincts)
var _half: int = 0
var _count: int = 0
var _axe: PackedFloat32Array
var _plaques: FastNoiseLite


## Coroutine : renvoie false si la construction a été annulée (actif.call() faux).
func construire(terrain: MapTerrain, actif: Callable) -> bool:
	var tree := terrain.get_tree()
	_half = int(Config.MAP_HALF_SIZE) + MapTerrain.COLLISION_MARGIN
	_count = _half * 2 + 1
	_lignes.resize(_count)
	MapBiomes.weights_at(0.0, 0.0)  # crée les bruits ici : les threads ne font que les lire
	await MapThread.groupe(tree, _ligne_hauteurs, _count)
	if not actif.call():
		return false
	var data := PackedFloat32Array()
	for ligne: PackedFloat32Array in _lignes:
		data.append_array(ligne)
	terrain.appliquer_relief(data, _count, _half)
	if DisplayServer.get_name() == "headless":
		return true
	return await _construire_visuel(terrain, tree, actif)


func _ligne_hauteurs(j: int) -> void:
	var ligne := PackedFloat32Array()
	ligne.resize(_count)
	for i in _count:
		ligne[i] = MapTerrain._exact_height(i - _half, j - _half)
	_lignes[j] = ligne


## Rendu : lignes du maillage et eau calculées en thread, puis nœuds posés sur le fil principal.
func _construire_visuel(terrain: MapTerrain, tree: SceneTree, actif: Callable) -> bool:
	_axe = MapTerrainMesh.axe()
	_plaques = MapTerrainMesh.creer_plaques()
	_lignes = []
	_lignes.resize(_axe.size())
	await MapThread.groupe(tree, _ligne_maillage, _axe.size())
	var resultat := {}
	await MapThread.tache(tree, func() -> void:
		resultat["arrays"] = MapTerrainMesh.fusionner(_lignes)
		resultat["eau"] = MapWater.calculer())
	if not actif.call():
		return false
	var visual := MeshInstance3D.new()
	visual.mesh = MapTerrainMesh.creer_mesh(resultat["arrays"])
	visual.material_override = MapTerrainMesh.make_material()
	terrain.add_child(visual)
	await tree.process_frame  # une image pour le maillage, une autre pour l'eau
	if not actif.call():
		return false
	terrain.add_child(MapWater.creer(resultat["eau"]))
	return true


func _ligne_maillage(j: int) -> void:
	_lignes[j] = MapTerrainMesh.calculer_ligne(_axe, _plaques, j)
