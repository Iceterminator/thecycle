class_name MapDecor
extends Node3D
## Décor de la carte : arbres, rochers, buissons et herbe (modèles : DecorModels), semés au
## hasard avec une graine fixe, posés sur le relief (MapTerrain.height_at). Chaque peer
## construit le même décor de son côté : rien ne passe par le réseau.
## Arbres et rochers ont une collision ; MonsterManager._bake_navmesh en tient compte.
## L'herbe et les petites plantes n'en ont pas (MultiMesh). Rien près des points d'intérêt
## (Marker3D, QuestSpots ; petit rayon pour les LumicepSpots) ni de l'évac. Arbres évités
## sur les fortes pentes, rochers plutôt sur les pentes et les crêtes. Modèles et densités selon le biome (MapDecorPick, data/biomes/) ;
## plantes d'eau à la surface des mares du marais. Créé par World, enfant de Map.

const MapDecorPick := preload("res://systems/decor/map_decor_pick.gd")

const SEED := 20261118
const CLEAR_RADIUS := 13.0      ## zone dégagée autour de chaque point d'intérêt (m)
const EVAC_CLEAR := 24.0        ## zone dégagée autour de la plateforme d'évac (centre)
const EDGE_MARGIN := 3.0        ## pas de collision collée aux murs invisibles
const OUTSIDE_RING := 58.0      ## largeur de la forêt hors carte (décor seulement)
const TREE_MAX_SLOPE := 0.7     ## tan de l'angle : 0.7 = 35°
const BUSH_MAX_SLOPE := 1.0
const ROCK_MIN_SLOPE := 0.3     ## rochers « de pente » : gradient mini, ou altitude mini
const ROCK_MIN_HEIGHT := 8.0
const SMALL_CLEAR_PARENTS := ["LumicepSpots"]  ## repères à petit rayon dégagé
const SMALL_CLEAR_RADIUS := 3.0

## Portées de visibilité (m) : au-delà, le décor est masqué (brume dense, gain GPU). 0 = illimitée.
const TREE_RANGE := 130.0       ## arbres dans la carte (la forêt extérieure reste visible : elle ferme l'horizon)
const ROCK_RANGE := 110.0
const BUSH_RANGE := 100.0
const GRASS_RANGE := 50.0
const SMALL_RANGE := 50.0

const TREE_COUNT := 250
const ROCK_COUNT := 100
const BUSH_COUNT := 580
const GRASS_COUNT := 14000
const SMALL_COUNT := 650
const OUTSIDE_TREE_COUNT := 700  ## tirages : environ la moitié tombe dans la bande extérieure
const WATER_PLANT_TRIES := 6000  ## tirages : seuls ceux qui tombent dans une mare sont gardés
const WATER_RANGE := 60.0

var _rng := RandomNumberGenerator.new()
var _clear_points: Array[Vector3] = []
var _clear_radii: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_rng.seed = SEED
	var world := get_parent().get_parent()
	for marker in world.find_children("*", "Marker3D", true, false):
		var small := SMALL_CLEAR_PARENTS.has(String(marker.get_parent().name))
		_clear_radii.append(SMALL_CLEAR_RADIUS if small else CLEAR_RADIUS)
		_clear_points.append((marker as Node3D).global_position)
	var half := Config.MAP_HALF_SIZE
	for i in TREE_COUNT:
		var pos := _free_spot(half - EDGE_MARGIN, TREE_MAX_SLOPE)
		var choice := [] if pos == Vector3.INF else MapDecorPick.pick(_rng, &"trees", pos.x, pos.z)
		if not choice.is_empty():
			_place_solid(choice[0], pos, choice[1] * _rng.randf_range(0.8, 1.4), true, TREE_RANGE)
	for i in ROCK_COUNT:
		var pos := _rock_spot(half - EDGE_MARGIN)
		var choice := [] if pos == Vector3.INF else MapDecorPick.pick(_rng, &"rocks", pos.x, pos.z)
		if not choice.is_empty():
			var s: float = choice[1] * _rng.randf_range(0.7, 2.2)
			pos.y -= 0.15 * s  # légèrement enfoncé dans la pente
			_place_solid(choice[0], pos, s, false, ROCK_RANGE)
	_outside_forest(half)
	_scatter_multimesh(&"bushes", BUSH_COUNT, half, Vector2(0.7, 1.4), true, BUSH_RANGE)
	_scatter_multimesh(&"grass", GRASS_COUNT, half, Vector2(0.35, 0.7), false, GRASS_RANGE)
	_scatter_multimesh(&"small", SMALL_COUNT, half, Vector2(0.6, 1.5), false, SMALL_RANGE)
	_scatter_water_plants(half)


