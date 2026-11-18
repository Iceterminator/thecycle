class_name GripTunerCamera
extends Camera3D
## Caméra de dev du réglage de prise : vues fixes autour de l'arme en main (repère de la tête).

enum View { FPS, DROITE, GAUCHE, DESSUS }

const DISTANCE := 0.7
const NOMS: Array[String] = ["1re personne", "côté droit", "côté gauche", "dessus"]

var _player: Player
var _view: View = View.FPS


func setup(player: Player) -> void:
	_player = player
	near = 0.01
	fov = 50.0


func set_view(view: View) -> void:
	_view = view
	if view == View.FPS:
		current = false
		if is_instance_valid(_player) and _player.camera:
			_player.camera.current = true
	else:
		current = true


func view_name() -> String:
	return NOMS[_view]


func _process(_delta: float) -> void:
	if _view == View.FPS or not is_instance_valid(_player) or _player.held_weapon == null:
		return
	var held := _player.held_weapon
	var model := held.get_node_or_null("Model") as Node3D
	var target := model.global_position if model else held.global_position
	var basis := _player.head.global_basis
	match _view:
		View.DROITE:
			look_at_from_position(target + basis.x * DISTANCE, target, basis.y)
		View.GAUCHE:
			look_at_from_position(target - basis.x * DISTANCE, target, basis.y)
		View.DESSUS:
			look_at_from_position(target + basis.y * DISTANCE, target, -basis.z)
