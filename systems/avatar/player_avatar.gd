class_name PlayerAvatar
extends Node3D
## Corps animé d'un joueur, vu par les autres (Universal Base Characters + Universal
## Animation Library, Quaternius, CC0 : même squelette, les animations s'appliquent telles quelles).
## Enfant du BodyMesh du Player : il en suit la visibilité (caché pour le joueur local, à la
## mort, à l'évacuation) et la transparence (camouflage).
## L'animation se déduit du déplacement observé (position déjà synchronisée) : rien de plus
## ne passe par le réseau.

const MODELS := [
	"res://assets/models/characters/Superhero_Male_FullBody.gltf",
	"res://assets/models/characters/Superhero_Female_FullBody.gltf",
]
const ANIMS := "res://assets/models/characters/UAL1_Standard.glb"
const LOOPED := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd"]
const BODY_HEIGHT := 1.8       ## taille du personnage (m), comme la capsule du joueur
const BLEND := 0.2             ## fondu entre deux animations (s)
const MOVE_MIN := 0.4          ## m/s : en dessous, le joueur est immobile
const SPRINT_MIN := 7.5        ## m/s : au-dessus, il sprinte

static var _library: AnimationLibrary

var player: Player
var _body: MeshInstance3D
var _anim: AnimationPlayer
var _meshes: Array[MeshInstance3D] = []
var _last_pos: Vector3
var _speed := 0.0


## Remplace la capsule `body` par le personnage (modèle choisi d'après l'id du joueur).
func setup(owner_player: Player, body: MeshInstance3D) -> void:
	player = owner_player
	_body = body
	var model := (load(MODELS[absi(player.name.to_int()) % MODELS.size()]) as PackedScene).instantiate() as Node3D
	add_child(model)
	model.rotation.y = PI  # le glTF regarde vers +Z, Godot vers -Z
	var top := 0.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		_meshes.append(mi)
		top = maxf(top, mi.get_aabb().end.y)
	scale = Vector3.ONE * (BODY_HEIGHT / top if top > 0.0 else 1.0)
	position.y = -body.position.y  # le BodyMesh est centré sur la capsule : pieds au sol
	_anim = AnimationPlayer.new()
	model.add_child(_anim)  # root_node ".." = le modèle : pistes « Armature/Skeleton3D:os »
	_anim.add_animation_library("", _get_library())
	_anim.play("Idle")
	body.mesh = null
	_last_pos = player.global_position


static func _get_library() -> AnimationLibrary:
	if _library == null:
		var source := (load(ANIMS) as PackedScene).instantiate()
		var ap := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		_library = ap.get_animation_library("")
		for anim_name: String in LOOPED:
			if _library.has_animation(anim_name):
				_library.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		source.free()
	return _library


func _process(delta: float) -> void:
	var pos := player.global_position
	var moved := pos - _last_pos
	_last_pos = pos
	if delta <= 0.0 or not is_visible_in_tree():
		return
	var flat := Vector3(moved.x, 0.0, moved.z) / delta
	# Les positions arrivent par paquets : vitesse lissée pour ne pas clignoter.
	_speed = lerpf(_speed, flat.length(), clampf(delta * 6.0, 0.0, 1.0))
	var anim_name := "Idle"
	if player.is_crouching:
		anim_name = "Crouch_Fwd" if _speed > MOVE_MIN else "Crouch_Idle"
	elif _speed > SPRINT_MIN:
		anim_name = "Sprint"
	elif _speed > MOVE_MIN:
		anim_name = "Jog_Fwd"
	if _anim.current_animation != anim_name:
		_anim.play(anim_name, BLEND)
	# Recule : même animation, jouée à l'envers.
	var backwards := _speed > MOVE_MIN and flat.dot(-player.global_basis.z) < -0.5
	_anim.speed_scale = -1.0 if backwards else 1.0
	for mi in _meshes:
		mi.transparency = _body.transparency
