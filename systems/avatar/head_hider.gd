class_name HeadHider
extends SkeletonModifier3D
## Vue à la première personne : réduit l'os de la tête (et tout ce qui en dépend) à presque rien,
## après l'animation, pour que la tête ne passe jamais devant la caméra quand le corps bouge.

const BONE := "Head"
const TINY := Vector3.ONE * 0.001

var _bone := -1


## Branche le modificateur sous le squelette du personnage.
func setup(skeleton: Skeleton3D) -> void:
	name = "TeteCachee"
	skeleton.add_child(self)
	_bone = skeleton.find_bone(BONE)


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton and _bone >= 0:
		skeleton.set_bone_pose_scale(_bone, TINY)
