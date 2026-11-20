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
const ABILITY_MANAGER_SCRIPT := preload("res://systems/abilities/ability_manager.gd")
const PACT_SCRIPT := preload("res://systems/pacts/pact_manager.gd")
const PROFILE_SCRIPT := preload("res://systems/profiles/profile_manager.gd")
const SQUAD_SCRIPT := preload("res://systems/squads/squad_manager.gd")
const QualiteGraphique := preload("res://systems/rendu/qualite_graphique.gd")

@onready var players: Node3D = $Players
@onready var spawn_points: Node3D = $SpawnPoints

## Créés en code sur tous les peers (mêmes noms partout, pour les RPC).
var match_manager: MatchManager
var evac_ship: EvacShip


func _ready() -> void:
	_build_border()
	var post := PostTraitement.new()
	post.name = "PostTraitement"
	add_child(post)
	if not Net.is_dedicated_server:
		_appliquer_qualite()
		Events.reglages_graphiques_changes.connect(_appliquer_qualite)
	var decor := MapDecor.new()
	decor.name = "Decor"
	$Map.add_child(decor)
	var briefing_room := BriefingRoom.new()
	briefing_room.name = "BriefingRoom"
	add_child(briefing_room)
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
	var abilities: AbilityManager = ABILITY_MANAGER_SCRIPT.new()
	abilities.name = "AbilityManager"
	add_child(abilities)
	var pacts: PactManager = PACT_SCRIPT.new()
	pacts.name = "PactManager"
	add_child(pacts)
	var profiles: ProfileManager = PROFILE_SCRIPT.new()
	profiles.name = "ProfileManager"
	add_child(profiles)
	var squads: SquadManager = SQUAD_SCRIPT.new()
	squads.name = "SquadManager"
	add_child(squads)
	if not multiplayer.is_server():
		return
	Events.player_joined.connect(_on_peer_joined)
	Events.player_left.connect(_remove_player)
	# Clients déjà connectés (normalement aucun à ce stade).
	for id in multiplayer.get_peers():
		_on_peer_joined(id)
	# L'hôte joue aussi, sauf en serveur dédié.
	if not Net.is_dedicated_server:
		add_player(1)


## Arrivée d'un client : joueur créé seulement au lobby ; sinon il attend la prochaine partie.
func _on_peer_joined(peer_id: int) -> void:
	if match_manager.accepts_new_players():
		add_player(peer_id)
	else:
		match_manager.add_waiting(peer_id)


func add_player(peer_id: int) -> void:
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
	var pos := (points.pick_random() as Node3D).global_position
	return Vector3(pos.x, MapTerrain.height_at(pos.x, pos.z) + 2.0, pos.z)  # 2 m au-dessus du sol


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


## Applique la qualité graphique enregistrée (menu Échap) à l'environnement, au soleil et au post-traitement.
func _appliquer_qualite() -> void:
	QualiteGraphique.appliquer_monde(self, Config.SettingsStore.quality())
