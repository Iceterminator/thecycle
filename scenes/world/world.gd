class_name World
extends Node3D
## Le monde de jeu (carte de test pour l'instant).
## Côté serveur : crée un joueur par client connecté, le retire à la déconnexion.
## Le MultiplayerSpawner réplique automatiquement ces joueurs chez tous les clients.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MATCH_SCRIPT := preload("res://systems/match/match_manager.gd")
const EVAC_SCRIPT := preload("res://systems/evac/evac_ship.gd")
const STORM_SCRIPT := preload("res://systems/storm/storm_manager.gd")
const FAME_SCRIPT := preload("res://systems/score/fame_manager.gd")

@onready var players: Node3D = $Players
@onready var spawn_points: Node3D = $SpawnPoints

## Créés en code sur tous les peers (mêmes noms partout, pour les RPC).
var match_manager: MatchManager
var evac_ship: EvacShip


func _ready() -> void:
	_build_border()
	evac_ship = EVAC_SCRIPT.new()
	evac_ship.name = "EvacShip"
	evac_ship.players_root = players
	add_child(evac_ship)
	match_manager = MATCH_SCRIPT.new()
	match_manager.name = "MatchManager"
	add_child(match_manager)
	var storm: StormManager = STORM_SCRIPT.new()
	storm.name = "StormManager"
	add_child(storm)
	var fame: FameManager = FAME_SCRIPT.new()
	fame.name = "FameManager"
	add_child(fame)
	if not multiplayer.is_server():
		return
	Events.player_joined.connect(_add_player)
	Events.player_left.connect(_remove_player)
	# Clients déjà connectés (normalement aucun à ce stade).
	for id in multiplayer.get_peers():
		_add_player(id)
	# L'hôte joue aussi, sauf en serveur dédié.
	if not Net.is_dedicated_server:
		_add_player(1)


func _add_player(peer_id: int) -> void:
	if players.has_node(str(peer_id)):
		return
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)  # le nom = l'id réseau, utilisé pour l'autorité
	player.position = pick_spawn_point()
	players.add_child(player, true)


func _remove_player(peer_id: int) -> void:
	var player := players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()


func get_player(peer_id: int) -> Player:
	return players.get_node_or_null(str(peer_id)) as Player


func pick_spawn_point() -> Vector3:
	## Point aléatoire (aussi utilisé par RespawnManager). Plus tard : le joueur choisit sa zone de largage.
	var points := spawn_points.get_children()
	if points.is_empty():
		return Vector3(0, 2, 0)
	return (points.pick_random() as Node3D).global_position


## Murs invisibles autour de la carte (sur tous les peers : décor local, pas d'objet réseau).
## Couche « monde » : ils arrêtent joueurs, monstres et tirs.
func _build_border() -> void:
	var half := Config.MAP_HALF_SIZE
	var height := 80.0
	var thick := 2.0
	var body := StaticBody3D.new()
	body.name = "MapBorder"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var along_x := side.z != 0.0
		box.size = Vector3(half * 2.0 + thick * 2.0 if along_x else thick, height, thick if along_x else half * 2.0 + thick * 2.0)
		shape.shape = box
		shape.position = side * (half + thick / 2.0) + Vector3.UP * (height / 2.0 - 10.0)
		body.add_child(shape)
