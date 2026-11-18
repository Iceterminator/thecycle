class_name GripTunerSave
extends RefCounted
## Enregistrement des réglages du GripTuner : repères « Poignee » et « MainGauche » de la
## scène *_held.tscn de l'arme en main (une seule sauvegarde), puis `model_length` de l'arme.
## Les fonctions renvoient un message d'erreur, ou "" si tout s'est bien passé.


static func save(held: WeaponModel) -> String:
	var weapon := held.current_weapon()
	if weapon == null or weapon.model == null or not weapon.model.resource_path.ends_with("_held.tscn"):
		return "Rien à enregistrer (pas de scène *_held.tscn)"
	var path := weapon.model.resource_path
	var inverse := Basis.from_euler(weapon.model_rotation_deg * (PI / 180.0)).inverse()
	var scale_factor := held.model_scale_factor()
	var packed := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var root := packed.instantiate() as Node if packed else null
	var grip := root.find_child("Poignee", true, false) as Node3D if root else null
	if grip == null or grip.get_parent() != root:
		if root:
			root.free()
		return "Repère « Poignee » introuvable ou pas enfant direct de la racine"
	# La main gauche d'abord, avec l'échelle actuelle, puis la poignée (et la taille).
	if held.tune_left != Vector3.ZERO:
		var hand := root.find_child("MainGauche", true, false) as Node3D
		if hand == null:
			root.free()
			return "Repère « MainGauche » introuvable (lancer tools/make_held_scenes.gd)"
		hand.position += inverse * (held.tune_left / scale_factor)
	grip.position -= inverse * (held.tune_offset / (scale_factor * held.tune_scale))
	var error := _write(root, path)
	root.free()
	if error != OK:
		return "Enregistrement impossible (version exportée)" if not OS.has_feature("editor") else "Erreur d'enregistrement (%d)" % error
	ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if not is_equal_approx(held.tune_scale, 1.0):
		weapon.model_length = snappedf(weapon.model_length * held.tune_scale, 0.001)
		ResourceSaver.save(weapon, weapon.resource_path)
	return ""


static func _write(root: Node, path: String) -> int:
	var repacked := PackedScene.new()
	var error := repacked.pack(root)
	if error == OK:
		error = ResourceSaver.save(repacked, path)
	return error
