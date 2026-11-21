extends SceneTree
## Outil : convertit les animations Mixamo (assets/animations/fusil/*.fbx, squelette « mixamorig »)
## pour le squelette des personnages (Superhero, Quaternius) et les range dans une bibliothèque
## assets/animations/fusil_homme.res (une animation par fichier, nommée comme lui).
## Les deux squelettes sont au repos en pose T, tournés vers +Z : chaque os reçoit la même
## rotation (dans l'espace du personnage) que son équivalent Mixamo, par rapport à ce repos.
## Le bassin suit la hauteur Mixamo à l'échelle du personnage ; son déplacement au sol est
## retiré (c'est le jeu qui fait avancer le joueur).
## À lancer depuis la racine du projet :
##   godot --headless --path . -s tools/retarget_mixamo.gd
## Pas de référence aux classes du projet par leur nom (script lancé avec -s).

const SOURCE_DIR := "res://assets/animations/fusil/"
const OUTPUT := "res://assets/animations/fusil_homme.res"
const TARGET_MODEL := "res://assets/models/characters/Superhero_Male_FullBody.gltf"
const TRACK_PREFIX := "Armature/Skeleton3D:"  ## chemin des pistes, comme la bibliothèque Quaternius
const SOURCE_ANIM := "mixamo_com"
const FPS := 30.0
const SKIP := ["x_bot"]  ## fichiers sans animation utile
## Mots qui marquent une animation en boucle.
const LOOP_WORDS := ["idle", "walk", "run", "sprint", "jump_loop"]
## Os Mixamo (sans « mixamorig_ ») -> os du personnage. Doigts ajoutés par _bone_map().
const BONES := {
	"Hips": "pelvis", "Spine": "spine_01", "Spine1": "spine_02", "Spine2": "spine_03",
	"Neck": "neck_01", "Head": "Head",
	"LeftShoulder": "clavicle_l", "LeftArm": "upperarm_l", "LeftForeArm": "lowerarm_l", "LeftHand": "hand_l",
	"RightShoulder": "clavicle_r", "RightArm": "upperarm_r", "RightForeArm": "lowerarm_r", "RightHand": "hand_r",
	"LeftUpLeg": "thigh_l", "LeftLeg": "calf_l", "LeftFoot": "foot_l", "LeftToeBase": "ball_l",
	"RightUpLeg": "thigh_r", "RightLeg": "calf_r", "RightFoot": "foot_r", "RightToeBase": "ball_r",
}
const FINGERS := {"Thumb": "thumb", "Index": "index", "Middle": "middle", "Ring": "ring", "Pinky": "pinky"}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var target := (load(TARGET_MODEL) as PackedScene).instantiate()
	root.add_child(target)
	var tsk := target.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	tsk.reset_bone_poses()
	var library := AnimationLibrary.new()
	for file in ResourceLoader.list_directory(SOURCE_DIR):
		if not file.ends_with(".fbx") or file.get_basename() in SKIP:
			continue
		var anim := _convert(SOURCE_DIR + file, tsk)
		if anim:
			library.add_animation(file.get_basename(), anim)
			print("[Mixamo] %s : %.2f s" % [file.get_basename(), anim.length])
	var err := ResourceSaver.save(library, OUTPUT)
	print("[Mixamo] %d animations -> %s (%s)" % [library.get_animation_list().size(), OUTPUT, error_string(err)])
	quit()


## Os Mixamo complet -> os du personnage (corps + phalanges 1 à 3 des doigts).
func _bone_map() -> Dictionary:
	var map := {}
	for key: String in BONES:
		map["mixamorig_" + key] = BONES[key]
	for side in [["Left", "l"], ["Right", "r"]]:
		for finger: String in FINGERS:
			for i in 3:
				map["mixamorig_%sHand%s%d" % [side[0], finger, i + 1]] = "%s_%02d_%s" % [FINGERS[finger], i + 1, side[1]]
	return map


