extends RefCounted
## Glissade commune à tous les kits (celle du Furet est plus longue).
## État et logique ; la vitesse du joueur est modifiée via KitMovement.

var left: float = 0.0
var dir := Vector3.ZERO
var speed: float = 0.0
var cd: float = 0.0
var _m: KitMovement


func _init(movement: KitMovement) -> void:
	_m = movement


func duration() -> float:
	var kit := _m.kit
	return kit.move_param("slide", "slide_duration_s", Config.combat.slide_duration) * (1.0 + kit.get_effect("slide_duration_mult"))


func process(delta: float, on_floor: bool, input_dir: Vector2) -> void:
	var kit := _m.kit
	var player := _m.player
	if left > 0.0:
		left = maxf(left - delta, 0.0)
		if Input.is_action_just_pressed("jump") and on_floor:
			# Saut glissé : élan vers l'avant.
			var boost := kit.move_param("slide", "slide_jump_boost_mps", Config.combat.slide_jump_boost)
			player.velocity.y = Config.combat.jump_velocity
			_m._dash_velocity = _m.forced_horizontal() + dir * boost
			left = 0.0
			player.velocity.x = _m._dash_velocity.x
			player.velocity.z = _m._dash_velocity.z
			_m._jump_used = true
		elif not on_floor:
			left = 0.0
		return
	var sprinting := Input.is_action_pressed("sprint") and input_dir.y < 0.0
	if on_floor and sprinting and Input.is_action_just_pressed("crouch") and cd <= 0.0:
		dir = (player.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		speed = kit.move_param("slide", "slide_speed_mps", Config.combat.slide_speed)
		left = duration()
		cd = Config.combat.slide_cooldown
