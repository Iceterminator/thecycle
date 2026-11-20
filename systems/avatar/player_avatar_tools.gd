extends RefCounted
## Outils de PlayerAvatar : arbre d'animation construit en code (jambes, haut du corps, tir)
## et calcul du point d'attache de l'arme dans la paume.

static func build_tree(skeleton: Skeleton3D, skeleton_path: NodePath) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeTransition.new()
	loco.xfade_time = PlayerAvatar.BLEND
	loco.input_count = PlayerAvatar.LOCO.size()
	bt.add_node("loco", loco)
	for i in PlayerAvatar.LOCO.size():
		var entry: Array = PlayerAvatar.LOCO[i]
		loco.set_input_name(i, entry[0])
		var clip := AnimationNodeAnimation.new()
		clip.animation = entry[1]
		if entry[2]:
			clip.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD
		bt.add_node("clip_" + String(entry[0]), clip)
		bt.connect_node("loco", i, "clip_" + String(entry[0]))
	var aim := AnimationNodeAnimation.new()
	aim.animation = "Pistol_Aim_Neutral"
	bt.add_node("aim", aim)
	var upper := AnimationNodeBlend2.new()
	var shoot := AnimationNodeOneShot.new()
	shoot.fadein_time = 0.03
	shoot.fadeout_time = 0.12
	var fire := AnimationNodeAnimation.new()
	fire.animation = "Pistol_Shoot"
	bt.add_node("fire", fire)
	# Haut du corps seulement : spine_01 et tous ses descendants.
	upper.filter_enabled = true
	shoot.filter_enabled = true
	var bones: Array[int] = [skeleton.find_bone(PlayerAvatar.UPPER_ROOT_BONE)]
	while not bones.is_empty():
		var bone: int = bones.pop_back()
		if bone < 0:
			continue
		var path := NodePath("%s:%s" % [skeleton_path, skeleton.get_bone_name(bone)])
		upper.set_filter_path(path, true)
		shoot.set_filter_path(path, true)
		bones.append_array(skeleton.get_bone_children(bone))
	bt.add_node("upper", upper)
	bt.connect_node("upper", 0, "loco")
	bt.connect_node("upper", 1, "aim")
	bt.add_node("shoot", shoot)
	bt.connect_node("shoot", 0, "upper")
	bt.connect_node("shoot", 1, "fire")
	bt.connect_node("output", 0, "shoot")
	return bt



## Os de la paume droite présents dans le squelette.
static func palm_bones(skeleton: Skeleton3D) -> PackedInt32Array:
	var bones := PackedInt32Array()
	for bone_name: String in PlayerAvatar.PALM_BONES:
		var bone := skeleton.find_bone(bone_name)
		if bone >= 0:
			bones.append(bone)
	return bones


## Point d'attache de l'arme : moyenne des os de la paume, décalée vers l'intérieur de la
## main (normale de la paume, côté doigts repliés) pour que la poignée soit dans le creux.
static func palm_global(skeleton: Skeleton3D, bones: PackedInt32Array) -> Vector3:
	var points: Array[Vector3] = []
	var sum := Vector3.ZERO
	for bone in bones:
		var point := (skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin
		points.append(point)
		sum += point
	var center := sum / maxf(bones.size(), 1.0)
	if points.size() == PlayerAvatar.PALM_BONES.size():  # main, index, majeur, auriculaire
		var normal := (points[1] - points[3]).cross(points[2] - points[0])
		if normal.length_squared() > 0.0:
			center += normal.normalized() * PlayerAvatar.PALM_DEPTH
	return center



## Modèle d'un joueur : apparence de son profil, sinon un de `fallback` selon son id.
static func model_scene(p: Player, fallback: Array) -> PackedScene:
	var chosen := AppearanceData.get_by_id(ProfileManager.appearance_of(p.get_peer_id()))
	if chosen and chosen.model:
		return chosen.model
	return load(fallback[absi(p.name.to_int()) % fallback.size()]) as PackedScene


static var _library: AnimationLibrary

## Bibliothèque d'animations `path` (chargée une fois), animations `looped` en boucle.
static func animation_library(path: String, looped: Array) -> AnimationLibrary:
	if _library == null:
		var source := (load(path) as PackedScene).instantiate()
		var ap := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		_library = ap.get_animation_library("")
		for anim_name: String in looped:
			if _library.has_animation(anim_name):
				_library.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		source.free()
	return _library
