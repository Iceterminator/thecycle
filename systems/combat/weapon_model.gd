class_name WeaponModel
extends Node3D
## Arme tenue en main (modèle 3D de WeaponData.model), créée par le Player sur tous les
## peers, enfant de la tête : le joueur local la voit en bas à droite de l'écran (au centre
## quand il vise), les autres joueurs la voient devant lui, orientée comme son regard
## (rotation de la tête synchronisée). Suit l'arme en main (Inventory.active_weapon_changed).
## Sans modèle pour l'arme en main, rien n'est affiché.
## Le modèle est tourné (model_rotation_deg), mis à l'échelle (model_length) et centré.
##
## Ressenti (joueur local seulement) : recul à chaque tir (kick), balancement qui suit la
## vue, balancement de marche, pose de sprint, arme qui remonte quand on la sort, et
## secousse de la caméra (Events.camera_shake_requested : explosions, dégâts reçus).
## La secousse passe par h_offset / v_offset / roulis : la direction du tir ne change pas.

const HIP_POSITION := Vector3(0.24, -0.21, -0.48)
const AIM_POSITION := Vector3(0.0, -0.13, -0.38)
const AIM_SPEED := 12.0
const HAND_SHIFT := Vector3(0.0, 0.04, -0.08)  ## arme des autres : un peu devant et au-dessus de la paume

const KICK_BACK := 0.07          ## recul de l'arme vers l'arrière (m) à pleine force
const KICK_UP_DEG := 8.0         ## canon qui se relève (degrés) à pleine force
const KICK_RECOVER := 14.0       ## vitesse de retour après un tir
const KICK_MAX := 1.6            ## cumul maximal pendant une rafale
const SWAY_PER_SPEED := 0.025    ## balancement (rad) par rad/s de rotation de la vue
const SWAY_MAX_DEG := 7.0
const SWAY_SPEED := 9.0
const BOB_FREQ := 1.4            ## pas par mètre parcouru (× 2π)
const BOB_AMP := 0.014           ## amplitude du balancement de marche (m)
const SPRINT_ROT_DEG := Vector3(-14.0, 32.0, 10.0)
const SPRINT_OFFSET := Vector3(-0.08, -0.05, 0.05)
const SPRINT_MIN_SPEED := 4.0    ## vitesse au sol à partir de laquelle la pose de sprint s'active
const RAISE_DROP := 0.25         ## l'arme sortie part de 25 cm plus bas…
const RAISE_TILT_DEG := 35.0     ## …et inclinée vers le bas
const RAISE_SPEED := 5.0
const SHAKE_OFFSET := 0.07       ## décalage maximal de la caméra (m)
const SHAKE_ROLL_DEG := 2.5
const SHAKE_DECAY := 2.5         ## perte de « secousse » par seconde

var player: Player
var _current: WeaponData
var _offset: Vector3 = Vector3.ZERO
var _base: Vector3 = HIP_POSITION
var _kick := 0.0
var _sway := Vector2.ZERO
var _last_look := Vector2.ZERO
var _bob_time := 0.0
var _bob_amp := 0.0
var _sprint := 0.0
var _raise := 0.0
var _trauma := 0.0
var _shake_time := 0.0


func setup(owner_player: Player) -> void:
	player = owner_player
	position = HIP_POSITION
	player.inventory.active_weapon_changed.connect(_refresh)
	Events.camera_shake_requested.connect(_on_camera_shake_requested)
	_refresh()


func _refresh() -> void:
	var weapon := player.inventory.get_active_weapon()
	if weapon == _current:
		return
	_current = weapon
	for child in get_children():
		child.queue_free()
	if weapon and weapon.model:
		_offset = weapon.model_offset
		add_child(build(weapon))
		_raise = 1.0


## Un tir du joueur local : strength ≈ 1 pour une arme qui recule fort.
func kick(strength: float) -> void:
	_kick = minf(_kick + strength, KICK_MAX)
	# Le recul vient de tourner la vue : ne pas le compter comme un mouvement de souris.
	_last_look = Vector2(player.rotation.y, player.head.rotation.x)
	_trauma = minf(_trauma + strength * 0.12, 1.0)


func _on_camera_shake_requested(point: Vector3, strength: float, reach: float) -> void:
	if player == null or not player.is_multiplayer_authority():
		return
	var falloff := 1.0 - player.camera.global_position.distance_to(point) / maxf(reach, 0.01)
	if falloff > 0.0:
		_trauma = minf(_trauma + strength * falloff, 1.0)


