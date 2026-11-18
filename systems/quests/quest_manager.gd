class_name QuestManager
extends Node
## Crée les quêtes / contrats via le CrystalSpawner (règle 3 : seul le serveur crée).
## - Sur tous les peers : fournit la spawn_function, reçoit les annonces.
## - Sur le serveur :
##   * un cristal par CrystalSpot, un contrat par ContractSpot (selon son `kind`) ;
##   * les spots « lumicep » font repousser des Lumicèpes (objets au sol) ;
##   * porter des Lumicèpes attire des Tiques (de plus en plus souvent) ;
##   * diffuse les annonces (Events.announce_requested) à tous les joueurs.

const CRYSTAL_SCRIPT := preload("res://systems/quests/crystal.gd")
const CONTRACT_SCRIPTS := {
	&"uplink": preload("res://systems/contracts/uplink.gd"),
	&"extractor": preload("res://systems/contracts/extractor.gd"),
	&"relic": preload("res://systems/contracts/relic.gd"),
	&"collector": preload("res://systems/contracts/collector.gd"),
	&"facility": preload("res://systems/contracts/facility.gd"),
	&"drones": preload("res://systems/contracts/drone_site.gd"),
}
const LUMICEP := &"lumicep"
const CRYSTALS_DIR := "res://data/quests/"
const TIQUE := preload("res://data/monsters/tique.tres")

@export var spawner: MultiplayerSpawner
@export var spots: Node3D
@export var contract_spots: Node3D
@export var players_root: Node3D

var _next_uid: int = 0
var _lumicep_spots: Array[Vector3] = []
var _lumicep_timer: float = 0.0
var _tick_timers: Dictionary = {}  # peer_id -> secondes avant la prochaine Tique


func _ready() -> void:
	spawner.spawn_function = _spawn_node
	set_physics_process(multiplayer.is_server())
	if not multiplayer.is_server():
		return
	Events.announce_requested.connect(func(text: String, color: Color) -> void: _announce.rpc(text, color))
	Events.crystal_spawn_requested.connect(_on_crystal_spawn_requested)
	Events.contract_spawn_requested.connect(func(kind: StringName, data_path: String, position: Vector3) -> void:
		if CONTRACT_SCRIPTS.has(kind):
			_spawn({"kind": kind, "data": data_path, "pos": position}))
	Events.match_reset_requested.connect(_on_match_reset)
	Events.crystal_upgrade_requested.connect(_on_crystal_upgrade)
	_spawn_all.call_deferred()


## Menu admin : un cristal de plus, à la position demandée (le chemin est déjà vérifié).
func _on_crystal_spawn_requested(crystal_data_path: String, position: Vector3) -> void:
	_spawn({"kind": &"crystal", "data": crystal_data_path, "pos": position})


func _spawn_all() -> void:
	for node in spots.get_children():
		var spot := node as CrystalSpot
		if spot and spot.crystal_data:
			_spawn({"kind": &"crystal", "data": spot.crystal_data.resource_path, "pos": spot.global_position})
	for node in contract_spots.get_children():
		var cspot := node as ContractSpot
		if cspot == null:
			continue
		if cspot.kind == LUMICEP:
			_lumicep_spots.append(cspot.global_position)
		elif CONTRACT_SCRIPTS.has(cspot.kind) and cspot.contract_data:
			_spawn({"kind": cspot.kind, "data": cspot.contract_data.resource_path, "pos": cspot.global_position})
			print("[Contrat] %s placé en %s" % [cspot.contract_data.display_name, cspot.global_position])
	_lumicep_timer = 0.0


func _spawn(data: Dictionary) -> void:
	_next_uid += 1
	data["uid"] = _next_uid
	spawner.spawn(data)


