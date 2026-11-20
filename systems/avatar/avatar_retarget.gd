extends RefCounted
## Adapte les animations (faites pour le squelette Superhero) à un personnage dont le squelette
## a les mêmes os mais d'autres proportions (ex. le Prospecteur : jambes plus courtes, gros casque).
## Les animations imposent aussi la position de chaque os : on décale chaque clé de position
## de (repos du modèle - repos de référence). Les rotations, absolues, restent telles quelles.
## Une bibliothèque adaptée par modèle, gardée en cache.

const REFERENCE_MODEL := "res://assets/models/characters/Superhero_Male_FullBody.gltf"
const EPSILON := 0.001  ## écart de repos (m) en dessous duquel on ne touche pas aux clés

static var _reference_rest: Dictionary = {}   ## os -> position de repos de référence
static var _cache: Dictionary = {}            ## chemin du modèle -> AnimationLibrary


## Bibliothèque adaptée au squelette `skeleton` du modèle `model_path` (`base` si rien à changer).
static func library_for(model_path: String, skeleton: Skeleton3D, base: AnimationLibrary) -> AnimationLibrary:
	if model_path == REFERENCE_MODEL:
		return base
	if _cache.has(model_path):
		return _cache[model_path]
	var deltas := _rest_deltas(skeleton)
	var library := base if deltas.is_empty() else _shifted_library(base, deltas)
	_cache[model_path] = library
	return library


## Os dont le repos diffère de la référence -> décalage à ajouter.
static func _rest_deltas(skeleton: Skeleton3D) -> Dictionary:
	if _reference_rest.is_empty():
		var reference := (load(REFERENCE_MODEL) as PackedScene).instantiate()
		var ref_skeleton := reference.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for i in ref_skeleton.get_bone_count():
			_reference_rest[ref_skeleton.get_bone_name(i)] = ref_skeleton.get_bone_rest(i).origin
		reference.free()
	var deltas := {}
	for i in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(i)
		if not _reference_rest.has(bone):
			continue
		var delta: Vector3 = skeleton.get_bone_rest(i).origin - _reference_rest[bone]
		if delta.length() > EPSILON:
			deltas[bone] = delta
	return deltas


static func _shifted_library(base: AnimationLibrary, deltas: Dictionary) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for anim_name in base.get_animation_list():
		var anim := base.get_animation(anim_name).duplicate(true) as Animation
		for track in anim.get_track_count():
			if anim.track_get_type(track) != Animation.TYPE_POSITION_3D:
				continue
			var bone := anim.track_get_path(track).get_concatenated_subnames()
			if not deltas.has(bone):
				continue
			var delta: Vector3 = deltas[bone]
			for key in anim.track_get_key_count(track):
				anim.track_set_key_value(track, key, (anim.track_get_key_value(track, key) as Vector3) + delta)
		library.add_animation(anim_name, anim)
	return library