func _process(delta: float) -> void:
	if player == null:
		return
	var local := player.is_multiplayer_authority()
	visible = not player.health.is_dead and not player.is_evacuated and (local or player.body_mesh.visible)
	var t := clampf(delta * AIM_SPEED, 0.0, 1.0)
	if not local:
		# Dans la main droite du personnage, orientée comme le regard (tête synchronisée).
		if player.avatar and player.avatar.is_visible_in_tree():
			rotation = Vector3.ZERO
			global_position = player.avatar.hand_position() + player.head.global_basis * HAND_SHIFT
		else:
			position = position.lerp(HIP_POSITION + _offset, t)
		return
	var aiming := player.weapon.is_aiming
	_base = _base.lerp((AIM_POSITION if aiming else HIP_POSITION) + _offset, t)
	_kick = lerpf(_kick, 0.0, clampf(delta * KICK_RECOVER, 0.0, 1.0))
	_raise = maxf(_raise - delta * RAISE_SPEED, 0.0)
	var raise := _raise * _raise  # remontée rapide au début, douce à la fin

	# Balancement : l'arme traîne derrière les mouvements de la vue.
	var look := Vector2(player.rotation.y, player.head.rotation.x)
	var look_speed := Vector2.ZERO
	if delta > 0.0:
		look_speed = Vector2(wrapf(look.x - _last_look.x, -PI, PI), look.y - _last_look.y) / delta
	_last_look = look
	var max_sway := deg_to_rad(SWAY_MAX_DEG)
	var sway_target := (look_speed * SWAY_PER_SPEED).clampf(-max_sway, max_sway) * (0.3 if aiming else 1.0)
	_sway = _sway.lerp(sway_target, clampf(delta * SWAY_SPEED, 0.0, 1.0))

	# Balancement de marche, au rythme des pas.
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var grounded := player.is_on_floor()
	_bob_time += delta * speed * BOB_FREQ * TAU / 2.0 if grounded else 0.0
	var bob_target := clampf(speed / 5.0, 0.0, 1.6) if grounded and speed > 0.5 else 0.0
	_bob_amp = lerpf(_bob_amp, bob_target * (0.2 if aiming else 1.0), clampf(delta * 8.0, 0.0, 1.0))
	var bob := Vector3(sin(_bob_time) * BOB_AMP, -absf(cos(_bob_time)) * BOB_AMP, 0.0) * _bob_amp

	# Pose de sprint (arme baissée et tournée), annulée dès qu'on vise ou qu'on tire.
	var sprinting := grounded and not aiming and _kick < 0.05 and speed > SPRINT_MIN_SPEED \
			and Input.is_action_pressed("sprint")
	_sprint = lerpf(_sprint, 1.0 if sprinting else 0.0, clampf(delta * 10.0, 0.0, 1.0))

	position = _base + bob + SPRINT_OFFSET * _sprint \
			+ Vector3(0.0, _kick * 0.015 - raise * RAISE_DROP, _kick * KICK_BACK)
	rotation = Vector3(
		deg_to_rad(KICK_UP_DEG) * _kick - _sway.y - deg_to_rad(RAISE_TILT_DEG) * raise,
		-_sway.x,
		sin(_bob_time) * 0.015 * _bob_amp,
	) + SPRINT_ROT_DEG * (PI / 180.0) * _sprint
	_shake_camera(delta)


func _shake_camera(delta: float) -> void:
	_trauma = maxf(_trauma - delta * SHAKE_DECAY, 0.0)
	_shake_time += delta * 30.0
	var s := _trauma * _trauma
	var cam := player.camera
	cam.h_offset = sin(_shake_time * 1.3) * SHAKE_OFFSET * s
	cam.v_offset = sin(_shake_time * 1.7 + 1.0) * SHAKE_OFFSET * s
	cam.rotation.z = sin(_shake_time * 1.1 + 2.0) * deg_to_rad(SHAKE_ROLL_DEG) * s


## Modèle de l'arme prêt à poser : tourné, mis à l'échelle, centré sur l'origine, sans ombre.
static func build(weapon: WeaponData) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Model"
	var instance := weapon.model.instantiate() as Node3D
	pivot.add_child(instance)
	instance.rotation_degrees = weapon.model_rotation_deg
	# Boîte englobante de tous les maillages, dans le repère du pivot (avant mise à l'échelle).
	var box := AABB()
	var first := true
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var xf := Transform3D.IDENTITY
		var n: Node = mesh
		while n != pivot:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var part := xf * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	if first:
		return pivot
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var scale_factor := weapon.model_length / maxf(longest, 0.001)
	instance.scale = Vector3.ONE * scale_factor
	instance.position = -box.get_center() * scale_factor
	return pivot