## Forêt dense hors des murs : ferme l'horizon (pas de collision, on ne peut pas y aller).
func _outside_forest(half: float) -> void:
	var outer := half + OUTSIDE_RING
	for i in OUTSIDE_TREE_COUNT:
		var x := _rng.randf_range(-outer, outer)
		var z := _rng.randf_range(-outer, outer)
		if maxf(absf(x), absf(z)) < half + 4.0:
			continue  # dans la carte : seulement la bande extérieure
		var category := &"big_trees" if _rng.randf() < 0.12 else &"trees"
		var choice := MapDecorPick.pick(_rng, category, x, z, 0.5)
		if not choice.is_empty():
			DecorModels.no_shadow(_place_visual(choice[0], Vector3(x, MapTerrain.height_at(x, z), z), choice[1] * _rng.randf_range(0.9, 1.6)))


## Point au sol, loin des points d'intérêt et sous une pente maximale ; Vector3.INF après 20 essais.
func _free_spot(half: float, max_slope: float = 99.0) -> Vector3:
	for attempt in 20:
		var x := _rng.randf_range(-half, half)
		var z := _rng.randf_range(-half, half)
		if Vector2(x, z).length() < EVAC_CLEAR or MapTerrain.slope_at(x, z) > max_slope \
				or MapBiomes.is_water(x, z, MapTerrain.height_at(x, z) - 0.15):
			continue
		var ok := true
		for i in _clear_points.size():
			var p := _clear_points[i]
			if Vector2(x - p.x, z - p.z).length() < _clear_radii[i]:
				ok = false
				break
		if ok:
			return Vector3(x, MapTerrain.height_at(x, z), z)
	return Vector3.INF


## Rocher : 7 sur 10 cherchent une pente ou une crête (quelques essais), les autres n'importe où.
func _rock_spot(half: float) -> Vector3:
	var want_steep := _rng.randf() < 0.7
	var pos := Vector3.INF
	for attempt in 8:
		pos = _free_spot(half)
		if pos == Vector3.INF or not want_steep:
			return pos
		if MapTerrain.slope_at(pos.x, pos.z) > ROCK_MIN_SLOPE or pos.y > ROCK_MIN_HEIGHT:
			return pos
	return pos


func _place_visual(model: String, pos: Vector3, s: float) -> Node3D:
	var inst := DecorModels.scene(model).instantiate() as Node3D
	inst.position = pos
	inst.rotation.y = _rng.randf() * TAU
	inst.scale = Vector3.ONE * s
	add_child(inst)
	return inst


func _place_solid(model: String, pos: Vector3, s: float, is_tree: bool, view_range: float) -> void:
	var inst := _place_visual(model, pos, s)
	DecorModels.add_collision(inst, is_tree)
	DecorModels.set_range_end(inst, view_range)


## Petites plantes sans collision, regroupées par maillage et par case (MultiMesh, voir DecorModels).
func _scatter_multimesh(category: StringName, count: int, half: float, scale_range: Vector2, avoid: bool, view_range: float) -> void:
	var by_model: Dictionary = {}
	for i in count:
		var pos := _free_spot(half, BUSH_MAX_SLOPE) if avoid else _random_spot(half)
		if pos == Vector3.INF or (not avoid and Vector2(pos.x, pos.z).length() < 11.0):
			continue  # rien sur la plateforme d'évac (rayon 10)
		var choice := MapDecorPick.pick(_rng, category, pos.x, pos.z)
		if not choice.is_empty():
			_add_instance(by_model, choice, pos, scale_range)
	_build_multimeshes(by_model, view_range)


## Nénuphars et plantes flottantes : à la surface des mares (marais seulement).
func _scatter_water_plants(half: float) -> void:
	var models: Dictionary = MapBiomes.DATA[MapBiomes.MARAIS].water_plants
	var by_model: Dictionary = {}
	for i in WATER_PLANT_TRIES:
		var x := _rng.randf_range(-half, half)
		var z := _rng.randf_range(-half, half)
		if not MapBiomes.is_water(x, z, MapTerrain.height_at(x, z) + 0.1):
			continue  # au moins 10 cm d'eau
		var choice := MapDecorPick.from_dict(_rng, models)
		if not choice.is_empty():
			_add_instance(by_model, choice, Vector3(x, MapBiomes.WATER_LEVEL + 0.01, z), Vector2(0.7, 1.3))
	_build_multimeshes(by_model, WATER_RANGE)


func _add_instance(by_model: Dictionary, choice: Array, pos: Vector3, scale_range: Vector2) -> void:
	var s: float = choice[1] * _rng.randf_range(scale_range.x, scale_range.y)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s)
	if not by_model.has(choice[0]):
		by_model[choice[0]] = []
	(by_model[choice[0]] as Array).append(Transform3D(basis, pos))


func _build_multimeshes(by_model: Dictionary, view_range: float) -> void:
	for model: String in by_model:
		DecorModels.add_multimeshes(self, model, by_model[model], view_range)


## Point au hasard sur le sol ; Vector3.INF dans une mare.
func _random_spot(half: float) -> Vector3:
	var x := _rng.randf_range(-half, half)
	var z := _rng.randf_range(-half, half)
	var h := MapTerrain.height_at(x, z)
	return Vector3.INF if MapBiomes.is_water(x, z, h - 0.15) else Vector3(x, h, z)
