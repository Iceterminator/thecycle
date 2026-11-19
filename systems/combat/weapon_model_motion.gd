extends RefCounted
## Animation de l'arme du joueur local : recul, balancement de la vue, balancement de marche,
## pose de sprint, remontée à la sortie. WeaponModel appelle update() à chaque frame puis
## lit `pos` et `rot`. Les constantes de réglage restent dans WeaponModel.

var kick := 0.0
var raise_amount := 0.0
var pos := Vector3.ZERO  ## position calculée (hors `tune_offset`)
var rot := Vector3.ZERO  ## rotation calculée (radians)
var _player: Player
var _sway := Vector2.ZERO
var _last_look := Vector2.ZERO
var _bob_time := 0.0
var _bob_amp := 0.0
var _sprint := 0.0


func _init(owner_player: Player) -> void:
	_player = owner_player


## Un tir : le recul vient de tourner la vue, ne pas le compter comme un mouvement de souris.
func add_kick(strength: float) -> void:
	kick = minf(kick + strength, WeaponModel.KICK_MAX)
	_last_look = Vector2(_player.rotation.y, _player.head.rotation.x)


## Calcule `pos` et `rot` à partir de la position de base (visée / hanche déjà interpolée).
func update(delta: float, aiming: bool, base: Vector3) -> void:
	kick = lerpf(kick, 0.0, clampf(delta * WeaponModel.KICK_RECOVER, 0.0, 1.0))
	raise_amount = maxf(raise_amount - delta * WeaponModel.RAISE_SPEED, 0.0)
	var raise := raise_amount * raise_amount  # remontée rapide au début, douce à la fin

	# Balancement : l'arme traîne derrière les mouvements de la vue.
	var look := Vector2(_player.rotation.y, _player.head.rotation.x)
	var look_speed := Vector2.ZERO
	if delta > 0.0:
		look_speed = Vector2(wrapf(look.x - _last_look.x, -PI, PI), look.y - _last_look.y) / delta
	_last_look = look
	var max_sway := deg_to_rad(WeaponModel.SWAY_MAX_DEG)
	var sway_target := (look_speed * WeaponModel.SWAY_PER_SPEED).clampf(-max_sway, max_sway) * (0.3 if aiming else 1.0)
	_sway = _sway.lerp(sway_target, clampf(delta * WeaponModel.SWAY_SPEED, 0.0, 1.0))

	# Balancement de marche, au rythme des pas.
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var grounded := _player.is_on_floor()
	_bob_time += delta * speed * WeaponModel.BOB_FREQ * TAU / 2.0 if grounded else 0.0
	var bob_target := clampf(speed / 5.0, 0.0, 1.6) if grounded and speed > 0.5 else 0.0
	_bob_amp = lerpf(_bob_amp, bob_target * (0.2 if aiming else 1.0), clampf(delta * 8.0, 0.0, 1.0))
	var bob_amp := WeaponModel.BOB_AMP
	var bob := Vector3(sin(_bob_time) * bob_amp, -absf(cos(_bob_time)) * bob_amp, 0.0) * _bob_amp

	# Pose de sprint (arme baissée et tournée), annulée dès qu'on vise ou qu'on tire.
	var sprinting := grounded and not aiming and kick < 0.05 and speed > WeaponModel.SPRINT_MIN_SPEED \
			and Input.is_action_pressed("sprint")
	_sprint = lerpf(_sprint, 1.0 if sprinting else 0.0, clampf(delta * 10.0, 0.0, 1.0))

	pos = base + bob + WeaponModel.SPRINT_OFFSET * _sprint \
			+ Vector3(0.0, kick * 0.015 - raise * WeaponModel.RAISE_DROP, kick * WeaponModel.KICK_BACK)
	rot = Vector3(
		deg_to_rad(WeaponModel.KICK_UP_DEG) * kick - _sway.y - deg_to_rad(WeaponModel.RAISE_TILT_DEG) * raise,
		-_sway.x,
		sin(_bob_time) * 0.015 * _bob_amp,
	) + WeaponModel.SPRINT_ROT_DEG * (PI / 180.0) * _sprint
