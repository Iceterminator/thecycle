class_name KitMovement
extends Node
## Capacités de mouvement du kit (étape 8b), selon KitData.mobility_type, plus la
## glissade commune à tous les kits. Valeurs dans KitData.movement (référence).
##
## Le déplacement est décidé par le client propriétaire (règle 2, exception) : ce nœud
## modifie la vitesse du Player dans son _physics_process. Ce qui fait des dégâts
## (plongée du Martinet, coup de poing du Bastion) est DEMANDÉ au serveur, qui vérifie la
## recharge et la position puis applique. Créé en code par le Player sur tous les peers
## (nœud « Movement ») pour que les RPC aient le même chemin partout.
##
## - Jetpack (Martinet) : maintenir Saut 0,2 s ; carburant ; contrôle total en l'air
##   pendant la poussée. Plongée : Accroupi en l'air, vers le viseur ; dégâts de zone.
## - Propulseurs (Kit de prospecteur) : maintenir Saut en l'air, petite poussée.
## - Esquive (Furet) : charges d'énergie ; double saut (triple au niveau 4) ; Saut +
##   gauche / droite / arrière au sol = esquive. Glissade plus longue.
## - Super saut (Bastion) : maintenir Saut au sol pour charger, relâcher. Coup de poing
##   chargé : maintenir V puis relâcher (ruée + coup qui repousse).
## - Glissade (tous) : Accroupi pendant un sprint ; Saut pendant la glissade = élan.

const DODGE_ACTIVATION_HOLD := 0.2   ## jetpack : Saut maintenu avant la poussée (s)
const SUPER_JUMP_TAP := 0.15         ## super saut : en dessous, c'est un saut normal (s)
const PUNCH_DASH_TIME := 0.25        ## durée de la ruée du coup de poing (s)
const PUNCH_HIT_DELAY := 0.2         ## le serveur frappe un peu après la demande (ruée)

var player: Player
var kit: KitController

# --- Client propriétaire ---
var fuel: float = 0.0
var charges: float = 0.0
var _fuel_pause: float = 0.0
var _jump_hold: float = 0.0
var _jet_active: bool = false
var _air_jumps_used: int = 0
var _diving: bool = false
var _dive_cd: float = 0.0
var _super_hold: float = 0.0
var _super_cd: float = 0.0
var _punch_hold: float = 0.0
var _punch_cd: float = 0.0
var _dash_left: float = 0.0
var _dash_velocity := Vector3.ZERO
var _slide_left: float = 0.0
var _slide_dir := Vector3.ZERO
var _slide_speed: float = 0.0
var _slide_cd: float = 0.0
var _jump_used: bool = false        ## Saut déjà utilisé ce tour (glissade, esquive…)
var _last_kit_id: String = "?"

# --- Serveur ---
var _srv_dive_ready_ms: int = 0
var _srv_punch_ready_ms: int = 0


func _ready() -> void:
	player = get_parent() as Player
	kit = player.get_node("Kit") as KitController


func mobility() -> int:
	var data := kit.get_kit()
	return data.mobility_type if data else KitData.MobilityType.NONE


# =========================================================================
# Client propriétaire : appelé par Player._physics_process
# =========================================================================

## Avant le déplacement : recharges, saut et capacités. Peut changer player.velocity.
func pre_physics(delta: float, input_dir: Vector2) -> void:
	if kit.kit_id != _last_kit_id:
		_reset_for_kit()
	var on_floor := player.is_on_floor()
	_jump_used = false
	_dive_cd = maxf(_dive_cd - delta, 0.0)
	_super_cd = maxf(_super_cd - delta, 0.0)
	_punch_cd = maxf(_punch_cd - delta, 0.0)
	_slide_cd = maxf(_slide_cd - delta, 0.0)
	_dash_left = maxf(_dash_left - delta, 0.0)
	if on_floor:
		_air_jumps_used = 0
	_process_slide(delta, on_floor, input_dir)
	match mobility():
		KitData.MobilityType.JETPACK:
			_process_jet(delta, on_floor, "jetpack", true)
			_process_dive(on_floor)
		KitData.MobilityType.JETBOOSTERS:
			_process_jet(delta, on_floor, "jetboosters", false)
		KitData.MobilityType.DASH:
			_process_dash(delta, on_floor, input_dir)
		KitData.MobilityType.SUPER_JUMP:
			_process_super_jump(delta, on_floor)
			_process_punch(delta)
		_:
			_basic_jump(on_floor)


