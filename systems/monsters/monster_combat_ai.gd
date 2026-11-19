extends RefCounted
## IA de combat d'un monstre (serveur) : poursuite, préparation et coup (mêlée ou tir).

var _m: Monster


func _init(monster: Monster) -> void:
	_m = monster


func do_chase(can_attack: bool = true) -> void:
	var motion := _m._motion
	if not motion.valid_target():
		_m._ai.start_return()
		return
	var data := _m.data
	var target_pos := _m._target.global_position
	var dist := motion.target_dist()
	# Pas d'abandon ni de laisse quand on attaque son objectif.
	var on_objective := _m._target == _m.objective
	if not on_objective and (dist > data.lose_radius or (_m.objective == null and motion.flat_dist(_m.home) > data.leash_radius)):
		_m._ai.start_return()
		return
	if data.ranged:
		_chase_ranged(target_pos, dist, can_attack)
		return
	if can_attack and dist <= data.attack_range:
		_m.state = Monster.State.WINDUP
		_m._state_left = data.attack_windup
	if dist <= data.attack_range * Monster.CONTACT_RATIO:
		# Déjà au contact : on ne pousse pas le joueur, on le regarde.
		motion.halt()
		motion.face(target_pos)
		return
	motion.move_toward_with_path(target_pos, data.run_speed * _m._ai.aggro_mult())


## Monstre à distance : à portée avec ligne de vue, il s'arrête (ou recule si on est trop
## près) et prépare un tir ; sinon il se rapproche.
func _chase_ranged(target_pos: Vector3, dist: float, can_attack: bool) -> void:
	var motion := _m._motion
	var data := _m.data
	if dist <= data.attack_range and motion.has_line_of_sight(_m._target):
		if dist < data.min_range and _m._target != _m.objective:
			motion.back_off()
		else:
			motion.halt()
			motion.face(target_pos)
		if can_attack:
			_m.state = Monster.State.WINDUP
			_m._state_left = data.attack_windup
		return
	motion.move_toward_with_path(target_pos, data.run_speed * _m._ai.aggro_mult())


## Préparation du coup : le monstre continue d'avancer (plus lentement) vers la cible.
## Le coup part à la fin s'il est encore à portée ; s'il rate, la pause est courte.
## Monstre à distance : il reste sur place et vise, puis tire s'il voit toujours la cible.
func do_windup() -> void:
	var motion := _m._motion
	if not motion.valid_target():
		_m._ai.start_return()
		return
	var data := _m.data
	var target_pos := _m._target.global_position
	if data.ranged:
		motion.halt()
		motion.face(target_pos)
		if _m._state_left > 0.0:
			return
		if motion.target_dist() <= data.attack_range * Monster.HIT_RANGE_RATIO and motion.has_line_of_sight(_m._target):
			_m._projectiles.fire()
			_m._state_left = data.attack_cooldown
		else:
			_m._state_left = Monster.MISS_RECOVERY
		_m._pause_left = 0.0
		_m.state = Monster.State.RECOVER
		return
	if motion.target_dist() > data.attack_range * Monster.CONTACT_RATIO:
		motion.move_to(target_pos, data.run_speed * Monster.LUNGE_SPEED_RATIO)
	else:
		motion.halt()
	motion.face(target_pos)
	if _m._state_left > 0.0:
		return
	if motion.target_dist() <= data.attack_range * Monster.HIT_RANGE_RATIO:
		_m._target.server_receive_hit(data.attack_damage * _m.damage_mult, Config.MONSTER_KILLER_ID)
		_m._state_left = data.attack_cooldown
		_m._pause_left = data.post_hit_pause
	else:
		_m._state_left = Monster.MISS_RECOVERY
	_m.state = Monster.State.RECOVER
