class_name FirstPersonArms
extends Node3D
## Bras du joueur local, vus à la première personne : son propre personnage
## (PlayerAvatar.load_model) en pose « arme en main », la caméra dans sa tête. Vue de
## l'intérieur, la tête n'est pas dessinée (faces arrière) : on voit les bras tendus.
## Enfant de WeaponModel : le corps suit le recul et le balancement de l'arme ; la tête
## reste calée sur la caméra et l'arme est posée dans la main droite (hand_local).

const AIM := "Pistol_Aim_Neutral"
const HEAD_BONE := "Head"
## Caméra par rapport à l'os de la tête (m, repère de l'arme) : à hauteur des yeux et
## juste devant le visage, qui reste ainsi derrière la caméra (matériaux à double face).
const EYE := Vector3(0.0, 0.02, -0.16)
const HIDDEN_MESHES := ["Eyes", "Eyebrows"]
const GRIP := Vector3(0.0, 0.05, -0.07)  ## centre de l'arme par rapport à la main droite (m)

var _skeleton: Skeleton3D
var _hand := -1
var _head := -1
var _anim: AnimationPlayer
var _reloading := false


func setup(p: Player) -> void:
	var model := PlayerAvatar.load_model(p)
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
	_hand = _skeleton.find_bone(PlayerAvatar.HAND_BONE)
	_head = _skeleton.find_bone(HEAD_BONE)
	_anim = AnimationPlayer.new()
	model.add_child(_anim)
	_anim.add_animation_library("", PlayerAvatar.animation_library())
	_anim.play(AIM)


func play_shot() -> void:
	if not _reloading:
		_anim.play("Pistol_Shoot", 0.03)
		_anim.queue(AIM)


func set_reloading(value: bool) -> void:
	if value == _reloading:
		return
	_reloading = value
	_anim.play("Pistol_Reload" if value else AIM, 0.15)


## Place le corps pour que la tête tombe sur `camera_local` (caméra dans le repère du parent).
func anchor_head(camera_local: Vector3) -> void:
	if _head >= 0:
		position += camera_local - _bone_local(_head) - EYE


## Où poser l'arme (repère du parent) : dans la main droite.
func hand_local() -> Vector3:
	return _bone_local(_hand) + GRIP if _hand >= 0 else Vector3.ZERO


func _bone_local(bone: int) -> Vector3:
	var global := (_skeleton.global_transform * _skeleton.get_bone_global_pose(bone)).origin
	return (get_parent() as Node3D).global_transform.affine_inverse() * global
