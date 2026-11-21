class_name MonsterManager
extends Node
## Crée les monstres via le MonsterSpawner (règle 3 : seul le serveur crée).
## - Sur tous les peers : fournit la spawn_function (recrée le monstre reçu).
## - Sur le serveur : génère le navmesh de la carte, peuple chaque MonsterCamp, et
##   repeuple un camp vidé après Config.match_rules.camp_respawn_delay (pour les tests).

const MONSTER_SCRIPT := preload("res://systems/monsters/monster.gd")
const MonsterNavmesh := preload("res://systems/monsters/monster_navmesh.gd")

@export var spawner: MultiplayerSpawner
@export var camps: Node3D
@export var players_root: Node3D
@export var nav_region: NavigationRegion3D
@export var map: Node3D  ## géométrie de la carte (CSG) servant au navmesh

var _next_uid: int = 0
## Incrémenté à chaque nouvelle partie : les repeuplements en attente sont annulés.
var _generation: int = 0
## Niveau des monstres (1 à 3, Events.monster_level_changed) : appliqué à ceux qui apparaissent.
var _level: int = 1
## Camp qui bloque la plateforme d'évac (créé à l'annonce de l'évac, jamais repeuplé).
var _pad_camp: MonsterCamp


func _ready() -> void:
	spawner.spawn_function = _spawn_node
	if not multiplayer.is_server():
		return
	Events.wave_spawn_requested.connect(_on_wave_spawn_requested)
	Events.match_reset_requested.connect(_on_match_reset)
	Events.evac_announced.connect(_spawn_evac_pad_camp)
	Events.monster_level_changed.connect(func(level: int) -> void: _level = clampi(level, 1, Config.match_rules.monster_level_health_mult.size()))
	Events.carte_chargee.connect(_setup)  # la carte n'existe qu'en partie (Niveaux)
	Events.carte_liberee.connect(_vider)
	for node in camps.get_children():
		if node is MonsterCamp:
			(node as MonsterCamp).cleared.connect(_on_camp_cleared)


func _setup() -> void:
	# Les CSG créent leurs collisions en différé : on attend avant de générer le navmesh.
	await get_tree().physics_frame
	await get_tree().physics_frame
	MonsterNavmesh.bake(nav_region, map)  # les camps sont peuplés par match_reset_requested


func _spawn_camp(camp: MonsterCamp) -> void:
	var count := 0
	for monster_data in camp.camp_data.roll():
		var angle := randf() * TAU
		var dist := sqrt(randf()) * camp.radius
		var pos := camp.global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		var monster := spawner.spawn({
			"uid": _new_uid(),
			"data": monster_data.resource_path,
			"pos": _ground(pos),
			"rot": randf() * TAU,
			"hp": _level_mult(Config.match_rules.monster_level_health_mult),
			"lvl": _level,
		}) as Monster
		_apply_level(monster, 1.0)
		monster.camp = camp
		monster.players_root = players_root
		camp.alive.append(monster)
		count += 1
	print("[Monstres] Camp %s (niveau %d) : %d monstres" % [camp.name, camp.camp_data.level, count])


## Monstre de vague (Events.wave_spawn_requested) : il attaque `objective`.
## L'objectif est prévenu via register_wave_monster(monster) pour suivre sa vague.
func _on_wave_spawn_requested(objective: Node3D, monster_data: MonsterData, position: Vector3,
		health_mult: float, damage_mult: float) -> void:
	var monster := spawner.spawn({
		"uid": _new_uid(),
		"data": monster_data.resource_path,
		"pos": _ground(position),
		"rot": randf() * TAU,
		"hp": health_mult * _level_mult(Config.match_rules.monster_level_health_mult),
		"lvl": _level,
	}) as Monster
	monster.players_root = players_root
	monster.objective = objective
	_apply_level(monster, damage_mult)
	monster.aggro_objective()
	if objective.has_method("register_wave_monster"):
		objective.register_wave_monster(monster)


func _on_camp_cleared(camp: MonsterCamp, _killer_id: int) -> void:
	var generation := _generation
	await get_tree().create_timer(Config.match_rules.camp_respawn_delay).timeout
	if is_instance_valid(camp) and generation == _generation:
		_spawn_camp(camp)