## Une animation Mixamo convertie pour le squelette `tsk` (au repos), ou null.
func _convert(path: String, tsk: Skeleton3D) -> Animation:
	var source := (load(path) as PackedScene).instantiate()
	root.add_child(source)
	var ssk := source.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	if not player.has_animation(SOURCE_ANIM):
		source.queue_free()
		return null
	var clip := player.get_animation(SOURCE_ANIM)
	player.play(SOURCE_ANIM)
	var pairs := []  ## [os source, os cible, correction de repos]
	for src_name: String in _bone_map():
		var s := ssk.find_bone(src_name)
		var t := tsk.find_bone(_bone_map()[src_name])
		if s >= 0 and t >= 0:
			var fix := ssk.get_bone_global_rest(s).basis.get_rotation_quaternion().inverse() \
					* tsk.get_bone_global_rest(t).basis.get_rotation_quaternion()
			pairs.append([s, t, fix])
	var hips := ssk.find_bone("mixamorig_Hips")
	var pelvis := tsk.find_bone("pelvis")
	var scale := tsk.get_bone_global_rest(pelvis).origin.y / maxf(ssk.get_bone_global_rest(hips).origin.y, 0.001)
	var frames := maxi(int(round(clip.length * FPS)), 1)
	var rotations := {}  ## os cible -> Array[Quaternion]
	var hip_positions: Array[Vector3] = []
	for f in frames + 1:
		player.seek(minf(f / FPS, clip.length), true)
		var globals := {}  ## os cible -> rotation dans l'espace du personnage
		for pair in pairs:
			globals[pair[1]] = ssk.get_bone_global_pose(pair[0]).basis.get_rotation_quaternion() * pair[2]
		for t: int in globals:
			var parent := tsk.get_bone_parent(t)
			var parent_rot := _target_global(tsk, parent, globals)
			if not rotations.has(t):
				rotations[t] = []
			rotations[t].append((parent_rot.inverse() * globals[t]).normalized())
		hip_positions.append(ssk.get_bone_global_pose(hips).origin * scale)
	var anim := _build(tsk, rotations, _in_place(hip_positions, tsk, pelvis), frames)
	anim.loop_mode = Animation.LOOP_LINEAR if _is_loop(path.get_file()) else Animation.LOOP_NONE
	source.queue_free()
	return anim


## Rotation globale (espace du personnage) de l'os `bone` : convertie si connue, sinon repos.
func _target_global(tsk: Skeleton3D, bone: int, globals: Dictionary) -> Quaternion:
	if bone < 0:
		return Quaternion.IDENTITY
	if globals.has(bone):
		return globals[bone]
	return _target_global(tsk, tsk.get_bone_parent(bone), globals) * tsk.get_bone_rest(bone).basis.get_rotation_quaternion()


## Positions locales du bassin, sans le déplacement au sol (dérive entre 1re et dernière image).
func _in_place(positions: Array[Vector3], tsk: Skeleton3D, pelvis: int) -> Array[Vector3]:
	var start := positions[0]
	var drift := positions[-1] - start
	var parent_inv := tsk.get_bone_global_rest(tsk.get_bone_parent(pelvis)).affine_inverse() \
			if tsk.get_bone_parent(pelvis) >= 0 else Transform3D.IDENTITY
	var rest := tsk.get_bone_global_rest(pelvis).origin
	var out: Array[Vector3] = []
	for i in positions.size():
		var k := float(i) / maxf(positions.size() - 1, 1)
		var p := positions[i] - Vector3(start.x + drift.x * k, 0.0, start.z + drift.z * k)
		out.append(parent_inv * Vector3(p.x + rest.x, p.y, p.z + rest.z))
	return out


func _build(tsk: Skeleton3D, rotations: Dictionary, hips: Array[Vector3], frames: int) -> Animation:
	var anim := Animation.new()
	anim.length = frames / FPS
	var pelvis := tsk.find_bone("pelvis")
	var track := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track, TRACK_PREFIX + tsk.get_bone_name(pelvis))
	for f in hips.size():
		anim.position_track_insert_key(track, f / FPS, hips[f])
	for t: int in rotations:
		track = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, TRACK_PREFIX + tsk.get_bone_name(t))
		var keys: Array = rotations[t]
		for f in keys.size():
			anim.rotation_track_insert_key(track, f / FPS, keys[f])
	return anim


func _is_loop(file: String) -> bool:
	for word: String in LOOP_WORDS:
		if file.contains(word):
			return true
	return false