## Après move_and_slide : fin de plongée à l'atterrissage.
func post_physics() -> void:
	if _diving and player.is_on_floor():
		_diving = false
		_dive_cd = kit.move_param("dive_attack", "cooldown_s", 8.0)
		_fuel_pause = kit.move_param("dive_attack", "pauses_fuel_regen_s", 1.5)
		request_dive_impact.rpc_id(1, player.global_position)


## La vitesse horizontale est imposée (glissade, esquive, plongée, ruée) ?
func overrides_horizontal() -> bool:
	return _slide_left > 0.0 or _dash_left > 0.0 or _diving


func is_sliding() -> bool:
	return _slide_left > 0.0


## Part de contrôle en l'air (le jetpack donne un contrôle total pendant la poussée).
func air_control() -> float:
	if _jet_active:
		return kit.move_param("jetpack", "air_control", Config.AIR_CONTROL)
	return Config.AIR_CONTROL


## Vitesse horizontale imposée quand overrides_horizontal() est vrai.
func forced_horizontal() -> Vector3:
	if _diving:
		return Vector3(player.velocity.x, 0, player.velocity.z)
	if _dash_left > 0.0:
		return _dash_velocity
	# Glissade : ralentit jusqu'à la vitesse de marche.
	var t := _slide_left / maxf(_slide_duration(), 0.01)
	return _slide_dir * lerpf(kit.move_speed(), _slide_speed, t)


func _reset_for_kit() -> void:
	_last_kit_id = kit.kit_id
	fuel = _fuel_max()
	charges = _charges_max()
	_diving = false
	_dash_left = 0.0


func _basic_jump(on_floor: bool) -> void:
	if not _jump_used and Input.is_action_just_pressed("jump") and on_floor and not player.is_crouching:
		player.velocity.y = Config.JUMP_VELOCITY
		_jump_used = true


# --- Glissade (tous les kits ; celle du Furet est plus longue) ---

func _slide_duration() -> float:
	var base := kit.move_param("slide", "slide_duration_s", Config.SLIDE_DURATION)
	return base


