class_name MapDecor
extends Node3D
## Décor de la carte : arbres, rochers, buissons et herbe (modèles : DecorModels), semés au
## hasard avec une graine fixe, posés sur le relief (MapTerrain.height_at). Chaque peer
## construit le même décor de son côté : rien ne passe par le réseau.
## Arbres et rochers ont une collision ; MonsterManager._bake_navmesh en tient compte.
## L'herbe et les petites plantes n'en ont pas (MultiMesh, très peu coûteux).
## Rien n'est posé près des points d'intérêt (Marker3D du monde, QuestSpots compris ; petit
## rayon pour les LumicepSpots) ni de l'évac. Arbres évités sur les fortes pentes, rochers plutôt sur les
## pentes et les crêtes. Créé par World, enfant de Map.

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

const TREE_COUNT := 250
const ROCK_COUNT := 100
const BUSH_COUNT := 580
const GRASS_COUNT := 7000
const SMALL_COUNT := 650
const OUTSIDE_TREE_COUNT := 1050  ## tirages : environ la moitié tombe dans la bande extérieure

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
		if pos != Vector3.INF:
			_place_solid(_pick(DecorModels.TREES), pos, _rng.randf_range(0.8, 1.4), true)
	for i in ROCK_COUNT:
		var pos := _rock_spot(half - EDGE_MARGIN)
		if pos != Vector3.INF:
			var s := _rng.randf_range(0.7, 2.2)
			pos.y -= 0.15 * s  # légèrement enfoncé dans la pente
			_place_solid(_pick(DecorModels.ROCKS), pos, s, false)
	# Forêt dense hors des murs : ferme l'horizon (pas de collision, on ne peut pas y aller).
	var outer := half + OUTSIDE_RING
	for i in OUTSIDE_TREE_COUNT:
		var x := _rng.randf_range(-outer, outer)
		var z := _rng.randf_range(-outer, outer)
		if maxf(absf(x), absf(z)) < half + 4.0:
			continue  # dans la carte : seulement la bande extérieure
		var big := _rng.randf() < 0.12
		_place_visual(_pick(DecorModels.BIG_TREES if big else DecorModels.TREES),
				Vector3(x, MapTerrain.height_at(x, z), z), _rng.randf_range(0.9, 1.6))
	_scatter_multimesh(DecorModels.BUSHES, BUSH_COUNT, half, Vector2(0.7, 1.4), true)
	_scatter_multimesh(DecorModels.GRASS, GRASS_COUNT, half, Vector2(0.35, 0.7), false)
	_scatter_multimesh(DecorModels.SMALL, SMALL_COUNT, half, Vector2(0.6, 1.5), false)


func _pick(list: Array) -> String:
	return list[_rng.randi() % list.size()]


## Point au sol, loin des points d'intérêt et sous une pente maximale ; Vector3.INF après 20 essais.
func _free_spot(half: float, max_slope: float = 99.0) -> Vector3:
	for attempt in 20:
		var x := _rng.randf_range(-half, half)
		var z := _rng.randf_range(-half, half)
		if Vector2(x, z).length() < EVAC_CLEAR or MapTerrain.slope_at(x, z) > max_slope:
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


func _place_solid(model: String, pos: Vector3, s: float, is_tree: bool) -> void:
	DecorModels.add_collision(_place_visual(model, pos, s), is_tree)


## Petites plantes sans collision, regroupées par maillage (un MultiMesh par maillage).
func _scatter_multimesh(models: Array, count: int, half: float, scale_range: Vector2, avoid: bool) -> void:
	var by_model: Dictionary = {}
	for model: String in models:
		by_model[model] = []
	for i in count:
		var pos := _free_spot(half, BUSH_MAX_SLOPE) if avoid else _random_spot(half)
		if pos == Vector3.INF or (not avoid and Vector2(pos.x, pos.z).length() < 11.0):
			continue  # rien sur la plateforme d'évac (rayon 10)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(scale_range.x, scale_range.y))
		(by_model[_pick(models)] as Array).append(Transform3D(basis, pos))
	for model: String in by_model:
		if not (by_model[model] as Array).is_empty():
			DecorModels.add_multimeshes(self, model, by_model[model])


func _random_spot(half: float) -> Vector3:
	var x := _rng.randf_range(-half, half)
	var z := _rng.randf_range(-half, half)
	return Vector3(x, MapTerrain.height_at(x, z), z)
