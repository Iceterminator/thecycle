extends RefCounted
## Calcul de la pose des doigts (outil make_hand_pose.gd) : chaque doigt refermé pas à pas jusqu'au
## contact (rayons sur les formes de collision de l'arme).

const STEP_DEG := 2.0
const MAX_DEG := [70.0, 95.0, 80.0]  ## repli maximal des phalanges 1, 2, 3 (degrés)
const TIP := 0.012  ## le bout du doigt dépasse le dernier os (m, avant mise à l'échelle)

var sk: Skeleton3D
var globals: Dictionary = {}  ## os -> pose globale (repère du squelette) après l'IK, mise à jour ici
var space: PhysicsDirectSpaceState3D


## Referme un doigt vers `grip` (repère du squelette) et range ses rotations locales dans `pose`.
func close_finger(finger: String, side: String, grip: Vector3, pose: HandPoseData) -> void:
	var bones: Array[int] = []
	for i in 4:
		bones.append(sk.find_bone("%s_%02d%s_%s" % [finger, i + 1, "_leaf" if i == 3 else "", side]))
	if bones.has(-1):
		return
	var rots: Array[Quaternion] = []
	for i in 3:
		rots.append(sk.get_bone_rest(bones[i]).basis.get_rotation_quaternion())
	var angles := [0.0, 0.0, 0.0]
	var active := [true, true, true]
	while active.has(true):
		var trial := rots.duplicate()
		var points := _chain(bones, trial)
		for j in 3:
			if active[j] and angles[j] + STEP_DEG <= MAX_DEG[j]:
				trial[j] = _curl(bones, trial, j, points, grip)
				points = _chain(bones, trial)
		var hit := _first_hit(points, space)
		var stopped := false
		for j in 3:
			if active[j] and (angles[j] + STEP_DEG > MAX_DEG[j] or j <= hit):
				active[j] = false
				stopped = true
		if hit >= 0:
			if not stopped:  # contact sur un segment déjà arrêté : on arrête la première phalange encore libre
				active[active.find(true)] = false
			continue
		for j in 3:
			if active[j]:
				rots[j] = trial[j]
				angles[j] += STEP_DEG
	for i in 3:
		pose.rotations[StringName(sk.get_bone_name(bones[i]))] = rots[i]


## Points (repère du squelette) des articulations 1, 2, 3, du bout de l'os 4 et du bout du doigt.
func _chain(bones: Array[int], rots: Array[Quaternion]) -> Array[Vector3]:
	var xf: Transform3D = globals[sk.get_bone_parent(bones[0])]
	var points: Array[Vector3] = []
	for i in 4:
		var rot := rots[i] if i < 3 else sk.get_bone_rest(bones[i]).basis.get_rotation_quaternion()
		xf = xf * Transform3D(Basis(rot), sk.get_bone_rest(bones[i]).origin)
		points.append(xf.origin)
	points.append(points[3] + (points[3] - points[2]).normalized() * TIP)
	return points


## Rotation locale de la phalange `j` repliée d'un pas vers `grip`.
func _curl(bones: Array[int], rots: Array[Quaternion], j: int, points: Array[Vector3], grip: Vector3) -> Quaternion:
	var dir := (points[j + 1] - points[j]).normalized()
	var to_grip := grip - points[j]
	var axis := dir.cross(to_grip - dir * dir.dot(to_grip)).normalized()
	if axis.is_zero_approx():
		return rots[j]
	var parent_rot := globals[sk.get_bone_parent(bones[0])].basis.get_rotation_quaternion() as Quaternion
	for i in j:
		parent_rot = parent_rot * rots[i]
	var global_rot := Quaternion(axis, deg_to_rad(STEP_DEG)) * parent_rot * rots[j]
	return (parent_rot.inverse() * global_rot).normalized()


## Premier segment (0 = phalange 1… 3 = bout du doigt) qui touche l'arme, -1 si aucun.
func _first_hit(points: Array[Vector3], space: PhysicsDirectSpaceState3D) -> int:
	var xf := sk.global_transform
	for i in points.size() - 1:
		var query := PhysicsRayQueryParameters3D.create(xf * points[i], xf * points[i + 1])
		query.hit_back_faces = true
		if not space.intersect_ray(query).is_empty():
			return mini(i, 2)
	return -1

