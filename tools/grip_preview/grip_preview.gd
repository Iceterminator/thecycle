@tool
extends Node3D
## Aperçu de la prise des armes (outil d'éditeur, rien n'est sauvegardé).
## Mode d'emploi : ouvrir cette scène, choisir l'arme dans l'Inspecteur de la racine,
## ouvrir la scène « held » de son modèle (assets/models/weapons/held/) dans un autre
## onglet, déplacer le repère Poignee, Ctrl+S : l'aperçu se met à jour (vérifié toutes les 0,5 s).
## Caméra VueFPS : cocher « Aperçu » pour voir la vue du joueur à la première personne.

const REFRESH_DELAY := 0.5
const POSE_TIME := 0.1

@export var weapon: WeaponData:
	set(value):
		weapon = value
		_rebuild_weapon()
@export_enum("Homme", "Femme") var character := 0:
	set(value):
		character = value
		_rebuild_all()
@export_tool_button("Rafraîchir") var refresh := _rebuild_all

var _timer := 0.0
var _stamp := 0  ## dates de modification de la scène held et de l'arme
var _skeleton: Skeleton3D
var _palm := PackedInt32Array()
var _head := -1
var _left: LeftHandIk  ## IK de la main gauche (même réglage qu'en jeu)


func _ready() -> void:
	_rebuild_all()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_timer += delta
	if _timer < REFRESH_DELAY or weapon == null or weapon.model == null:
		return
	_timer = 0.0
	# Reconstruit seulement quand la scène held ou l'arme ont été sauvegardées.
	var stamp := FileAccess.get_modified_time(weapon.model.resource_path) \
			+ FileAccess.get_modified_time(weapon.resource_path)
	if stamp != _stamp:
		if _stamp != 0:
			ResourceLoader.load(weapon.model.resource_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		_stamp = stamp
		_rebuild_weapon()


func _rebuild_all() -> void:
	if not is_inside_tree():
		return
	_clear("Perso")
	var path: String = PlayerAvatar.MODELS[clampi(character, 0, PlayerAvatar.MODELS.size() - 1)]
	var holder := Node3D.new()
	holder.name = "Perso"
	add_child(holder)
	var model := (load(path) as PackedScene).instantiate() as Node3D
	holder.add_child(model)
	model.rotation.y = PI  # le glTF regarde vers +Z, Godot vers -Z
	var top := 0.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		top = maxf(top, (node as MeshInstance3D).get_aabb().end.y)
	holder.scale = Vector3.ONE * (PlayerAvatar.BODY_HEIGHT / top if top > 0.0 else 1.0)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_left = LeftHandIk.new()
	_left.setup(_skeleton)
	_palm = PlayerAvatar.palm_bones(_skeleton)
	_head = _skeleton.find_bone(FirstPersonArms.HEAD_BONE)
	var anim := AnimationPlayer.new()
	model.add_child(anim)
	anim.add_animation_library("", PlayerAvatar.animation_library())
	anim.play(FirstPersonArms.AIM)
	anim.seek(POSE_TIME, true)
	_place_camera()
	_rebuild_weapon()


func _rebuild_weapon() -> void:
	if not is_inside_tree():
		return
	_clear("Arme")
	_clear("Paume")
	if weapon == null or weapon.model == null or _skeleton == null:
		return
	var palm := to_local(PlayerAvatar.palm_global(_skeleton, _palm)) + FirstPersonArms.GRIP
	var gun := WeaponModel.build(weapon)
	gun.name = "Arme"
	add_child(gun)
	gun.position = palm  # orientée vers -Z, comme le personnage
	var marker := MeshInstance3D.new()
	marker.name = "Paume"
	var sphere := SphereMesh.new()
	sphere.radius = 0.01
	sphere.height = 0.02
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.RED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = material
	marker.mesh = sphere
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	marker.position = palm
	var left := gun.find_child("MainGauche", true, false) as Node3D
	_left.follow(left.global_position if left else null, global_basis)


## Caméra VueFPS : sur l'os de la tête + EYE (repère de l'arme, non mis à l'échelle).
func _place_camera() -> void:
	var camera := get_node_or_null("VueFPS") as Camera3D
	if camera == null or _head < 0:
		return
	var head := to_local((_skeleton.global_transform * _skeleton.get_bone_global_pose(_head)).origin)
	camera.position = head + FirstPersonArms.EYE
	camera.rotation = Vector3.ZERO


func _clear(node_name: String) -> void:
	var old := get_node_or_null(node_name)
	if old != null:
		old.name = "_ancien"  # libère le nom tout de suite
		old.queue_free()
