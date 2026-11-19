extends RefCounted
## IA générale d'un monstre (serveur) : machine à états, patrouille, retour au camp,
## recherche de joueurs. Poursuite et attaque : monster_combat_ai.gd.

var idle_left: float = 0.0
var _m: Monster
var _has_patrol_point: bool = false
var _scan_left: float = 0.0


func _init(monster: Monster) -> void:
	_m = monster


## Un pas d'IA : décrémente les minuteurs puis exécute l'état courant.
func step(delta: float) -> void:
	var combat := _m._combat_ai
	_m._state_left -= delta
	_scan_left -= delta
	_m._repath_left -= delta
	match _m.state:
		Monster.State.PATROL:
			_do_patrol(delta)
		Monster.State.CHASE:
			combat.do_chase()
		Monster.State.WINDUP:
			combat.do_windup()
		Monster.State.RECOVER:
			if _m._pause_left > 0.0:
				# Juste après un coup qui a touché : petite pause en reculant.
				_m._pause_left -= delta
				_m._motion.back_off()
			else:
				# Puis il reprend la poursuite, sans frapper avant la fin de la recharge.
				combat.do_chase(false)
			if _m.state == Monster.State.RECOVER and _m._state_left <= 0.0:
				_m.state = Monster.State.CHASE
		Monster.State.RETURN:
			_do_return()


## Monstres plus agressifs dans la tempête.
func aggro_mult() -> float:
	return Config.match_rules.storm_monster_mult if StormManager.is_in_storm(_m.global_position) else 1.0


func _do_patrol(delta: float) -> void:
	var motion := _m._motion
	if _scan_left <= 0.0:
		_scan_left = Monster.SCAN_INTERVAL
		var player := _find_player()
		if player:
			_m.aggro(player, true)
			return
	if idle_left > 0.0:
		idle_left -= delta
		motion.halt()
		return
	if not _has_patrol_point:
		var angle := randf() * TAU
		var dist := sqrt(randf()) * (_m.camp.radius if _m.camp else 6.0)
		_m._agent.target_position = _m.home + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		_has_patrol_point = true
		return  # laisse une frame au chemin pour se calculer
	# get_next_path_position() calcule le chemin : à appeler AVANT de tester s'il est fini.
	var next := _m._agent.get_next_path_position()
	if _m._agent.is_navigation_finished() or _m._agent.get_current_navigation_path().is_empty():
		_has_patrol_point = false
		idle_left = randf_range(1.0, 3.0)
		motion.halt()
		return
	motion.move_to(next, _m.data.walk_speed)


func _do_return() -> void:
	var motion := _m._motion
	if motion.flat_dist(_m.home) < 2.0:
		_m.health = _m.max_health  # de retour au camp : PV au max (pas de « kiting » gratuit)
		_m.state = Monster.State.PATROL
		_has_patrol_point = false
		idle_left = randf_range(0.5, 1.5)
		motion.halt()
		return
	motion.move_toward_with_path(_m.home, _m.data.walk_speed * 1.6)


## Monstre de vague : fonce sur son objectif dès son apparition.
func aggro_objective() -> void:
	_m._had_objective = true
	if is_instance_valid(_m.objective):
		_m._target = _m.objective
		_m.state = Monster.State.CHASE
		_m._repath_left = 0.0


## Prend `player` pour cible. `alert_camp` : prévient le reste de la meute.
func aggro(player: Player, alert_camp: bool) -> void:
	if _m.health <= 0.0:
		return
	_m._target = player
	if _m.state == Monster.State.PATROL or _m.state == Monster.State.RETURN:
		_m.state = Monster.State.CHASE
		_m._repath_left = 0.0
	if alert_camp and _m.camp:
		_m.camp.alert(player, _m)


func start_return() -> void:
	# Monstre de vague : il retourne attaquer son objectif plutôt que rentrer.
	if is_instance_valid(_m.objective) and _m.objective.can_be_hit():
		_m._target = _m.objective
		_m.state = Monster.State.CHASE
		_m._repath_left = 0.0
		return
	if _m._had_objective:
		# Objectif détruit / joueur ciblé mort : le monstre de vague n'a plus de raison d'être.
		_m.queue_free()
		return
	_m._target = null
	_m.state = Monster.State.RETURN
	_m._repath_left = 0.0


## Joueur vivant le plus proche dans le rayon de détection, avec ligne de vue.
func _find_player() -> Player:
	if _m.players_root == null:
		return null
	var best: Player = null
	var best_dist := _m.data.detection_radius * aggro_mult()
	for node in _m.players_root.get_children():
		var player := node as Player
		if player == null or not player.can_be_hit():
			continue
		# Joueur camouflé : invisible pour les monstres, sauf tout près.
		var cloaked := player.buffs != null and player.buffs.get_cloak(0.0) >= Config.combat.cloak_monster_ignore
		if cloaked and _m.global_position.distance_to(player.global_position) > 4.0:
			continue
		var dist := _m.global_position.distance_to(player.global_position)
		if dist <= best_dist and _m._motion.has_line_of_sight(player):
			best = player
			best_dist = dist
	return best
