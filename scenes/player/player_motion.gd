extends RefCounted
## Déplacement du joueur local, appelé par Player._physics_process : marche, saut, glissade,
## recul, ramper (à terre), forme de capsule accroupie, vol de spectateur.

var _p: Player


func _init(player: Player) -> void:
	_p = player


## Déplacement normal (hors largage, spectateur et vol admin).
func step(delta: float) -> void:
	var on_floor := _p.is_on_floor()
	_p.is_airborne = not on_floor
	if not on_floor:
		_p.velocity.y -= _p.gravity * delta
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# À terre : on rampe, rien d'autre (pas de saut ni de capacité).
	if _p.health.is_downed:
		_p.is_crouching = true
		apply_crouch_shape(delta)
		var crawl := (_p.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized() * Config.combat.downed_speed
		_p.velocity.x = crawl.x
		_p.velocity.z = crawl.z
		_p.move_and_slide()
		return
	# Saut, glissade et capacités du kit (jetpack, esquive, super saut…).
	_p.movement.pre_physics(delta, input_dir)
	_p.is_crouching = Input.is_action_pressed("crouch") or _p.movement.is_sliding()
	apply_crouch_shape(delta)
	if _p.movement.overrides_horizontal():
		var forced := _p.movement.forced_horizontal()
		_p.velocity.x = forced.x
		_p.velocity.z = forced.z
	else:
		_move_horizontal(delta, input_dir, on_floor)
	# Recul : ajouté au sol (où la vitesse horizontale est réimposée à chaque image).
	if on_floor:
		_p.velocity += _p._knockback
	_p._knockback = _p._knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	_p.move_and_slide()
	_p.movement.post_physics()


func _move_horizontal(delta: float, input_dir: Vector2, on_floor: bool) -> void:
	var direction := (_p.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var target := direction * _current_speed(input_dir)
	if on_floor:
		if direction:
			_p.velocity.x = target.x
			_p.velocity.z = target.z
		else:
			var speed := _current_speed(input_dir)
			_p.velocity.x = move_toward(_p.velocity.x, 0, speed)
			_p.velocity.z = move_toward(_p.velocity.z, 0, speed)
	else:
		# En l'air : contrôle partiel (Config.combat.air_control), total pendant le jetpack.
		var weight := clampf(_p.movement.air_control() * 10.0 * delta, 0.0, 1.0)
		_p.velocity.x = lerpf(_p.velocity.x, target.x, weight)
		_p.velocity.z = lerpf(_p.velocity.z, target.z, weight)


## Vitesse au sol : celle du kit ; sprint (en avançant) x Config.combat.sprint_multiplier.
func _current_speed(input_dir: Vector2) -> float:
	var buff := _p.buffs.get_mult("speed_mult") if _p.buffs else 1.0
	if _p.is_crouching:
		return Config.combat.crouch_speed * buff
	if Input.is_action_pressed("sprint") and input_dir.y < 0:
		return _p.kit.move_speed() * Config.combat.sprint_multiplier * buff
	return _p.kit.move_speed() * buff


func apply_crouch_shape(delta: float) -> void:
	var target := Player.CROUCH_HEIGHT if _p.is_crouching else Player.STAND_HEIGHT
	var shape := _p.collision.shape as CapsuleShape3D
	shape.height = lerpf(shape.height, target, 12.0 * delta)
	_p.collision.position.y = shape.height / 2.0
	_p.head.position.y = shape.height - Player.HEAD_OFFSET


## Spectateur (embarqué) : vol libre sans collision. Espace monte, Ctrl descend, Maj accélère.
func spectator_move(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := _p.head.global_basis * Vector3(input_dir.x, 0, input_dir.y)
	if Input.is_action_pressed("jump"):
		direction += Vector3.UP
	if Input.is_action_pressed("crouch"):
		direction += Vector3.DOWN
	if direction.length_squared() > 0.0:
		var speed := Config.SPECTATOR_SPEED * (2.0 if Input.is_action_pressed("sprint") else 1.0)
		_p.global_position += direction.normalized() * speed * delta


## Souris : regard (tête / corps), bascule de la capture, recapture au clic.
func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_p.rotate_y(-event.relative.x * Config.MOUSE_SENSITIVITY)
		_p.head.rotate_x(-event.relative.y * Config.MOUSE_SENSITIVITY)
		_p.head.rotation.x = clampf(_p.head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	elif event.is_action_pressed("toggle_mouse"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		# Un vrai clic recapture la souris ; pas la molette (sinon, défiler dans un menu
		# ouvert recapturait la souris par-dessus le menu).
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Camouflage vu par les autres : le corps devient transparent.
func apply_cloak() -> void:
	if _p.buffs and _p.body_mesh.visible:
		var speed := Vector2(_p.velocity.x, _p.velocity.z).length()
		_p.body_mesh.transparency = _p.buffs.get_cloak(speed)
