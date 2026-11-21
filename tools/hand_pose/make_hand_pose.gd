extends Node
## Outil : pose des doigts d'une arme (data/hand_poses/<arme>.tres, branchée sur WeaponData.hand_pose).
## L'Homme est mis en visée fusil, l'arme posée dans sa main comme en jeu (Poignee au centre de la
## paume, main gauche par IK sur MainGauche ; cibles des doigts : TARGETS) ; puis les doigts partent tendus et se referment
## ensemble, pas à pas, chaque phalange vers la poignée : dès qu'un segment touche l'arme, il
## s'arrête avec ceux qui le précèdent, les suivants continuent (le bout du doigt vient s'y poser).
## Lancer (avec fenêtre si --capture) :
##   <godot> --path . res://tools/hand_pose/make_hand_pose.tscn -- --arme=karma_1 [--capture=fichier.png]

const Builder := preload("res://systems/combat/weapon_model_builder.gd")
const Tools := preload("res://systems/avatar/player_avatar_tools.gd")
const Solver := preload("res://tools/hand_pose/hand_pose_solver.gd")
const MODEL := "res://assets/models/characters/Superhero_Male_FullBody.gltf"
const OUT_DIR := "res://data/hand_poses/"
const FINGERS := ["thumb", "index", "middle", "ring", "pinky"]
## Repères facultatifs de la scène held vers lesquels se referment les doigts (sinon : Poignee à droite,
## MainGauche à gauche) : « main » ou « main_doigt ».
const TARGETS := {"r_index": "Detente", "r_thumb": "Pouce"}

var _sk: Skeleton3D
var _globals: Dictionary = {}  ## os -> pose globale (repère du squelette) après l'IK


func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var id: String = args.get("arme", "karma_1")
	var data := load("res://data/weapons/%s.tres" % id) as WeaponData
	var model := (load(MODEL) as PackedScene).instantiate() as Node3D
	var holder := Node3D.new()
	add_child(holder)
	holder.add_child(model)
	model.rotation.y = PI
	var top := 0.0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		top = maxf(top, mi.get_aabb().end.y)
	holder.scale = Vector3.ONE * (PlayerAvatar.BODY_HEIGHT / top)
	_sk = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var anim := AnimationPlayer.new()
	model.add_child(anim)
	anim.add_animation_library("", PlayerAvatar.animation_library_for(MODEL, _sk))
	anim.play(Tools.RIFLE_AIM)
	anim.seek(0.5, true)
	anim.pause()
	await get_tree().process_frame
	var weapon := Builder.build(data)
	add_child(weapon)
	weapon.global_position = PlayerAvatar.palm_global(_sk, PlayerAvatar.palm_bones(_sk))
	var left_target := weapon.find_child("MainGauche", true, false) as Node3D
	var ik := LeftHandIk.new()
	ik.setup(_sk)
	if left_target:
		ik.follow(left_target.global_position, Basis.IDENTITY)
	for mi: MeshInstance3D in weapon.find_children("*", "MeshInstance3D", true, false):
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = mi.mesh.create_trimesh_shape()
		body.add_child(shape)
		add_child(body)
		body.global_transform = mi.global_transform
	await _sk.skeleton_updated
	for b in _sk.get_bone_count():
		_globals[b] = _sk.get_bone_global_pose(b)
	await get_tree().physics_frame
	var solver := Solver.new()
	solver.sk = _sk
	solver.globals = _globals
	solver.space = get_viewport().world_3d.direct_space_state
	var to_sk := _sk.global_transform.affine_inverse()
	var grips := {"r": to_sk * weapon.global_position, "l": to_sk * (left_target.global_position if left_target else weapon.global_position)}
	var pose := HandPoseData.new()
	for side: String in grips:
		print("[Doigts] main %s : à %.3f m de sa cible" % [side, (_globals[_sk.find_bone("hand_" + side)].origin - grips[side]).length()])
		var hand_marker := weapon.find_child(TARGETS.get(side, "-"), true, false) as Node3D
		var hand_target: Vector3 = to_sk * hand_marker.global_position if hand_marker else grips[side]
		for finger: String in FINGERS:
			var marker := weapon.find_child(TARGETS.get(side + "_" + finger, "-"), true, false) as Node3D
			solver.close_finger(finger, side, to_sk * marker.global_position if marker else hand_target, pose)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var path := OUT_DIR + id + ".tres"
	ResourceSaver.save(pose, path)
	data.hand_pose = load(path) as HandPoseData
	ResourceSaver.save(data, data.resource_path)
	print("[Doigts] %d phalanges -> %s" % [pose.rotations.size(), path])
	if args.has("capture"):
		await _capture(pose, weapon, args["capture"])
	get_tree().quit()


## Position (monde) des yeux : juste devant l'os de la tête, comme la caméra en jeu.
func _eye() -> Vector3:
	var head := _sk.global_transform * _sk.get_bone_global_pose(_sk.find_bone("Head"))
	return head.origin + Vector3(0, 0.08, -0.12)


## Captures de contrôle (main droite, pouce, main gauche dessous et côté) avec la pose appliquée.
func _capture(pose: HandPoseData, weapon: Node3D, file: String) -> void:
	var applied := HandPoseModifier.new()
	applied.fixed_pose = pose
	applied.setup(_sk, null)  # après l'IK de la main gauche, comme en jeu
	get_window().size = Vector2i(900, 600)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40.0
	var light := DirectionalLight3D.new()
	add_child(light)
	light.rotation_degrees = Vector3(-50, 40, 0)
	var right := weapon.global_position
	var left_marker := weapon.find_child("MainGauche", true, false) as Node3D
	var left := left_marker.global_position if left_marker else right
	# [point regardé, position de la caméra par rapport à lui, suffixe du fichier]
	var views := [[right, Vector3(0.35, 0.1, 0.05), ""], [right, Vector3(-0.05, -0.2, -0.3), "_pouce"],
			[left, Vector3(0.05, -0.3, -0.1), "_gauche_dessous"], [left, Vector3(-0.3, 0.05, -0.15), "_gauche_cote"],
			[left, Vector3(-0.9, 0.1, 0.35), "_bras_gauche"], [left, _eye() - left, "_yeux"]]
	for view in views:
		cam.global_position = view[0] + view[1]
		cam.look_at(view[0])
		for k in 6:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(file.get_basename() + view[2] + ".png")
