class_name QuestManager
extends Node
## Crée les quêtes / contrats via le CrystalSpawner (règle 3 : seul le serveur crée).
## - Sur tous les peers : fournit la spawn_function, reçoit les annonces et la liste des
##   objectifs actifs (écran Tab).
## - Sur le serveur :
##   * nouvelle carte (quest_spots) : tirage au sort des quêtes à chaque partie (QuestDraw) ;
##   * ancienne carte (spots + contract_spots) : un cristal / contrat par emplacement ;
##   * Lumicèpes et Tiques : voir LumicepTicks ;
##   * quêtes différées (Cœur, collecteur d'orage) : voir QuestDelayed ;
##   * diffuse les annonces (Events.announce_requested) à tous les joueurs.

const QuestManagerUpgrade := preload("res://systems/quests/quest_manager_upgrade.gd")
const LUMICEP := &"lumicep"
const CRYSTALS_DIR := "res://data/quests/"

@export var spawner: MultiplayerSpawner
@export var quest_spots: Node3D  ## nouvelle carte : emplacements de quêtes (tirage)
@export var lumicep_spots: Node3D  ## nouvelle carte : points de Lumicèpes
@export var spots: Node3D  ## ancienne carte : CrystalSpot
@export var contract_spots: Node3D  ## ancienne carte : ContractSpot
@export var players_root: Node3D

## Objectifs (ids de data/objectives/) des quêtes de la partie ; vide = pas de filtre (tout afficher).
var active_objectives: PackedStringArray = PackedStringArray()
## Quêtes tirées pour l'écran de largage : {name, count, later} (synchronisé avec les objectifs).
var drawn_list: Array = []

var _next_uid: int = 0
var _ticks: LumicepTicks
var _delayed: QuestDelayed


func _ready() -> void:
	spawner.spawn_function = QuestFactory.create
	if not multiplayer.is_server():
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_request_objectives.rpc_id(1)
		else:  # le monde se charge avant la fin de la connexion
			multiplayer.connected_to_server.connect(func() -> void: _request_objectives.rpc_id(1), CONNECT_ONE_SHOT)
		return
	_ticks = LumicepTicks.new()
	_ticks.players_root = players_root
	_ticks.loot_root = get_parent().get_node("Loot")
	add_child(_ticks)
	_delayed = QuestDelayed.new()
	_delayed.world = get_parent() as World
	_delayed.spawn_callable = _spawn
	add_child(_delayed)
	Events.announce_requested.connect(func(text: String, color: Color) -> void: _announce.rpc(text, color))
	Events.crystal_spawn_requested.connect(_on_crystal_spawn_requested)
	Events.contract_spawn_requested.connect(func(kind: StringName, data_path: String, position: Vector3) -> void:
		if QuestFactory.CONTRACT_SCRIPTS.has(kind):
			_spawn({"kind": kind, "data": data_path, "pos": position}))
	Events.match_reset_requested.connect(_on_match_reset)
	Events.crystal_upgrade_requested.connect(_on_crystal_upgrade)
	_spawn_all.call_deferred()


## Menu admin : un cristal de plus, à la position demandée (le chemin est déjà vérifié).
func _on_crystal_spawn_requested(crystal_data_path: String, position: Vector3) -> void:
	_spawn({"kind": &"crystal", "data": crystal_data_path, "pos": position})


func _spawn_all() -> void:
	if quest_spots:
		_spawn_drawn()
	else:
		_spawn_legacy()


## Tirage au sort : types, exemplaires, emplacements, points de Lumicèpes.
func _spawn_drawn() -> void:
	var result := QuestDraw.draw(QuestDraw.load_draws(), QuestDraw.marker_positions(quest_spots),
			QuestDraw.marker_positions(lumicep_spots), Config.match_rules.drawn_quest_types,
			Config.match_rules.lumicep_spots_per_collector, Config.match_rules)
	for quest: Dictionary in result["quests"]:
		print("[Quête] %s en %s : %s" % [quest["name"], quest["pos"], quest["data"].get_file()])
		if not _delayed.queue_if_delayed(quest):
			_spawn(quest)
	_ticks.set_spots(result["lumicep_spots"])
	print("[Quête] tirage : %s (%d points de Lumicèpes)" % [result["summary"], result["lumicep_spots"].size()])
	_set_objectives.rpc(result["objectives"], result["list"])


## Ancienne carte (world_test) : un cristal par CrystalSpot, un contrat par ContractSpot.
func _spawn_legacy() -> void:
	var lumicep_points: Array[Vector3] = []
	for node in spots.get_children():
		var spot := node as CrystalSpot
		if spot and spot.crystal_data:
			_spawn({"kind": &"crystal", "data": spot.crystal_data.resource_path, "pos": spot.global_position})
	for node in contract_spots.get_children():
		var cspot := node as ContractSpot
		if cspot == null:
			continue
		if cspot.kind == LUMICEP:
			lumicep_points.append(cspot.global_position)
		elif QuestFactory.CONTRACT_SCRIPTS.has(cspot.kind) and cspot.contract_data:
			_spawn({"kind": cspot.kind, "data": cspot.contract_data.resource_path, "pos": cspot.global_position})
			print("[Contrat] %s placé en %s" % [cspot.contract_data.display_name, cspot.global_position])
	_ticks.set_spots(lumicep_points)
	_set_objectives.rpc(PackedStringArray(), [])


func _spawn(data: Dictionary) -> void:
	_next_uid += 1
	spawner.spawn({"kind": data["kind"], "data": data["data"], "pos": data["pos"], "uid": _next_uid})


@rpc("authority", "call_local", "reliable")
func _announce(text: String, color: Color) -> void:
	Events.announcement.emit(text, color)


## Liste des objectifs actifs : envoyée à tous au tirage, et à la demande d'un client qui arrive.
@rpc("authority", "call_local", "reliable")
func _set_objectives(ids: PackedStringArray, list: Array) -> void:
	active_objectives = ids
	drawn_list = list
	Events.objectives_synced.emit()


@rpc("any_peer", "reliable")
func _request_objectives() -> void:
	if multiplayer.is_server():
		_set_objectives.rpc_id(multiplayer.get_remote_sender_id(), active_objectives, drawn_list)


## Nouvelle partie : cristaux et contrats sont recréés neufs (nouveau tirage). Les Lumicèpes
## au sol sont retirés par le LootManager ; on les fait repousser tout de suite.
func _on_match_reset() -> void:
	_delayed.clear()
	for node in spawner.get_node(spawner.spawn_path).get_children():
		node.queue_free()
	_spawn_all.call_deferred()

## 10:00 : les cristaux pas encore commencés montent d'un niveau (voir QuestManagerUpgrade).
func _on_crystal_upgrade() -> void:
	QuestManagerUpgrade.upgrade_idle_crystals(self)
