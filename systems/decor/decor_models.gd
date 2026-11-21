class_name DecorModels
extends RefCounted
## Modèles du décor (packs CC0 : Quaternius, Asset Quest, Kenney ; listes par biome dans data/biomes/) :
## chargement mis en cache, collisions des arbres / rochers et MultiMesh des petites plantes.
## Utilisé par MapDecor (qui décide où les poser).

const DIR := "res://assets/models/nature/"
const CELL_SIZE := 40.0   ## m : taille des cases de MultiMesh (culling et portée de visibilité)


static var _scenes: Dictionary = {}
static var _remplacements: Dictionary = {}  ## chemin .tres -> Material (ou null si absent)


## Matériau de remplacement : <dossier du modèle>/<nom du matériau>.tres s'il existe
## (ex. herbe, feuillage Poly Haven → shader de vent), sinon null.
static func _override_for(model: String, mat: Material) -> Material:
	if mat == null or mat.resource_name.is_empty():
		return null
	var path := model.get_base_dir() + "/" + mat.resource_name + ".tres"
	if not _remplacements.has(path):
		_remplacements[path] = load(path) as Material if ResourceLoader.exists(path) else null
	return _remplacements[path]


static var _demandes: Dictionary = {}  ## modèles demandés en chargement d'arrière-plan (precharger)


static func chemin(model: String) -> String:
	return model if model.begins_with("res://") else DIR + model + ".gltf"


## Demande le chargement des modèles dans des threads : scene() les trouve prêts (pas d'arrêt de l'image).
static func precharger(models: Array) -> void:
	for model: String in models:
		if not _scenes.has(model) and not _demandes.has(model):
			ResourceLoader.load_threaded_request(chemin(model))
			_demandes[model] = true


## Coroutine : attend, image par image, la fin des chargements demandés par precharger().
static func attendre_precharges(tree: SceneTree) -> void:
	for model: String in _demandes.keys():
		while ResourceLoader.load_threaded_get_status(chemin(model)) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await tree.process_frame


static func scene(model: String) -> PackedScene:
	if not _scenes.has(model):
		var packed: PackedScene
		if _demandes.has(model):
			packed = ResourceLoader.load_threaded_get(chemin(model)) as PackedScene
			_demandes.erase(model)
		else:
			packed = load(chemin(model)) as PackedScene
		_apply_overrides(model, packed)
		_scenes[model] = packed
	return _scenes[model]


## Remplace, dans les maillages du modèle (partagés par toutes ses copies), les matériaux qui ont un .tres.
static func _apply_overrides(model: String, packed: PackedScene) -> void:
	var source := packed.instantiate()
	for node in source.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		for i in mesh.get_surface_count() if mesh else 0:
			var remplace := _override_for(model, mesh.surface_get_material(i))
			if remplace:
				mesh.surface_set_material(i, remplace)
	source.free()


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


## Coupe les ombres portées d'un modèle posé (forêt hors carte : loin des ombres, coûteuse avec le feuillage).
static func no_shadow(inst: Node3D) -> void:
	for node in inst.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
