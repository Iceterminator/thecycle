class_name FirstPersonArms
extends Node3D
## Bras du joueur local, vus à la première personne : son propre personnage
## (PlayerAvatar.model_scene) en pose « arme en main », la caméra dans sa tête. Vue de
## l'intérieur, la tête n'est pas dessinée (faces arrière) : on voit les bras tendus.
## Enfant de WeaponModel : le corps suit le recul et le balancement de l'arme ; la tête
## reste calée sur la caméra et l'arme est posée au centre de la paume droite (hand_local).

const Tools := preload("res://systems/avatar/player_avatar_tools.gd")
const AIM := "Pistol_Aim_Neutral"  ## pose prise pistolet (fusil : Tools.RIFLE_AIM)
const HEAD_BONE := "Head"
## Caméra par rapport à l'os de la tête (m, repère de l'arme) : à hauteur des yeux et
## juste devant le visage, qui reste ainsi derrière la caméra (matériaux à double face).
const EYE := Vector3(0.0, 0.02, -0.16)
const HIDDEN_MESHES := ["Eyes", "Eyebrows"]
const GRIP := Vector3.ZERO  ## ajustement fin du point d'attache (m, repère de l'arme)

var _skeleton: Skeleton3D
var _palm := PackedInt32Array()
var _head := -1
var _anim: AnimationPlayer
var _reloading := false
var _rifle := false  ## prise fusil (arme à deux mains en main)
var _aiming := false  ## visée (prise fusil : arme à l'épaule ; sinon arme basse)
var _left_hand: LeftHandIk
var _player: Player
var _model: Node3D
var _model_path := ""
var _check_left := 0.0


func setup(p: Player) -> void:
	_player = p
	var scene := PlayerAvatar.model_scene(p)
	_model_path = scene.resource_path
	var model := scene.instantiate() as Node3D
	_model = model
	_reloading = false
	add_child(model)
	model.rotation.y = PI  # le glTF regarde vers +Z, Godot vers -Z
	var top := 0.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = not String(mi.name) in HIDDEN_MESHES
		top = maxf(top, mi.get_aabb().end.y)
	scale = Vector3.ONE * (PlayerAvatar.BODY_HEIGHT / top if top > 0.0 else 1.0)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_palm = PlayerAvatar.palm_bones(_skeleton)
	_head = _skeleton.find_bone(HEAD_BONE)
	_anim = AnimationPlayer.new()
	model.add_child(_anim)
	_anim.add_animation_library("", PlayerAvatar.animation_library_for(_model_path, _skeleton))
	_rifle = Tools.holds_rifle(p)
	_anim.play(_aim())
	_left_hand = LeftHandIk.new()
	_left_hand.setup(_skeleton)
	HeadHider.new().setup(_skeleton)
	HandPoseModifier.new().setup(_skeleton, p)


## Apparence changée dans le lobby : on refait les bras avec le nouveau modèle.
func _process(delta: float) -> void:
	if _player and (Tools.holds_rifle(_player) != _rifle or _player.weapon.is_aiming != _aiming):
		_rifle = Tools.holds_rifle(_player)
		_aiming = _player.weapon.is_aiming
		if not _reloading:
			_anim.play(_aim(), 0.15)
	_check_left -= delta
	if _check_left > 0.0 or _player == null:
		return
	_check_left = PlayerAvatar.APPEARANCE_CHECK
	if PlayerAvatar.model_scene(_player).resource_path != _model_path:
		remove_child(_model)
		_model.queue_free()
		setup(_player)


## Main gauche sur `target` (position globale) ; null = pose d'animation.
func set_left_target(target: Variant) -> void:
	_left_hand.follow(target, global_basis)


func play_shot() -> void:
	if not _reloading and not _rifle:  # prise fusil : recul de l'arme seulement (voir Tools.RIFLE_SHOT)
		_anim.play("Pistol_Shoot", 0.03)
		_anim.queue(_aim())


func set_reloading(value: bool) -> void:
	if value == _reloading:
		return
	_reloading = value
	var reload: String = Tools.RIFLE_RELOAD if _rifle else "Pistol_Reload"
	_anim.play(reload if value else _aim(), 0.15)


## Place le corps pour que la tête tombe sur `camera_local` (caméra dans le repère du parent).
func anchor_head(camera_local: Vector3) -> void:
	if _head >= 0:
		position += camera_local - _bone_local(_head) - EYE


## Où poser l'arme (repère du parent) : centre de la paume droite.
func hand_local() -> Vector3:
	if _palm.is_empty():
		return Vector3.ZERO
	return _to_parent(PlayerAvatar.palm_global(_skeleton, _palm)) + GRIP


func _bone_local(bone: int) -> Vector3:
	return _to_parent((_skeleton.global_transform * _skeleton.get_bone_global_pose(bone)).origin)


func _to_parent(global: Vector3) -> Vector3:
	return (get_parent() as Node3D).global_transform.affine_inverse() * global


## Pose selon la prise : pistolet (une seule pose), fusil à l'épaule en visée, arme basse sinon.
func _aim() -> String:
	if not _rifle:
		return AIM
	return Tools.RIFLE_AIM if _aiming else Tools.RIFLE_HIP
