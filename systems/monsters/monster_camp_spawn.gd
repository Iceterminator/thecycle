extends RefCounted
## Apparition des monstres d'un camp (serveur), utilisée par MonsterManager. Par tranches : un
## monstre à la fois, avec une pause à l'image suivante quand le budget de temps
## (Config.MAP_BUILD_BUDGET_MS) est écoulé, pour ne jamais figer le jeu (~120 monstres au début de partie).

const MapThread := preload("res://systems/map/map_thread.gd")
const MonsterGround := preload("res://systems/monsters/monster_ground.gd")

var _m: MonsterManager
var _tranche_debut: int = 0  ## début de la tranche de temps de l'image courante


func _init(manager: MonsterManager) -> void:
	_m = manager


## Coroutine : peuple chaque camp à la suite ; s'arrête si les monstres sont retirés entre-temps.
func spawn_all(camps: Node3D) -> void:
	var generation := _m._generation
	_tranche_debut = Time.get_ticks_usec()
	for node in camps.get_children():
		if node is MonsterCamp:
			await spawn_camp(node as MonsterCamp)
			if generation != _m._generation:
				return


## Coroutine : crée les monstres tirés par le camp (s'arrête si le camp ou la partie disparaît).
func spawn_camp(camp: MonsterCamp) -> void:
	var count := 0
	var generation := _m._generation
	for monster_data in camp.camp_data.roll():
		if generation != _m._generation or not is_instance_valid(camp):
			return
		var angle := randf() * TAU
		var dist := sqrt(randf()) * camp.radius
		var pos := camp.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var monster := _m.spawner.spawn({
			"uid": _m._new_uid(),
			"data": monster_data.resource_path,
			"pos": MonsterGround.point(_m.spawner.get_parent() as Node3D, pos),
			"rot": randf() * TAU,
			"hp": _m._level_mult(Config.match_rules.monster_level_health_mult),
			"lvl": _m._level,
		}) as Monster
		_m._apply_level(monster, 1.0)
		monster.camp = camp
		monster.players_root = _m.players_root
		camp.alive.append(monster)
		count += 1
		_tranche_debut = await MapThread.ceder(_m.get_tree(), _tranche_debut)
	print("[Monstres] Camp %s (niveau %d) : %d monstres" % [camp.name, camp.camp_data.level, count])