func _process_slide(delta: float, on_floor: bool, input_dir: Vector2) -> void:
	if _slide_left > 0.0:
		_slide_left = maxf(_slide_left - delta, 0.0)
		if Input.is_action_just_pressed("jump") and on_floor:
			# Saut glissé : élan vers l'avant.
			var boost := kit.move_param("slide", "slide_jump_boost_mps", Config.SLIDE_JUMP_BOOST)
			player.velocity.y = Config.JUMP_VELOCITY
			_dash_velocity = forced_horizontal() + _slide_dir * boost
			_slide_left = 0.0
			player.velocity.x = _dash_velocity.x
			player.velocity.z = _dash_velocity.z
			_jump_used = true
		elif not on_floor:
			_slide_left = 0.0
		return
	var sprinting := Input.is_action_pressed("sprint") and input_dir.y < 0.0
	if on_floor and sprinting and Input.is_action_just_pressed("crouch") and _slide_cd <= 0.0:
		_slide_dir = (player.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		_slide_speed = kit.move_param("slide", "slide_speed_mps", Config.SLIDE_SPEED)
		_slide_left = _slide_duration()
		_slide_cd = Config.SLIDE_COOLDOWN


# --- Jetpack (Martinet) et propulseurs (Kit de prospecteur) ---

func _fuel_max() -> float:
	match mobility():
		KitData.MobilityType.JETPACK:
			return kit.move_param("jetpack", "fuel_max", 100.0)
		KitData.MobilityType.JETBOOSTERS:
			return kit.move_param("jetboosters", "fuel_max", 50.0)
	return 0.0


func _process_jet(delta: float, on_floor: bool, block: String, from_ground: bool) -> void:
	_basic_jump(on_floor)
	_jump_hold = _jump_hold + delta if Input.is_action_pressed("jump") else 0.0
	var can_thrust := from_ground or not on_floor
	_jet_active = can_thrust and _jump_hold >= DODGE_ACTIVATION_HOLD and fuel > 0.0 and not _diving
	if _jet_active:
		var thrust := kit.move_param(block, "thrust_acceleration_mps2", 12.0) * (1.0 + kit.get_effect("thrust_mult"))
		var max_up := kit.move_param(block, "max_vertical_speed_mps", 3.0)
		player.velocity.y = minf(player.velocity.y + thrust * delta, max_up)
		fuel = maxf(fuel - kit.move_param(block, "fuel_consumption_per_s", 50.0) * delta, 0.0)
		_fuel_pause = kit.move_param(block, "fuel_regen_delay_s", 1.0)
	else:
		_fuel_pause = maxf(_fuel_pause - delta, 0.0)
		if _fuel_pause <= 0.0:
			var regen := kit.move_param(block, "fuel_regen_per_s", 20.0) * (1.0 + kit.get_effect("fuel_regen_mult"))
			fuel = minf(fuel + regen * delta, _fuel_max())


## Plongée : Accroupi en l'air, vers le viseur (toujours un peu vers le bas).
func _process_dive(on_floor: bool) -> void:
	if on_floor or _diving or _dive_cd > 0.0 or not Input.is_action_just_pressed("crouch"):
		return
	var dir := -player.camera.global_basis.z
	dir.y = minf(dir.y, -0.5)
	_diving = true
	player.velocity = dir.normalized() * kit.move_param("dive_attack", "dive_speed_mps", 25.0)


# --- Esquive, double saut, charges (Furet) ---

func _charges_max() -> float:
	if mobility() != KitData.MobilityType.DASH:
		return 0.0
	return kit.move_param("energy_charges", "max", 4.0) + kit.get_effect("energy_charges_add")


func _process_dash(delta: float, on_floor: bool, input_dir: Vector2) -> void:
	charges = minf(charges + delta / maxf(kit.move_param("energy_charges", "regen_s_per_charge", 3.0), 0.1), _charges_max())
	if _jump_used or not Input.is_action_just_pressed("jump"):
		return
	if on_floor:
		var sideways := absf(input_dir.x) > 0.3 or input_dir.y > 0.3
		if sideways and charges >= 1.0:
			# Esquive : courte ruée à gauche / droite / en arrière.
			var dir := (player.global_basis * Vector3(input_dir.x, 0, maxf(input_dir.y, 0.0))).normalized()
			var duration := kit.move_param("dodge", "duration_s", 0.2)
			_dash_velocity = dir * kit.move_param("dodge", "distance_m", 4.0) / maxf(duration, 0.01)
			_dash_left = duration
			charges -= 1.0
		else:
			_basic_jump(on_floor)
		_jump_used = true
		return
	var max_air := int(kit.move_param("double_jump", "max_air_jumps", 1.0) + kit.get_effect("air_jumps_add"))
	if _air_jumps_used < max_air and charges >= 1.0:
		player.velocity.y = kit.move_param("double_jump", "jump_velocity_mps", 6.0)
		_air_jumps_used += 1
		charges -= 1.0
		_jump_used = true


# --- Super saut et coup de poing chargé (Bastion) ---

func _process_super_jump(delta: float, on_floor: bool) -> void:
	if not on_floor or _super_cd > 0.0:
		_super_hold = 0.0
		_basic_jump(on_floor)
		return
	var speed := 1.0 + kit.get_effect("charge_speed_mult")
	if Input.is_action_pressed("jump"):
		_super_hold += delta * speed
	elif Input.is_action_just_released("jump") and not _jump_used:
		if _super_hold < SUPER_JUMP_TAP:
			player.velocity.y = Config.JUMP_VELOCITY
		else:
			var t := clampf(_super_hold / kit.move_param("super_jump", "charge_time_max_s", 1.0), 0.0, 1.0)
			var v := lerpf(kit.move_param("super_jump", "jump_velocity_min_mps", 5.0),
					kit.move_param("super_jump", "jump_velocity_max_mps", 12.0), t)
			player.velocity.y = v * (1.0 + kit.get_effect("super_jump_mult"))
			_super_cd = kit.move_param("super_jump", "cooldown_s", 6.0)
		_super_hold = 0.0
		_jump_used = true


func _process_punch(delta: float) -> void:
	if Input.is_action_pressed("melee") and _punch_cd <= 0.0:
		_punch_hold += delta
	elif Input.is_action_just_released("melee") and _punch_hold > 0.0:
		_punch_hold = 0.0
		var dir := -player.global_basis.z
		dir.y = 0.0
		dir = dir.normalized()
		var dist := kit.move_param("charge_punch", "dash_distance_m", 6.0)
		_dash_velocity = dir * dist / PUNCH_DASH_TIME * (1.0 + kit.get_effect("charge_speed_mult"))
		_dash_left = PUNCH_DASH_TIME
		_punch_cd = kit.move_param("charge_punch", "cooldown_s", 8.0)
		request_punch.rpc_id(1, dir)


## Texte du HUD : ressource et recharges de la capacité du kit.
func status_text() -> String:
	match mobility():
		KitData.MobilityType.JETPACK:
			var dive := "prête (Accroupi en l'air)" if _dive_cd <= 0.0 else "%d s" % ceili(_dive_cd)
			return "Jetpack %d %%  —  Plongée %s" % [roundi(100.0 * fuel / maxf(_fuel_max(), 1.0)), dive]
		KitData.MobilityType.JETBOOSTERS:
			return "Propulseurs %d %%" % roundi(100.0 * fuel / maxf(_fuel_max(), 1.0))
		KitData.MobilityType.DASH:
			var full := int(charges)
			return "Énergie %s" % ("■".repeat(full) + "□".repeat(maxi(int(_charges_max()) - full, 0)))
		KitData.MobilityType.SUPER_JUMP:
			var jump := "prêt (maintenir Saut)" if _super_cd <= 0.0 else "%d s" % ceili(_super_cd)
			var punch := "prêt (V)" if _punch_cd <= 0.0 else "%d s" % ceili(_punch_cd)
			return "Super saut %s  —  Coup de poing %s" % [jump, punch]
	return ""


# =========================================================================
# Serveur : dégâts de la plongée et du coup de poing
# =========================================================================

func _sender_ok() -> bool:
	return multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.get_peer_id() \
			and not player.health.is_dead and not player.health.is_downed and not player.is_evacuated


## Atterrissage d'une plongée : dégâts de zone autour du point (pas sur soi).
@rpc("any_peer", "call_local", "reliable")
func request_dive_impact(pos: Vector3) -> void:
	if not _sender_ok() or mobility() != KitData.MobilityType.JETPACK:
		return
	var now := Time.get_ticks_msec()
	if now < _srv_dive_ready_ms or not pos.is_finite() or pos.distance_to(player.global_position) > 6.0:
		return
	# 10 % de marge sur la recharge (latence).
	_srv_dive_ready_ms = now + int(kit.move_param("dive_attack", "cooldown_s", 8.0) * 900.0)
	var radius := kit.move_param("dive_attack", "radius_m", 3.0)
	var damage := kit.move_param("dive_attack", "damage", 150.0) + kit.get_effect("dive_damage_add")
	for node in get_tree().get_nodes_in_group("damageable"):
		var target := node as Node3D
		if target == null or target == player or not target.can_be_hit():
			continue
		if target.global_position.distance_to(pos) <= radius:
			target.server_receive_hit(_vs_creature(target, damage), player.get_peer_id())
	player.weapon._show_explosion.rpc(pos, radius)


## Coup de poing chargé : frappe la cible la plus proche devant soi, après la ruée.
@rpc("any_peer", "call_local", "reliable")
func request_punch(dir: Vector3) -> void:
	if not _sender_ok() or mobility() != KitData.MobilityType.SUPER_JUMP or not dir.is_finite():
		return
	var now := Time.get_ticks_msec()
	if now < _srv_punch_ready_ms:
		return
	_srv_punch_ready_ms = now + int(kit.move_param("charge_punch", "cooldown_s", 8.0) * 900.0)
	await get_tree().create_timer(PUNCH_HIT_DELAY).timeout
	if not is_inside_tree() or player.health.is_dead:
		return
	dir = Vector3(dir.x, 0, dir.z).normalized()
	var best: Node3D = null
	var best_dist := Config.MELEE_RANGE
	for node in get_tree().get_nodes_in_group("damageable"):
		var target := node as Node3D
		if target == null or target == player or not target.can_be_hit():
			continue
		var to := target.global_position - player.global_position
		to.y = 0.0
		if to.length() <= best_dist and to.normalized().dot(dir) > 0.3:
			best = target
			best_dist = to.length()
	if best == null:
		return
	var mult := 1.0 + kit.get_effect("punch_damage_mult")
	var knock := dir * kit.move_param("charge_punch", "knockback_mps", 8.0)
	if best is Player:
		best.server_receive_hit(kit.move_param("charge_punch", "damage_vs_players", 160.0) * mult, player.get_peer_id())
		(best as Player).apply_knockback.rpc_id((best as Player).get_peer_id(), knock)
	else:
		best.server_receive_hit(_vs_creature(best, kit.move_param("charge_punch", "damage_vs_monsters", 200.0) * mult), player.get_peer_id())
		if best is CharacterBody3D:
			best.global_position += knock * 0.15  # petit recul du monstre


## Bonus de dégâts du kit contre les créatures.
func _vs_creature(target: Node, damage: float) -> float:
	return damage * (1.0 + kit.get_effect("creature_damage")) if target is Monster else damage
