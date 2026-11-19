class_name WeaponModel
extends Node3D
## Arme tenue en main (modèle 3D de WeaponData.model), créée par le Player sur tous les
## peers, enfant de la tête : le joueur local la voit en bas à droite de l'écran (au centre
## quand il vise), les autres joueurs la voient devant lui, orientée comme son regard
## (rotation de la tête synchronisée). Suit l'arme en main (Inventory.active_weapon_changed).
## Sans modèle pour l'arme en main, rien n'est affiché.
## Le modèle est tourné (model_rotation_deg), mis à l'échelle (model_length) et son repère Poignee (scène du modèle) posé sur l'origine.
##
## Ressenti (joueur local seulement) : recul à chaque tir (kick), balancement qui suit la
## vue, balancement de marche, pose de sprint, arme qui remonte quand on la sort, et
## secousse de la caméra (Events.camera_shake_requested : explosions, dégâts reçus).
## La secousse passe par h_offset / v_offset / roulis : la direction du tir ne change pas.

const WeaponModelBuilder := preload("res://systems/combat/weapon_model_builder.gd")
const WeaponModelMotion := preload("res://systems/combat/weapon_model_motion.gd")

const HIP_POSITION := Vector3(0.24, -0.21, -0.48)
const AIM_POSITION := Vector3(0.0, -0.13, -0.38)
const AIM_SPEED := 12.0
const ARMS_AIM_SHIFT := Vector3(0.0, 0.03, 0.04)  ## visée avec les bras : corps un peu relevé et reculé
const HAND_SHIFT := Vector3.ZERO  ## ajustement fin, la paume est déjà calculée par l'avatar

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
var _motion: WeaponModelMotion
var _trauma := 0.0
var _shake_time := 0.0
var _model: Node3D
var _arms: FirstPersonArms  ## joueur local seulement
var tune_offset := Vector3.ZERO  ## réglage en jeu (GripTuner) : décalage de l'arme (m, repère de l'arme)
var tune_scale := 1.0  ## réglage en jeu : facteur de taille
var tune_left := Vector3.ZERO  ## réglage en jeu : décalage de la main gauche (m, repère de l'arme)


func setup(owner_player: Player) -> void:
	player = owner_player
	_motion = WeaponModelMotion.new(player)
	position = HIP_POSITION
	player.inventory.active_weapon_changed.connect(_refresh)
	Events.camera_shake_requested.connect(_on_camera_shake_requested)
	if player.is_multiplayer_authority() and not Net.is_dedicated_server:
		_arms = FirstPersonArms.new()
		_arms.name = "Arms"
		add_child(_arms)
		_arms.setup(player)
	_refresh()


func _refresh() -> void:
	var weapon := player.inventory.get_active_weapon()
	if weapon == _current:
		return
	_current = weapon
	if _model:
		_model.queue_free()
		_model = null
	if weapon and weapon.model:
		_offset = weapon.model_offset
		_model = build(weapon)
		add_child(_model)
		_motion.raise_amount = 1.0


## Un tir du joueur local : strength ≈ 1 pour une arme qui recule fort.
func kick(strength: float) -> void:
	_motion.add_kick(strength)
	_trauma = minf(_trauma + strength * 0.12, 1.0)
	if _arms:
		_arms.play_shot()


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
			player.avatar.set_left_target(left_hand_target())
		else:
			position = position.lerp(HIP_POSITION + _offset, t)
		return
	var aiming := player.weapon.is_aiming
	# Avec les bras, la visée ne déplace presque pas le corps (la pose tient déjà l'arme au centre).
	var aim_pos := HIP_POSITION + ARMS_AIM_SHIFT if _arms else AIM_POSITION
	_base = _base.lerp((aim_pos if aiming else HIP_POSITION) + _offset, t)
	_motion.update(delta, aiming, _base)
	var pos := _motion.pos
	var rot := _motion.rot
	if _arms:
		# Rotation autour de la caméra (pas de l'arme) : la tête du corps reste sur la caméra.
		transform = Transform3D(Basis.from_euler(rot), Vector3.ZERO) * Transform3D(Basis(), pos)
		_arms.set_reloading(player.weapon.is_reloading)
		_arms.anchor_head(-(HIP_POSITION + _offset))
		if _model:
			_model.position = _arms.hand_local() + tune_offset
	else:
		position = pos
		rotation = rot
		if _model:
			_model.position = tune_offset
	if _model:
		_model.scale = Vector3.ONE * tune_scale
	if _arms:
		_arms.set_left_target(left_hand_target())
	_shake_camera(delta)


func _shake_camera(delta: float) -> void:
	_trauma = maxf(_trauma - delta * SHAKE_DECAY, 0.0)
	_shake_time += delta * 30.0
	var s := _trauma * _trauma
	var cam := player.camera
	cam.h_offset = sin(_shake_time * 1.3) * SHAKE_OFFSET * s
	cam.v_offset = sin(_shake_time * 1.7 + 1.0) * SHAKE_OFFSET * s
	cam.rotation.z = sin(_shake_time * 1.1 + 2.0) * deg_to_rad(SHAKE_ROLL_DEG) * s


## Modèle de l'arme prêt à poser : tourné, mis à l'échelle, poignée sur l'origine, sans ombre.
static func build(weapon: WeaponData) -> Node3D:
	return WeaponModelBuilder.build(weapon)


## Position globale du bout du canon (repère « Bouche » du modèle en main) ; sans repère, celle de l'arme.
func muzzle_position() -> Vector3:
	var marker := _model.find_child("Bouche", true, false) as Node3D if _model else null
	return marker.global_position if marker else global_position


## Position globale où poser la main gauche (repère « MainGauche » du modèle + réglage), ou null.
func left_hand_target() -> Variant:
	var marker := _model.find_child("MainGauche", true, false) as Node3D if _model else null
	if marker == null:
		return null
	return marker.global_position + global_basis * tune_left


## Vrai si un modèle est affiché (faux sur le serveur dédié ou sans modèle).
func has_model() -> bool:
	return _model != null


## Arme actuellement affichée en main.
func current_weapon() -> WeaponData:
	return _current


## Échelle de l'instance du modèle (sans le réglage en jeu), 1.0 sans modèle.
func model_scale_factor() -> float:
	if _model == null or _model.get_child_count() == 0:
		return 1.0
	return (_model.get_child(0) as Node3D).scale.x


## Force la reconstruction du modèle (après modification de la scène ou des données).
func rebuild() -> void:
	_current = null
	_refresh()
