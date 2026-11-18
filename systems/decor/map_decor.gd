class_name MapDecor
extends Node3D
## Décor de la carte : arbres, rochers, buissons et herbe (Stylized Nature MegaKit,
## Quaternius, CC0), semés au hasard avec une graine fixe. Chaque peer construit le même
## décor de son côté : rien ne passe par le réseau (ce ne sont pas des objets de jeu).
## Arbres et rochers ont une collision ; MonsterManager._bake_navmesh en tient compte.
## L'herbe et les petites plantes n'en ont pas (MultiMesh, très peu coûteux).
## Rien n'est posé près des points d'intérêt (tous les Marker3D du monde) ni de l'évac.
## Créé par World, enfant de Map.

const DIR := "res://assets/models/nature/"
const SEED := 20261118
const CLEAR_RADIUS := 13.0      ## zone dégagée autour de chaque point d'intérêt (m)
const EVAC_CLEAR := 20.0        ## zone dégagée autour de la plateforme d'évac (centre)
const EDGE_MARGIN := 3.0        ## pas de collision collée aux murs invisibles
const OUTSIDE_RING := 45.0      ## largeur de la forêt hors carte (décor seulement)

const TREES := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5",
		"Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5", "DeadTree_1", "DeadTree_2", "DeadTree_3"]
const BIG_TREES := ["TwistedTree_1", "TwistedTree_2"]
const ROCKS := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
const BUSHES := ["Bush_Common", "Bush_Common_Flowers", "Fern_1", "Plant_1_Big", "Flower_3_Group"]
const GRASS := ["Grass_Common_Short", "Grass_Common_Tall", "Grass_Wispy_Tall"]
const SMALL := ["Mushroom_Common", "Pebble_Round_1", "Pebble_Round_2"]

const TREE_COUNT := 110
const ROCK_COUNT := 45
const BUSH_COUNT := 260
const GRASS_COUNT := 3500
const SMALL_COUNT := 300
const OUTSIDE_TREE_COUNT := 520  ## tirages : environ la moitié tombe dans la bande extérieure

var _rng := RandomNumberGenerator.new()
var _clear_points: Array[Vector3] = []
var _scenes: Dictionary = {}


func _ready() -> void:
	_rng.seed = SEED
	var world := get_parent().get_parent()
	for marker in world.find_children("*", "Marker3D", true, false):
		_clear_points.append((marker as Node3D).global_position)
	_style_ground()
	var half := Config.MAP_HALF_SIZE
	for i in TREE_COUNT:
		var pos := _free_spot(half - EDGE_MARGIN)
		if pos != Vector3.INF:
			_place_solid(_pick(TREES), pos, _rng.randf_range(0.8, 1.4), true)
	for i in ROCK_COUNT:
		var pos := _free_spot(half - EDGE_MARGIN)
		if pos != Vector3.INF:
			_place_solid(_pick(ROCKS), pos, _rng.randf_range(0.7, 2.2), false)
	# Forêt dense hors des murs : ferme l'horizon (pas de collision, on ne peut pas y aller).
	var outer := half + OUTSIDE_RING
	for i in OUTSIDE_TREE_COUNT:
		var pos := Vector3(_rng.randf_range(-outer, outer), 0.0, _rng.randf_range(-outer, outer))
		if maxf(absf(pos.x), absf(pos.z)) < half + 4.0:
			continue  # dans la carte : seulement la bande extérieure
		var big := _rng.randf() < 0.12
		_place_visual(_pick(BIG_TREES if big else TREES), pos, _rng.randf_range(0.9, 1.6))
	_scatter_multimesh(BUSHES, BUSH_COUNT, half, Vector2(0.7, 1.4), true)
	_scatter_multimesh(GRASS, GRASS_COUNT, half, Vector2(0.35, 0.7), false)
	_scatter_multimesh(SMALL, SMALL_COUNT, half, Vector2(0.6, 1.5), false)


