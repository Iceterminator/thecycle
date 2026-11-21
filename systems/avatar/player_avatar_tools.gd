extends RefCounted
## Outils de PlayerAvatar : arbre d'animation construit en code (jambes, haut du corps, tir),
## prise « pistolet » ou « fusil » selon l'arme en main, et point d'attache de l'arme dans la paume.

## Animations fusil (Mixamo converties par tools/retarget_mixamo.gd ; absentes = prise pistolet).
const RIFLE_ANIMS := "res://assets/animations/fusil_homme.res"
const RIFLE_PREFIX := "Fusil_"
const RIFLE_AIM := "Fusil_idle_aiming"
const RIFLE_HIP := "Fusil_idle"  ## arme basse (vue à la première personne, hors visée)
## Pas d'animation de tir en prise fusil : celles de Mixamo n'ont pas la même pose que la visée
## (l'arme sauterait) ; le recul vient de l'arme (WeaponModel.kick).
const RIFLE_SHOT := RIFLE_AIM
const RIFLE_RELOAD := "Fusil_rechargement_1"
## Types d'arme tenus à une main (prise pistolet) ; tous les autres = prise fusil.
const ONE_HANDED := [WeaponData.WeaponType.PISTOL, WeaponData.WeaponType.GADGET]

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
	_add_stance_node(bt, "aim", "Pistol_Aim_Neutral", RIFLE_AIM, 0.2)
	var upper := AnimationNodeBlend2.new()
	var shoot := AnimationNodeOneShot.new()
	shoot.fadein_time = 0.03
	shoot.fadeout_time = 0.12
	_add_stance_node(bt, "fire", "Pistol_Shoot", RIFLE_SHOT, 0.0)
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


## Nœud `node_name` : choix entre l'animation pistolet et l'animation fusil (entrées « pistolet » / « fusil »).
static func _add_stance_node(bt: AnimationNodeBlendTree, node_name: String, pistol: String, rifle: String, fade: float) -> void:
	var choice := AnimationNodeTransition.new()
	choice.xfade_time = fade
	choice.input_count = 2
	var anims := [pistol, rifle if has_rifle_anims() else pistol]
	for i in 2:
		choice.set_input_name(i, ["pistolet", "fusil"][i])
		var clip := AnimationNodeAnimation.new()
		clip.animation = anims[i]
		bt.add_node("%s_%d" % [node_name, i], clip)
	bt.add_node(node_name, choice)
	for i in 2:
		bt.connect_node(node_name, i, "%s_%d" % [node_name, i])


## Le joueur tient-il une arme à deux mains (et les animations fusil sont-elles là) ?
static func holds_rifle(p: Player) -> bool:
	var weapon := p.inventory.get_active_weapon()
	return weapon != null and has_rifle_anims() and not weapon.type in ONE_HANDED


static func has_rifle_anims() -> bool:
	return _library != null and _library.has_animation(RIFLE_AIM)


## Met la prise (visée et tir) de l'arbre `tree` d'accord avec l'arme en main du joueur.
static func apply_stance(tree: AnimationTree, p: Player) -> void:
	var stance := "fusil" if holds_rifle(p) else "pistolet"
	if tree.get("parameters/aim/current_state") != stance:
		tree.set("parameters/aim/transition_request", stance)
		tree.set("parameters/fire/transition_request", stance)



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
		if ResourceLoader.exists(RIFLE_ANIMS):
			var rifle := load(RIFLE_ANIMS) as AnimationLibrary
			for anim_name in rifle.get_animation_list():
				_library.add_animation(RIFLE_PREFIX + anim_name, rifle.get_animation(anim_name))
	return _library
