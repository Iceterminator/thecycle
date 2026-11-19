extends RefCounted
## Déroulement serveur du cristal : lancement, vagues de monstres, échec, extraction.
## L'état (state, drill_health…) reste sur le Crystal (synchronisé) ; ici les monstres
## vivants et le compte à rebours de la prochaine vague.

var alive: Array[Monster] = []
var wave_timer: float = -1.0
var _c: Crystal


func _init(crystal: Crystal) -> void:
	_c = crystal


func register_wave_monster(monster: Monster) -> void:
	alive.append(monster)
	_c.monsters_left = alive.size()


func on_wave_monster_died(monster: Monster) -> void:
	alive.erase(monster)
	_c.monsters_left = alive.size()
	if _c.state != Crystal.State.DEFENSE or not alive.is_empty() or wave_timer >= 0.0:
		return
	if _c.wave_index < _c.data.waves.size():
		schedule_wave()
	else:
		_c.state = Crystal.State.EXTRACT
		print("[Quête] %s : vagues terminées, extraction possible" % _c.name)


func start_defense(player: Player) -> void:
	_c.state = Crystal.State.DEFENSE
	_c.drill_health = _c.data.drill_health
	_c.wave_index = 0
	print("[Quête] %s (%s) lancé par %d" % [_c.name, _c.data.difficulty_name, player.get_peer_id()])
	Events.quest_started.emit(StringName(_c.name), player.get_peer_id())
	schedule_wave()


func schedule_wave() -> void:
	wave_timer = Config.match_rules.crystal_wave_delay
	_c.next_wave_in = Config.match_rules.crystal_wave_delay


## Appelé chaque frame physique par le Crystal.
func physics_step(delta: float) -> void:
	if _c.state != Crystal.State.DEFENSE or wave_timer < 0.0:
		return
	wave_timer -= delta
	if wave_timer <= 0.0:
		wave_timer = -1.0
		_spawn_wave()


func _spawn_wave() -> void:
	var data := _c.data
	var wave: CampData = data.waves[_c.wave_index]
	_c.wave_index += 1
	_c.next_wave_in = 0.0
	var count := 0
	for monster_data in wave.roll():
		var angle := randf() * TAU
		var dist := randf_range(Config.match_rules.crystal_wave_spawn_min, Config.match_rules.crystal_wave_spawn_max)
		var pos := _c.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		Events.wave_spawn_requested.emit(_c, monster_data, pos, data.monster_health_mult, data.monster_damage_mult)
		count += 1
	print("[Quête] %s : vague %d/%d (%d monstres)" % [_c.name, _c.wave_index, data.waves.size(), count])
	_c._update_label()


func fail() -> void:
	_c.state = Crystal.State.FAILED
	wave_timer = -1.0
	print("[Quête] %s : foreuse détruite" % _c.name)
	Events.quest_failed.emit(StringName(_c.name))
	for monster in alive:
		if is_instance_valid(monster):
			monster.queue_free()
	alive.clear()
	_c.monsters_left = 0
	await _c.get_tree().create_timer(Config.match_rules.crystal_reset_delay).timeout
	if _c.is_inside_tree() and _c.state == Crystal.State.FAILED:
		_c.state = Crystal.State.IDLE


func complete(player: Player) -> void:
	var data := _c.data
	_c.state = Crystal.State.DONE
	player.score.add_objective_points(data.track, data.objective_points)
	print("[Quête] %s extrait par %d : +%d points" % [_c.name, player.get_peer_id(), data.objective_points])
	Events.quest_completed.emit(StringName(_c.name), player.get_peer_id(), data.objective_points)
	await _c.get_tree().create_timer(Config.match_rules.crystal_respawn_delay).timeout
	if _c.is_inside_tree() and _c.state == Crystal.State.DONE:
		_c.state = Crystal.State.IDLE
