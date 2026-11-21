extends RefCounted
## Jetpack (Martinet), plongée et propulseurs (Kit de prospecteur).
## Le carburant (fuel) reste sur KitMovement (lu par le HUD).

## Composante verticale minimale (vers le bas) de la direction d'une plongée.
const DIVE_MIN_DOWN := 0.5

var hold: float = 0.0
var active: bool = false
var diving: bool = false
var dive_cd: float = 0.0
var fuel_pause: float = 0.0
var _m: KitMovement


func _init(movement: KitMovement) -> void:
	_m = movement


func fuel_max() -> float:
	match _m.mobility():
		KitData.MobilityType.JETPACK:
			return _m.kit.move_param("jetpack", "fuel_max")
		KitData.MobilityType.JETBOOSTERS:
			return _m.kit.move_param("jetboosters", "fuel_max")
	return 0.0


func process_jet(delta: float, on_floor: bool, block: String, from_ground: bool) -> void:
	var kit := _m.kit
	var player := _m.player
	_m._basic_jump(on_floor)
	hold = hold + delta if Input.is_action_pressed("jump") else 0.0
	var can_thrust := from_ground or not on_floor
	active = can_thrust and hold >= KitMovement.DODGE_ACTIVATION_HOLD and _m.fuel > 0.0 and not diving
	var hovering := not active and not diving and not on_floor and _hover(delta, block)
	if active:
		var thrust := kit.move_param(block, "thrust_acceleration_mps2") * (1.0 + kit.get_effect("thrust_mult"))
		var max_up := kit.move_param(block, "max_vertical_speed_mps")
		player.velocity.y = minf(player.velocity.y + thrust * delta, max_up)
		var consumption := kit.move_param(block, "fuel_consumption_per_s") * (1.0 + kit.get_effect("fuel_consumption_mult"))
		_m.fuel = maxf(_m.fuel - consumption * delta, 0.0)
		fuel_pause = kit.move_param(block, "fuel_regen_delay_s")
	elif not hovering:
		fuel_pause = maxf(fuel_pause - delta, 0.0)
		if fuel_pause <= 0.0:
			var regen := kit.move_param(block, "fuel_regen_per_s") * (1.0 + kit.get_effect("fuel_regen_mult"))
			_m.fuel = minf(_m.fuel + regen * delta, fuel_max())


## Plongée : Accroupi en l'air, vers le viseur (toujours un peu vers le bas).
func process_dive(on_floor: bool) -> void:
	if on_floor or diving or dive_cd > 0.0 or not Input.is_action_just_pressed("crouch"):
		return
	var dir := -_m.player.camera.global_basis.z
	dir.y = minf(dir.y, -DIVE_MIN_DOWN * (1.0 + _m.kit.get_effect("dive_min_angle_mult")))  # mod « Angle de piqué »
	diving = true
	_m.player.velocity = dir.normalized() * _m.kit.move_param("dive_attack", "dive_speed_mps")


## Fin de plongée à l'atterrissage : recharge, pause du carburant, impact demandé au serveur.
func on_landed() -> void:
	diving = false
	dive_cd = _m.kit.move_param("dive_attack", "cooldown_s")
	fuel_pause = _m.kit.move_param("dive_attack", "pauses_fuel_regen_s")
	_m.request_dive_impact.rpc_id(1, _m.player.global_position)


## Mod « Vol stationnaire » : en l'air et en visée, descente très lente pour une part de la
## consommation de carburant. Renvoie true si le vol stationnaire est en cours.
func _hover(delta: float, block: String) -> bool:
	var kit := _m.kit
	if kit.get_effect("aim_hover") <= 0.0 or _m.fuel <= 0.0 or not _m.player.weapon.is_aiming:
		return false
	_m.player.velocity.y = maxf(_m.player.velocity.y, -kit.get_effect("hover_fall_mps"))
	var consumption := kit.move_param(block, "fuel_consumption_per_s") * (1.0 + kit.get_effect("fuel_consumption_mult"))
	_m.fuel = maxf(_m.fuel - consumption * kit.get_effect("hover_fuel_ratio") * delta, 0.0)
	fuel_pause = kit.move_param(block, "fuel_regen_delay_s")
	return true
