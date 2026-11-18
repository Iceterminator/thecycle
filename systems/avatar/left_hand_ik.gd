@tool
class_name LeftHandIk
extends Node3D
## Place la main gauche d'un personnage sur un point du monde (repère « MainGauche » de
## l'arme en main) par IK à deux os (épaule, coude, main). Ce nœud est la cible de l'IK ;
## un second nœud « Coude » sert de pôle (direction du coude). Désactivé sans cible.

const ROOT_BONE := "upperarm_l"
const MIDDLE_BONE := "lowerarm_l"
const END_BONE := "hand_l"
const PALM_REACH := 0.07  ## bout « virtuel » de la chaîne : milieu de la paume (m)
const POLE_OFFSET := Vector3(-0.25, -0.35, 0.25)  ## coude : en bas, à gauche, en arrière (repère du corps)

var _ik: TwoBoneIK3D
var _pole: Node3D


## Branche la cible, le pôle et l'IK sous le squelette du personnage.
func setup(skeleton: Skeleton3D) -> void:
	skeleton.add_child(self)
	_pole = Node3D.new()
	_pole.name = "Coude"
	skeleton.add_child(_pole)
	_ik = TwoBoneIK3D.new()
	_ik.name = "MainGaucheIk"
	skeleton.add_child(_ik)
	_ik.setting_count = 1
	_ik.set_root_bone_name(0, ROOT_BONE)
	_ik.set_middle_bone_name(0, MIDDLE_BONE)
	_ik.set_end_bone_name(0, END_BONE)
	_ik.set_extend_end_bone(0, true)
	_ik.set_end_bone_length(0, PALM_REACH)
	_ik.set_end_bone_direction(0, SkeletonModifier3D.BONE_DIRECTION_FROM_PARENT)
	_ik.set_target_node(0, _ik.get_path_to(self))
	_ik.set_pole_node(0, _ik.get_path_to(_pole))
	_ik.active = false


## Pose la main sur `target` (position globale) ; null = IK coupée (animation d'origine).
func follow(target: Variant, body_basis: Basis) -> void:
	if target == null:
		_ik.active = false
		return
	var point: Vector3 = target
	global_position = point
	_pole.global_position = point + body_basis * POLE_OFFSET
	_ik.active = true
