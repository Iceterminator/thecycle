extends Node3D
## Le monde de jeu (carte de test pour l'instant).
## Côté serveur : crée un joueur par client connecté, le retire à la déconnexion.
## Le MultiplayerSpawner réplique automatiquement ces joueurs chez tous les clients.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@onready var players: Node3D = $Players
@onready var spawn_points: Node3D = $SpawnPoints


func _ready() -> void:
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
	player.position = _pick_spawn_point()
	players.add_child(player, true)


func _remove_player(peer_id: int) -> void:
	var player := players.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()


func _pick_spawn_point() -> Vector3:
	## Étape 1 : point aléatoire. Plus tard : le joueur choisit sa zone de largage.
	var points := spawn_points.get_children()
	if points.is_empty():
		return Vector3(0, 2, 0)
	return (points.pick_random() as Node3D).global_position
