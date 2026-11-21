class_name PlayerAvatar
extends Node3D
## Corps animé d'un joueur, vu par les autres (personnages et animations Quaternius ; prise fusil : Mixamo).
## Enfant du BodyMesh du Player : il en suit la visibilité (caché en local, à l'évacuation) et la transparence.
##
## AnimationTree construit en code :
##   loco  (Transition) : jambes — repos, course (avant / arrière), sprint, accroupi, saut, mort
##   upper (Blend2, filtré sur le haut du corps) : pose « arme en main » par-dessus loco
##   shoot (OneShot, haut du corps) : coup de feu, déclenché par Weapon (play_shot)
## L'état vient de ce qui est déjà synchronisé (position, is_crouching, is_airborne, is_dead) :
## rien de plus ne passe par le réseau, sauf le tir qui réutilise l'effet de tir existant.

const PlayerAvatarTools := preload("res://systems/avatar/player_avatar_tools.gd")
const Retarget := preload("res://systems/avatar/avatar_retarget.gd")
const APPEARANCE_CHECK := 0.5  ## s entre deux vérifications de l'apparence choisie

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
const PALM_BONES := ["hand_r", "index_01_r", "middle_01_r", "pinky_01_r"]  ## leur moyenne = paume
const PALM_DEPTH := 0.035  ## la poignée est tenue côté paume, pas sur les os (m)
const BODY_HEIGHT := 1.8       ## taille du personnage (m), comme la capsule du joueur
const BLEND := 0.2             ## fondu entre deux animations des jambes (s)
const MOVE_MIN := 0.4          ## m/s : en dessous, le joueur est immobile
const SPRINT_MIN := 7.5        ## m/s : au-dessus, il sprinte

var player: Player
var _body: MeshInstance3D
var _tree: AnimationTree
var _skeleton: Skeleton3D
var _palm := PackedInt32Array()
var _left_hand: LeftHandIk
var _meshes: Array[MeshInstance3D] = []
var _last_pos: Vector3
var _speed := 0.0
var _loco := ""
var _model: Node3D
var _model_path := ""
var _check_left := 0.0


## Remplace la capsule `body` par le personnage (apparence du profil, sinon d'après l'id du joueur).
func setup(owner_player: Player, body: MeshInstance3D) -> void:
	player = owner_player
	_body = body
	_build_model()
	body.mesh = null
	_last_pos = player.global_position


## Construit le modèle, son squelette et ses animations ; refait si l'apparence change.
func _build_model() -> void:
	var scene := model_scene(player)
	_model_path = scene.resource_path
	var model := scene.instantiate() as Node3D
	_model = model
	_meshes.clear()
	_loco = ""
	add_child(model)
	model.rotation.y = PI  # le glTF regarde vers +Z, Godot vers -Z
	var top := 0.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		_meshes.append(mi)
		top = maxf(top, mi.get_aabb().end.y)
	scale = Vector3.ONE * (BODY_HEIGHT / top if top > 0.0 else 1.0)
	position.y = -_body.position.y  # le BodyMesh est centré sur la capsule : pieds au sol
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_palm = palm_bones(_skeleton)
	_left_hand = LeftHandIk.new()
	_left_hand.setup(_skeleton)
	HandPoseModifier.new().setup(_skeleton, player)
	var anim := AnimationPlayer.new()
	model.add_child(anim)  # root_node ".." = le modèle : pistes « Armature/Skeleton3D:os »
	anim.add_animation_library("", animation_library_for(_model_path, _skeleton))
	_tree = AnimationTree.new()
	model.add_child(_tree)
	_tree.anim_player = _tree.get_path_to(anim)
	_tree.tree_root = PlayerAvatarTools.build_tree(_skeleton, model.get_path_to(_skeleton))
	_tree.active = true


## Apparence changée dans le lobby : on reconstruit le modèle (vérifié toutes les APPEARANCE_CHECK s).
func _check_appearance(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0:
		return
	_check_left = APPEARANCE_CHECK
	if model_scene(player).resource_path != _model_path:
		remove_child(_model)
		_model.queue_free()
		_build_model()


## Modèle du joueur : apparence choisie dans le lobby, sinon homme ou femme selon son id.
static func model_scene(p: Player) -> PackedScene:
	return PlayerAvatarTools.model_scene(p, MODELS)


## Animations adaptées aux proportions du squelette du modèle (voir avatar_retarget.gd).
static func animation_library_for(model_path: String, skeleton: Skeleton3D) -> AnimationLibrary:
	return Retarget.library_for(model_path, skeleton, animation_library())


## Animations de la bibliothèque Quaternius (boucles réglées), chargées une fois.
static func animation_library() -> AnimationLibrary:
	return PlayerAvatarTools.animation_library(ANIMS, LOOPED)


## Un coup de feu de ce joueur (appelé sur tous les peers par l'effet de tir).
## Main gauche sur `target` (position globale) ; null = pose d'animation.
func set_left_target(target: Variant) -> void:
	_left_hand.follow(target, global_basis)


func play_shot() -> void:
	if _tree and not player.health.is_dead:
		_tree.set("parameters/shoot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Point d'attache de l'arme : centre de la paume droite (l'arme des autres joueurs s'y accroche).
func hand_position() -> Vector3:
	if _palm.is_empty():
		return global_position
	return palm_global(_skeleton, _palm)


## Os de la paume droite présents dans le squelette.
static func palm_bones(skeleton: Skeleton3D) -> PackedInt32Array:
	return PlayerAvatarTools.palm_bones(skeleton)


## Point d'attache de l'arme : moyenne des os de la paume, décalée vers l'intérieur de la main.
static func palm_global(skeleton: Skeleton3D, bones: PackedInt32Array) -> Vector3:
	return PlayerAvatarTools.palm_global(skeleton, bones)


func _process(delta: float) -> void:
	_check_appearance(delta)
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
	# Arme en main (prise pistolet ou fusil), sauf mort ou sprint (les bras suivent la course).
	PlayerAvatarTools.apply_stance(_tree, player)
	var armed := 0.0 if dead or loco == "Sprint" else 1.0
	var current: float = _tree.get("parameters/upper/blend_amount")
	_tree.set("parameters/upper/blend_amount", move_toward(current, armed, delta * 5.0))
	for mi in _meshes:
		mi.transparency = _body.transparency
