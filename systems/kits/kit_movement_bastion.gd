extends RefCounted
## Super saut et coup de poing chargé (Bastion), côté client propriétaire.

var super_hold: float = 0.0
var super_cd: float = 0.0
var punch_hold: float = 0.0
var punch_cd: float = 0.0
var _m: KitMovement


func _init(movement: KitMovement) -> void:
	_m = movement


func process_super_jump(delta: float, on_floor: bool) -> void:
	var kit := _m.kit
	var player := _m.player
	if not on_floor or super_cd > 0.0:
		super_hold = 0.0
		_m._basic_jump(on_floor)
		return
	var speed := 1.0 + kit.get_effect("charge_speed_mult")
	if Input.is_action_pressed("jump"):
		super_hold += delta * speed
	elif Input.is_action_just_released("jump") and not _m._jump_used:
		if super_hold < KitMovement.SUPER_JUMP_TAP:
			player.velocity.y = Config.combat.jump_velocity
		else:
			var t := clampf(super_hold / kit.move_param("super_jump", "charge_time_max_s"), 0.0, 1.0)
			var v := lerpf(kit.move_param("super_jump", "jump_velocity_min_mps"),
					kit.move_param("super_jump", "jump_velocity_max_mps"), t)
			player.velocity.y = v * (1.0 + kit.get_effect("super_jump_mult"))
			super_cd = kit.move_param("super_jump", "cooldown_s")
		super_hold = 0.0
		_m._jump_used = true


func process_punch(delta: float) -> void:
	var kit := _m.kit
	if Input.is_action_pressed("melee") and punch_cd <= 0.0:
		punch_hold += delta
	elif Input.is_action_just_released("melee") and punch_hold > 0.0:
		punch_hold = 0.0
		var dir := -_m.player.global_basis.z
		dir.y = 0.0
		dir = dir.normalized()
		var dist := kit.move_param("charge_punch", "dash_distance_m")
		_m._dash_velocity = dir * dist / KitMovement.PUNCH_DASH_TIME * (1.0 + kit.get_effect("charge_speed_mult"))
		_m._dash_left = KitMovement.PUNCH_DASH_TIME
		punch_cd = maxf(kit.move_param("charge_punch", "cooldown_s") + kit.get_effect("punch_cooldown_add"), 1.0)
		_m.request_punch.rpc_id(1, dir)