## Appelée sur tous les peers avec les mêmes données : recrée le même monstre.
func _spawn_node(data: Dictionary) -> Node:
	var monster: Monster = MONSTER_SCRIPT.new()
	monster.name = "Monster_%d" % data["uid"]
	monster.setup(load(data["data"]) as MonsterData, data.get("hp", 1.0), data.get("lvl", 1))
	monster.position = data["pos"]
	monster.rotation.y = data["rot"]
	if data.get("fige", false):  # salle de test : ni IA ni déplacement (le serveur seul les fait tourner)
		monster.ready.connect(monster.set_physics_process.bind(false))
	return monster


## Salle de test : un monstre figé au niveau donné (salle_test_stock.gd).
func server_spawn_fige(data_path: String, pos: Vector3, lvl: int) -> void:
	var mult: Array = Config.match_rules.monster_level_health_mult
	spawner.spawn({"uid": _new_uid(), "data": data_path, "pos": pos, "rot": PI, "hp": mult[clampi(lvl - 1, 0, mult.size() - 1)], "lvl": lvl, "fige": true})


func _ground(pos: Vector3) -> Vector3:
	var world := spawner.get_parent() as Node3D
	# Le tir part au-dessus du relief (qui peut être haut en ce point).
	var top := maxf(pos.y, MapTerrain.height_at(pos.x, pos.z)) + 3.0
	var query := PhysicsRayQueryParameters3D.create(Vector3(pos.x, top, pos.z), Vector3(pos.x, top - 25.0, pos.z), 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return (hit["position"] as Vector3) + Vector3.UP * 0.05
	# Collision du relief pas encore dans l'espace physique (camps peuplés juste après sa
	# construction) : relief calculé + marge, sinon le monstre naît sous le sol et tombe.
	return Vector3(pos.x, MapTerrain.height_at(pos.x, pos.z) + 0.3, pos.z)


func _new_uid() -> int:
	_next_uid += 1
	return _next_uid


## Nouvelle partie : tous les monstres disparaissent (le spawner les retire chez les
## clients), puis chaque camp est repeuplé.
## Retour au lobby : plus de carte, plus de monstres.
func _vider() -> void:
	_generation += 1
	if is_instance_valid(_pad_camp):
		_pad_camp.queue_free()
	_pad_camp = null
	for node in spawner.get_node(spawner.spawn_path).get_children():
		node.queue_free()
	for node in camps.get_children():
		if node is MonsterCamp:
			(node as MonsterCamp).alive.clear()


func _on_match_reset() -> void:
	_vider()
	for node in camps.get_children():
		if node is MonsterCamp:
			_spawn_camp(node as MonsterCamp)


func _level_mult(table: Array) -> float:
	return table[clampi(_level - 1, 0, table.size() - 1)]


## Serveur : dégâts et crédits selon le niveau actuel (les PV passent par la spawn_function).
func _apply_level(monster: Monster, damage_mult: float) -> void:
	monster.damage_mult = damage_mult * _level_mult(Config.match_rules.monster_level_damage_mult)
	monster.credits_mult = _level_mult(Config.match_rules.monster_level_credits_mult)


## Annonce de l'évac : des monstres occupent la plateforme. La navette ne se pose qu'une
## fois ce camp vidé (MatchManager écoute Events.evac_pad_cleared). Serveur seulement.
func _spawn_evac_pad_camp() -> void:
	var camp_data := load(Config.EVAC_PAD_CAMP) as CampData if Config.EVAC_PAD_CAMP != "" else null
	if camp_data == null:
		Events.evac_pad_cleared.emit(0)
		return
	if is_instance_valid(_pad_camp):
		_pad_camp.queue_free()
	_pad_camp = MonsterCamp.new()
	_pad_camp.name = "CampPlateformeEvac"
	_pad_camp.camp_data = camp_data
	_pad_camp.radius = 8.0
	_pad_camp.position = Config.EVAC_POSITION
	add_child(_pad_camp)
	_pad_camp.cleared.connect(func(_camp: MonsterCamp, killer_id: int) -> void: Events.evac_pad_cleared.emit(killer_id))
	_spawn_camp(_pad_camp)