## Appelée sur tous les peers avec les mêmes données : recrée le même objet.
func _spawn_node(data: Dictionary) -> Node:
	var kind: StringName = data.get("kind", &"crystal")
	if kind == &"crystal":
		var crystal: Crystal = CRYSTAL_SCRIPT.new()
		crystal.name = "Crystal_%d" % data["uid"]
		crystal.setup(load(data["data"]) as CrystalData)
		crystal.position = data["pos"]
		return crystal
	var node: Node3D = CONTRACT_SCRIPTS[kind].new()
	node.name = "%s_%d" % [String(kind).capitalize(), data["uid"]]
	node.setup(load(data["data"]) as ContractData)
	node.position = data["pos"]
	return node


@rpc("authority", "call_local", "reliable")
func _announce(text: String, color: Color) -> void:
	Events.announcement.emit(text, color)


# =========================================================================
# Serveur : Lumicèpes et Tiques
# =========================================================================

func _physics_process(delta: float) -> void:
	_lumicep_timer -= delta
	if _lumicep_timer <= 0.0:
		_lumicep_timer = Config.match_rules.lumicep_respawn_time
		_regrow_lumiceps()
	for node in players_root.get_children():
		var player := node as Player
		if player == null or not player.can_be_hit():
			continue
		var carried := player.inventory.get_resource(LUMICEP)
		var peer := player.get_peer_id()
		if carried <= 0:
			_tick_timers.erase(peer)
			continue
		# Plus on porte de Lumicèpes, plus les Tiques arrivent vite.
		var interval := maxf(Config.match_rules.tick_interval / carried, Config.match_rules.tick_min_interval)
		var left: float = _tick_timers.get(peer, interval) - delta
		if left <= 0.0:
			left = interval
			var angle := randf() * TAU
			var pos := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(12.0, 16.0)
			Events.wave_spawn_requested.emit(player, TIQUE, pos, 1.0, 1.0)
		_tick_timers[peer] = left


func _regrow_lumiceps() -> void:
	var loot := get_parent().get_node("Loot")
	for spot in _lumicep_spots:
		var present := false
		for p in loot.get_children():
			var pickup := p as Pickup
			if pickup and pickup.item.id == LUMICEP and pickup.global_position.distance_to(spot) < 1.5:
				present = true
				break
		if not present:
			Events.loot_drop_requested.emit(LUMICEP, 1, -1, spot, false)


## Nouvelle partie : cristaux et contrats sont recréés neufs. Les Lumicèpes au sol sont
## retirés par le LootManager ; on les fait repousser tout de suite.
func _on_match_reset() -> void:
	for node in spawner.get_node(spawner.spawn_path).get_children():
		node.queue_free()
	_lumicep_spots.clear()
	_tick_timers.clear()
	_spawn_all.call_deferred()


## 10:00 : chaque cristal pas encore commencé (IDLE) est remplacé par le niveau au-dessus,
## au même endroit (le spawner le recrée chez tous). Défense en cours, extraction, cristal
## épuisé : inchangés. Le niveau max reste max.
func _on_crystal_upgrade() -> void:
	var by_level: Dictionary = {}  # niveau -> CrystalData
	for file in ResourceLoader.list_directory(CRYSTALS_DIR):
		var crystal_data: CrystalData = load(CRYSTALS_DIR + file) as CrystalData if file.ends_with(".tres") else null
		if crystal_data:
			by_level[crystal_data.level] = crystal_data
	var upgraded := 0
	for node in spawner.get_node(spawner.spawn_path).get_children():
		var crystal := node as Crystal
		if crystal == null or crystal.is_queued_for_deletion() or crystal.state != Crystal.State.IDLE:
			continue
		var next: CrystalData = by_level.get(crystal.data.level + 1)
		if next == null:
			continue
		var pos := crystal.position
		crystal.queue_free()
		_spawn({"kind": &"crystal", "data": next.resource_path, "pos": pos})
		upgraded += 1
	if upgraded > 0:
		Events.announce_requested.emit("Les cristaux restants montent d'un niveau : plus durs, plus de points !", Color(0.3, 0.95, 0.85))
	print("[Quête] %d cristaux montés d'un niveau" % upgraded)
