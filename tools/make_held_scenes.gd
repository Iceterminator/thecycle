extends SceneTree
## Outil : fabrique, pour chaque modèle d'arme .gltf/.glb, une scène « tenue en main »
## assets/models/weapons/held/<nom>_held.tscn : le modèle + deux repères Marker3D,
## « Poignee » (posé dans la paume) et « Bouche » (bout du canon : flash, traçants), plus
## « MainGauche » (où poser la main gauche par IK ; absent des props), ajouté aussi aux scènes
## existantes qui n'en ont pas (Poignee et Bouche existantes ne sont jamais modifiées).
## Les repères sont placés au jugé (poignée vers l'arrière-bas, bouche au bout du canon, d'après
## model_rotation_deg ; MainGauche = Poignee + décalage selon le modèle), puis le champ
## model du .tres est rebranché sur la scène. Une scène existante n'est jamais régénérée
## (réglages manuels conservés), seul le .tres est rebranché.
## À lancer depuis la racine du projet :
##   godot --headless --path . -s tools/make_held_scenes.gd
## Ensuite, ajuster Poignee et Bouche à la main dans l'éditeur.
## Pas de référence aux classes du projet par leur nom (script lancé avec -s).

const WEAPONS_DIR := "res://data/weapons/"
const HELD_DIR := "res://assets/models/weapons/held/"
## Hauteur de la bouche du canon (fraction de la boîte orientée), selon le nom du modèle.
const MUZZLE_HEIGHT := {
	"Gun_Rifle": 0.65, "Gun_Sniper": 0.65, "Gun_Pistol": 0.85, "Gun_Revolver": 0.8,
	"k28_autopistol": 0.85, "asp_flechette_gun": 0.63, "ar55_phase_autorifle": 0.68,
}
## Décalage de la main gauche par rapport à la poignée (m, repère orienté : x droite, y haut, -z avant).
const LEFT_HAND_OFFSET := {
	"Gun_Rifle": Vector3(-0.025, 0.03, -0.26), "Gun_Sniper": Vector3(-0.025, 0.03, -0.34),
	"Gun_Pistol": Vector3(-0.045, -0.01, -0.01), "Gun_Revolver": Vector3(-0.045, -0.01, -0.01),
	"k28_autopistol": Vector3(-0.045, -0.01, -0.01), "asp_flechette_gun": Vector3(-0.045, -0.01, -0.01),
	"ar55_phase_autorifle": Vector3(-0.025, 0.03, -0.22),
}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(HELD_DIR)
	var first_weapon := {}  # chemin de scène held -> première arme qui l'utilise
	for file in ResourceLoader.list_directory(WEAPONS_DIR):
		if not file.ends_with(".tres"):
			continue
		var weapon: Resource = load(WEAPONS_DIR + file)
		var model: PackedScene = weapon.get("model") if weapon else null
		if model == null:
			continue
		var path := model.resource_path
		if path.ends_with("_held.tscn"):
			if not first_weapon.has(path):
				first_weapon[path] = weapon
			continue
		if not (path.ends_with(".gltf") or path.ends_with(".glb")):
			continue
		var held_path := HELD_DIR + path.get_file().get_basename() + "_held.tscn"
		if not ResourceLoader.exists(held_path):
			_make_scene(model, weapon, held_path)
			print("[Tenue] scène créée : %s" % held_path)
		weapon.set("model", load(held_path))
		if not first_weapon.has(held_path):
			first_weapon[held_path] = weapon
		ResourceSaver.save(weapon, WEAPONS_DIR + file)
		print("[Tenue] %s rebranchée sur %s" % [file, held_path])
	for held_path in first_weapon:
		_add_left_hand(held_path, first_weapon[held_path])
	quit(0)


func _make_scene(model: PackedScene, weapon: Resource, held_path: String) -> void:
	var base_name := held_path.get_file().get_basename().trim_suffix("_held")
	var root := Node3D.new()
	root.name = base_name + "_held"
	var instance := model.instantiate() as Node3D
	root.add_child(instance)
	instance.owner = root
	var basis := Basis.from_euler(Vector3(weapon.get("model_rotation_deg")) * (PI / 180.0))
	# Boîte orientée (canon vers -Z) : les 8 coins de chaque maillage, dans le repère du root.
	var box := AABB()
	var first := true
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var n: Node = mesh
		while n != root:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var local_box := mesh.get_aabb()
		for i in 8:
			var corner := basis * (xf * local_box.get_endpoint(i))
			box = AABB(corner, Vector3.ZERO) if first else box.expand(corner)
			first = false
	var grip := Vector2(0.3, 0.3)  # fraction de la boîte : x depuis l'arrière, y depuis le bas
	var center := box.get_center()
	var handle := Vector3(center.x, box.position.y + grip.y * box.size.y, box.end.z - grip.x * box.size.z)
	var muzzle := center
	if MUZZLE_HEIGHT.has(base_name):
		muzzle = Vector3(center.x, box.position.y + float(MUZZLE_HEIGHT[base_name]) * box.size.y, box.position.z)
	_add_marker(root, "Poignee", basis.inverse() * handle)
	_add_marker(root, "Bouche", basis.inverse() * muzzle)
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, held_path)
	root.free()


func _add_marker(root: Node3D, marker_name: String, pos: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	marker.gizmo_extents = 0.05
	root.add_child(marker)
	marker.owner = root
	marker.position = pos


## Ajoute « MainGauche » à une scène held qui n'en a pas (Poignee et Bouche restent intactes).
func _add_left_hand(held_path: String, weapon: Resource) -> void:
	var base_name := held_path.get_file().get_basename().trim_suffix("_held")
	if not LEFT_HAND_OFFSET.has(base_name):
		return
	var packed := ResourceLoader.load(held_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var root := packed.instantiate() as Node3D
	var grip := root.find_child("Poignee", true, false) as Node3D
	if root.find_child("MainGauche", true, false) or grip == null:
		root.free()
		return
	# Échelle du modèle en main (même calcul que WeaponModel.build).
	var pivot: Node3D = load("res://systems/combat/weapon_model.gd").build(weapon)
	var scale_factor := (pivot.get_child(0) as Node3D).scale.x if pivot.get_child_count() > 0 else 1.0
	pivot.free()
	var basis := Basis.from_euler(Vector3(weapon.get("model_rotation_deg")) * (PI / 180.0))
	var offset: Vector3 = LEFT_HAND_OFFSET[base_name]
	_add_marker(root, "MainGauche", grip.position + basis.inverse() * (offset / scale_factor))
	var repacked := PackedScene.new()
	repacked.pack(root)
	ResourceSaver.save(repacked, held_path)
	root.free()
	print("[Tenue] MainGauche ajouté à %s" % held_path)
