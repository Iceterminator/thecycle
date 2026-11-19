class_name DecorModels
extends RefCounted
## Modèles du décor (Stylized Nature MegaKit, Quaternius, CC0) : listes par catégorie,
## chargement mis en cache, collisions des arbres / rochers et MultiMesh des petites plantes.
## Utilisé par MapDecor (qui décide où les poser).

const DIR := "res://assets/models/nature/"
const CELL_SIZE := 40.0   ## m : taille des cases de MultiMesh (culling et portée de visibilité)

const TREES := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5",
		"Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5", "DeadTree_1", "DeadTree_2", "DeadTree_3"]
const BIG_TREES := ["TwistedTree_1", "TwistedTree_2"]
const ROCKS := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
const BUSHES := ["Bush_Common", "Bush_Common_Flowers", "Fern_1", "Plant_1_Big", "Flower_3_Group"]
const GRASS := ["Grass_Common_Short", "Grass_Common_Tall", "Grass_Wispy_Tall"]
const SMALL := ["Mushroom_Common", "Pebble_Round_1", "Pebble_Round_2"]

static var _scenes: Dictionary = {}


static func scene(model: String) -> PackedScene:
	if not _scenes.has(model):
		_scenes[model] = load(DIR + model + ".gltf")
	return _scenes[model]


## Arbre (collision = tronc) ou rocher (collision = forme convexe du modèle).
static func add_collision(inst: Node3D, is_tree: bool) -> void:
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


## Un MultiMesh (sans collision) par maillage du modèle et par case de CELL_SIZE m : chaque case
## a sa propre boîte englobante, donc le moteur n'affiche que celles qui sont à l'écran, et
## `range_end` (m, 0 = illimité) masque les cases lointaines (la brume les cache déjà).
static func add_multimeshes(parent: Node3D, model: String, xforms: Array, range_end: float = 0.0) -> void:
	var cells: Dictionary = {}
	for xf: Transform3D in xforms:
		var key := Vector2i(floori(xf.origin.x / CELL_SIZE), floori(xf.origin.z / CELL_SIZE))
		if not cells.has(key):
			cells[key] = []
		(cells[key] as Array).append(xf)
	var source := scene(model).instantiate() as Node3D
	for node in source.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var local := _local_xform(mi, source)
		for key: Vector2i in cells:
			var list: Array = cells[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mi.mesh
			mm.instance_count = list.size()
			for j in list.size():
				mm.set_instance_transform(j, (list[j] as Transform3D) * local)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = range_end
			parent.add_child(mmi)
	source.free()


## Distance de visibilité des MeshInstance3D d'un modèle posé (arbre, rocher) ; 0 = illimitée.
static func set_range_end(inst: Node3D, range_end: float) -> void:
	if range_end <= 0.0:
		return
	for node in inst.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visibility_range_end = range_end


static func _local_xform(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != root:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
