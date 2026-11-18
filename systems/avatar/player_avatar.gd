class_name PlayerAvatar
extends Node3D
## Corps animé d'un joueur, vu par les autres (Universal Base Characters + Universal
## Animation Library, Quaternius, CC0 : même squelette, les animations s'appliquent telles quelles).
## Enfant du BodyMesh du Player : il en suit la visibilité (caché pour le joueur local, à
## l'évacuation) et la transparence (camouflage).
##
## AnimationTree construit en code :
##   loco  (Transition) : jambes — repos, course (avant / arrière), sprint, accroupi, saut, mort
##   upper (Blend2, filtré sur le haut du corps) : pose « arme en main » par-dessus loco
##   shoot (OneShot, haut du corps) : coup de feu, déclenché par Weapon (play_shot)
## L'état vient de ce qui est déjà synchronisé (position, is_crouching, is_airborne, is_dead) :
## rien de plus ne passe par le réseau, sauf le tir qui réutilise l'effet de tir existant.

const MODELS := [
	"res://assets/models/characters/Superhero_Male_FullBody.gltf",
	"res://assets/models/characters/Superhero_Female_FullBody.gltf",
]
const ANIMS := "res://assets/models/characters/UAL1_Standard.glb"
const LOOPED := ["Idle", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Jump", "Pistol_Aim_Neutral"]
## Entrées de loco : [nom d'entrée, animation, à l'envers]
const LOCO := [
	["Idle", "Idle", false], ["Jog", "Jog_Fwd", false], ["Jog_Back", "Jog_Fwd", true],
	["Sprint", "Sprint", false], ["Crouch_Idle", "Crouch_Idle", false],
	["Crouch_Fwd", "Crouch_Fwd", false], ["Air", "Jump", false], ["Death", "Death01", false],
]
const UPPER_ROOT_BONE := "spine_01"   ## ce bone et ses enfants = haut du corps
const HAND_BONE := "hand_r"
const BODY_HEIGHT := 1.8       ## taille du personnage (m), comme la capsule du joueur
const BLEND := 0.2             ## fondu entre deux animations des jambes (s)
const MOVE_MIN := 0.4          ## m/s : en dessous, le joueur est immobile
const SPRINT_MIN := 7.5        ## m/s : au-dessus, il sprinte

static var _library: AnimationLibrary

var player: Player
var _body: MeshInstance3D
var _tree: AnimationTree
var _skeleton: Skeleton3D
var _hand := -1
var _meshes: Array[MeshInstance3D] = []
var _last_pos: Vector3
var _speed := 0.0
var _loco := ""


## Remplace la capsule `body` par le personnage (modèle choisi d'après l'id du joueur).
func setup(owner_player: Player, body: MeshInstance3D) -> void:
	player = owner_player
	_body = body
	var model := load_model(player)
	add_child(model)
	model.rotation.y = PI  # le glTF regarde vers +Z, Godot vers -Z
	var top := 0.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		_meshes.append(mi)
		top = maxf(top, mi.get_aabb().end.y)
	scale = Vector3.ONE * (BODY_HEIGHT / top if top > 0.0 else 1.0)
	position.y = -body.position.y  # le BodyMesh est centré sur la capsule : pieds au sol
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_hand = _skeleton.find_bone(HAND_BONE)
	var anim := AnimationPlayer.new()
	model.add_child(anim)  # root_node ".." = le modèle : pistes « Armature/Skeleton3D:os »
	anim.add_animation_library("", animation_library())
	_tree = AnimationTree.new()
	model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(anim)
	_tree.tree_root = _build_tree(model.get_path_to(_skeleton))
	_tree.active = true
	body.mesh = null
	_last_pos = player.global_position


## Personnage du joueur (homme ou femme selon son id), le même partout.
static func load_model(p: Player) -> Node3D:
	return (load(MODELS[absi(p.name.to_int()) % MODELS.size()]) as PackedScene).instantiate() as Node3D


static func animation_library() -> AnimationLibrary:
	if _library == null:
		var source := (load(ANIMS) as PackedScene).instantiate()
		var ap := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		_library = ap.get_animation_library("")
		for anim_name: String in LOOPED:
			if _library.has_animation(anim_name):
				_library.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		source.free()
	return _library


func _build_tree(skeleton_path: NodePath) -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeTransition.new()
	loco.xfade_time = BLEND
	loco.input_count = LOCO.size()
	bt.add_node("loco", loco)
	for i in LOCO.size():
		var entry: Array = LOCO[i]
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
	var bones: Array[int] = [_skeleton.find_bone(UPPER_ROOT_BONE)]
	while not bones.is_empty():
		var bone: int = bones.pop_back()
		if bone < 0:
			continue
		var path := NodePath("%s:%s" % [skeleton_path, _skeleton.get_bone_name(bone)])
		upper.set_filter_path(path, true)
		shoot.set_filter_path(path, true)
		bones.append_array(_skeleton.get_bone_children(bone))
	bt.add_node("upper", upper)
	bt.connect_node("upper", 0, "loco")
	bt.connect_node("upper", 1, "aim")
	bt.add_node("shoot", shoot)
	bt.connect_node("shoot", 0, "upper")
	bt.connect_node("shoot", 1, "fire")
	bt.connect_node("output", 0, "shoot")
	return bt


## Un coup de feu de ce joueur (appelé sur tous les peers par l'effet de tir).
func play_shot() -> void:
	if _tree and not player.health.is_dead:
		_tree.set("parameters/shoot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Position de la main droite (l'arme des autres joueurs s'y accroche).
func hand_position() -> Vector3:
	if _hand < 0:
		return global_position
	return (_skeleton.global_transform * _skeleton.get_bone_global_pose(_hand)).origin


func _process(delta: float) -> void:
	var pos := player.global_position
	var moved := pos - _last_pos
	_last_pos = pos
	if delta <= 0.0 or not is_visible_in_tree():
		return
	var flat := Vector3(moved.x, 0.0, moved.z) / delta
	# Les positions arrivent par paquets : vitesse lissée pour ne pas clignoter.
	_speed = lerpf(_speed, flat.length(), clampf(delta * 6.0, 0.0, 1.0))
	var dead := player.health.is_dead
	var loco := "Idle"
	if dead:
		loco = "Death"
	elif player.is_airborne:
		loco = "Air"
	elif player.is_crouching:
		loco = "Crouch_Fwd" if _speed > MOVE_MIN else "Crouch_Idle"
	elif _speed > SPRINT_MIN:
		loco = "Sprint"
	elif _speed > MOVE_MIN:
		loco = "Jog_Back" if flat.dot(-player.global_basis.z) < -0.5 else "Jog"
	if loco != _loco:
		_loco = loco
		_tree.set("parameters/loco/transition_request", loco)
	# Arme en main, sauf mort ou sprint (les bras suivent la course).
	var armed := 0.0 if dead or loco == "Sprint" else 1.0
	var current: float = _tree.get("parameters/upper/blend_amount")
	_tree.set("parameters/upper/blend_amount", move_toward(current, armed, delta * 5.0))
	for mi in _meshes:
		mi.transparency = _body.transparency
