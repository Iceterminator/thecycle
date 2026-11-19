extends RefCounted
## Esquive, double saut et charges d'énergie (Furet).

var air_jumps_used: int = 0
var _m: KitMovement


func _init(movement: KitMovement) -> void:
	_m = movement


func charges_max() -> float:
	if _m.mobility() != KitData.MobilityType.DASH:
		return 0.0
	return _m.kit.move_param("energy_charges", "max") + _m.kit.get_effect("energy_charges_add")


func process(delta: float, on_floor: bool, input_dir: Vector2) -> void:
	var kit := _m.kit
	var player := _m.player
	_m.charges = minf(_m.charges + delta / maxf(kit.move_param("energy_charges", "regen_s_per_charge"), 0.1), charges_max())
	if _m._jump_used or not Input.is_action_just_pressed("jump"):
		return
	if on_floor:
		var sideways := absf(input_dir.x) > 0.3 or input_dir.y > 0.3
		if sideways and _m.charges >= 1.0:
			# Esquive : courte ruée à gauche / droite / en arrière.
			var dir := (player.global_basis * Vector3(input_dir.x, 0, maxf(input_dir.y, 0.0))).normalized()
			var duration := kit.move_param("dodge", "duration_s")
			_m._dash_velocity = dir * kit.move_param("dodge", "distance_m") / maxf(duration, 0.01)
			_m._dash_left = duration
			_m.charges -= 1.0
			# Mod « esquive blindée » : le serveur réduit les dégâts pendant l'esquive.
			if kit.get_effect("dodge_damage_reduction") > 0.0:
				_m.request_dodge_guard.rpc_id(1, duration)
		else:
			_m._basic_jump(on_floor)
		_m._jump_used = true
		return
	var max_air := int(kit.move_param("double_jump", "max_air_jumps") + kit.get_effect("air_jumps_add"))
	if air_jumps_used < max_air and _m.charges >= 1.0:
		player.velocity.y = kit.move_param("double_jump", "jump_velocity_mps")
		air_jumps_used += 1
		_m.charges -= 1.0
		_m._jump_used = true
