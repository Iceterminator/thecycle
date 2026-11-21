class_name HandPoseModifier
extends SkeletonModifier3D
## Pose des doigts de l'arme en main (WeaponData.hand_pose), appliquée après l'animation :
## chaque phalange listée prend sa rotation locale. Sans pose : doigts de l'animation.
## Suit tout seul l'arme en main du joueur (aucun appel à faire au changement d'arme).

var fixed_pose: HandPoseData  ## sans joueur (outils) : pose appliquée telle quelle
var _player: Player
var _pose: HandPoseData
var _bones: Dictionary = {}  ## nom d'os -> index, pour la pose en cours


## Branche le modificateur sous le squelette du personnage de `player`.
func setup(skeleton: Skeleton3D, player: Player) -> void:
	name = "PoseDesDoigts"
	_player = player
	skeleton.add_child(self)


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var pose := fixed_pose
	if _player:
		var weapon := _player.inventory.get_active_weapon()
		pose = weapon.hand_pose if weapon else null
	if pose != _pose:
		_pose = pose
		_bones.clear()
		if pose:
			for bone_name: StringName in pose.rotations:
				_bones[bone_name] = skeleton.find_bone(bone_name)
	if _pose == null:
		return
	for bone_name: StringName in _pose.rotations:
		var bone: int = _bones[bone_name]
		if bone >= 0:
			skeleton.set_bone_pose_rotation(bone, _pose.rotations[bone_name])