## Sol : taches d'herbe olive et de terre ocre (bruit), sur la carte et au-delà des murs.
func _style_ground() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = SEED
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.set_color(0, Color("#4f5a22"))
	ramp.set_color(1, Color("#b58c4c"))
	ramp.add_point(0.45, Color("#6f6b2a"))
	ramp.add_point(0.6, Color("#9a7d3f"))
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 1.0
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.012
	var ground := get_parent().get_node_or_null("Ground") as CSGBox3D
	if ground:
		ground.material = mat
	# Blocs de couverture de la carte (CSG) : texture de roche du pack.
	var rock := StandardMaterial3D.new()
	rock.albedo_texture = load(DIR + "Rocks_Diffuse.png")
	rock.uv1_triplanar = true
	rock.uv1_world_triplanar = true
	rock.uv1_scale = Vector3.ONE * 0.25
	for node in get_parent().get_children():
		if node is CSGBox3D and node != ground:
			(node as CSGBox3D).material = rock
	var outside := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * (Config.MAP_HALF_SIZE + OUTSIDE_RING + 60.0) * 2.0
	outside.mesh = plane
	outside.material_override = mat
	outside.position.y = -0.02
	add_child(outside)


func _pick(list: Array) -> String:
	return list[_rng.randi() % list.size()]


## Point au hasard dans la carte, loin des points d'intérêt ; Vector3.INF après 20 essais.
func _free_spot(half: float) -> Vector3:
	for attempt in 20:
		var pos := Vector3(_rng.randf_range(-half, half), 0.0, _rng.randf_range(-half, half))
		if Vector2(pos.x, pos.z).length() < EVAC_CLEAR:
			continue
		var ok := true
		for p in _clear_points:
			if Vector2(pos.x - p.x, pos.z - p.z).length() < CLEAR_RADIUS:
				ok = false
				break
		if ok:
			return pos
	return Vector3.INF


func _scene(model: String) -> PackedScene:
	if not _scenes.has(model):
		_scenes[model] = load(DIR + model + ".gltf")
	return _scenes[model]


func _place_visual(model: String, pos: Vector3, s: float) -> Node3D:
	var inst := _scene(model).instantiate() as Node3D
	inst.position = pos
	inst.rotation.y = _rng.randf() * TAU
	inst.scale = Vector3.ONE * s
	add_child(inst)
	return inst


## Arbre (collision = tronc) ou rocher (collision = forme convexe du modèle).
func _place_solid(model: String, pos: Vector3, s: float, is_tree: bool) -> void:
	var inst := _place_visual(model, pos, s)
	var body := StaticBody3D.new()
	inst.add_child(body)
	if is_tree:
		var trunk := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.35
		cyl.height = 6.0
		trunk.shape = cyl
		trunk.position.y = 3.0
		body.add_child(trunk)
		return
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_convex_shape()
		body.add_child(cs)
		cs.global_transform = mi.global_transform


## Petites plantes sans collision, regroupées par maillage (un MultiMesh par maillage).
func _scatter_multimesh(models: Array, count: int, half: float, scale_range: Vector2, avoid: bool) -> void:
	var by_model: Dictionary = {}
	for model: String in models:
		by_model[model] = []
	for i in count:
		var pos := _free_spot(half) if avoid else Vector3(_rng.randf_range(-half, half), 0.0, _rng.randf_range(-half, half))
		if pos == Vector3.INF or (not avoid and Vector2(pos.x, pos.z).length() < 11.0):
			continue  # rien sur la plateforme d'évac (rayon 10)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(scale_range.x, scale_range.y))
		(by_model[_pick(models)] as Array).append(Transform3D(basis, pos))
	for model: String in by_model:
		var xforms: Array = by_model[model]
		if xforms.is_empty():
			continue
		var source := _scene(model).instantiate() as Node3D
		for node in source.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			var local := _local_xform(mi, source)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mi.mesh
			mm.instance_count = xforms.size()
			for j in xforms.size():
				mm.set_instance_transform(j, (xforms[j] as Transform3D) * local)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
		source.free()


func _local_xform(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != root:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
