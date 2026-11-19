class_name AdminFly
extends RefCounted
## Vol rapide du joueur admin (type noclip), purement local : le client décide de son
## déplacement (CLAUDE.md règle 2). Pas de gravité, pas de collision.
## Direction = caméra ; Espace monte, Ctrl (crouch) descend, Maj (sprint) accélère.

const SPEED := 40.0
const SPRINT_MULTIPLIER := 2.5
const MIN_HEIGHT_MARGIN := 5.0  # reste au-dessus de Config.KILL_Y pour ne pas mourir

var active: bool = false


func set_active(player: Player, value: bool) -> void:
	active = value
	player.velocity = Vector3.ZERO


## Un pas de vol (remplace tout le déplacement normal du joueur).
func step(player: Player, delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := player.camera.global_basis
	var direction := cam_basis * Vector3(input_dir.x, 0.0, input_dir.y)
	direction.y += Input.get_axis("crouch", "jump")
	var speed := SPEED * (SPRINT_MULTIPLIER if Input.is_action_pressed("sprint") else 1.0)
	player.velocity = Vector3.ZERO
	if direction.length() > 0.01:
		player.global_position += direction.normalized() * speed * delta
	player.global_position.y = maxf(player.global_position.y, Config.KILL_Y + MIN_HEIGHT_MARGIN)
