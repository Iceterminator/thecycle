class_name Niveaux
extends Node
## Ce qui est construit dans le monde selon l'activité. Le serveur décide (server_charger,
## server_retirer_briefing) ; chaque peer construit lui-même (décor local, rien de lourd sur le réseau) :
## - LOBBY : la salle de briefing seule, les joueurs y attendent pendant les menus ;
## - PARTIE : la carte (relief, décor), générée au début du briefing ; la salle disparaît au largage ;
## - SALLE_TEST : la salle de test seule (systems/salle_test/).
## Serveur : Events.carte_chargee / carte_liberee préviennent monstres, quêtes et loot.

enum Niveau { LOBBY, PARTIE, SALLE_TEST }

var niveau: Niveau = Niveau.LOBBY
var briefing_present: bool = true

@onready var _world: World = get_parent()
var _carte_construite := false


func _ready() -> void:
	_appliquer(niveau, briefing_present)
	if multiplayer.is_server():
		Events.player_joined.connect(func(peer: int) -> void: _appliquer.rpc_id(peer, niveau, briefing_present))


func carte_construite() -> bool:
	return _carte_construite


## Serveur : change d'activité chez tout le monde.
func server_charger(n: Niveau) -> void:
	_appliquer.rpc(n, n != Niveau.SALLE_TEST)


## Serveur : largage, la salle de briefing n'existe plus.
func server_retirer_briefing() -> void:
	_appliquer.rpc(niveau, false)


@rpc("authority", "call_local", "reliable")
func _appliquer(n: int, briefing: bool) -> void:
	var avant := niveau
	niveau = n as Niveau
	briefing_present = briefing
	_maj_briefing(briefing)
	_maj_salle_test(n == Niveau.SALLE_TEST)
	var carte := n == Niveau.PARTIE
	if carte != _carte_construite:
		_carte_construite = carte
		_construire_carte() if carte else _liberer_carte()
	if multiplayer.is_server() and avant != n:
		if avant != Niveau.LOBBY:  # monstres, objets, quêtes de la carte ou de la salle de test retirés
			Events.carte_liberee.emit()
		if carte:
			Events.carte_chargee.emit()


func _maj_briefing(present: bool) -> void:
	var salle := _world.get_node_or_null("BriefingRoom")
	if present and salle == null:
		salle = BriefingRoom.new()
		salle.name = "BriefingRoom"
		_world.add_child(salle)
	elif not present and salle:
		salle.name = "BriefingRoom_supprimee"
		salle.queue_free()


func _construire_carte() -> void:
	var map := _world.get_node_or_null("Map")
	var terrain := map.get_node_or_null("Terrain") as MapTerrain if map else null
	if terrain == null:
		return
	terrain.construire()
	var decor := MapDecor.new()
	decor.name = "Decor"
	map.add_child(decor)


func _liberer_carte() -> void:
	var map := _world.get_node_or_null("Map")
	if map == null:
		return
	var terrain := map.get_node_or_null("Terrain") as MapTerrain
	if terrain:
		terrain.detruire()
	var decor := map.get_node_or_null("Decor")
	if decor:
		decor.name = "Decor_supprime"
		decor.queue_free()


func _maj_salle_test(present: bool) -> void:
	var salle := _world.get_node_or_null("SalleTest")
	if present and salle == null:
		salle = SalleTest.new()
		salle.name = "SalleTest"
		_world.add_child(salle)
	elif not present and salle:
		salle.name = "SalleTest_supprimee"
		salle.queue_free()


## Lobby : un joueur choisit « Salle de test » ; tout le serveur y passe (une activité à la fois).
@rpc("any_peer", "call_local", "reliable")
func request_salle_test() -> void:
	if not multiplayer.is_server() or not MatchManager.is_lobby():
		return
	var mm := _world.match_manager
	mm.phase = MatchManager.Phase.SALLE_TEST
	mm.ready_players = {}
	server_charger(Niveau.SALLE_TEST)
	mm._broadcast_clock()
	var i := 0
	for node in _world.players.get_children():
		if node is Player:
			(node as Player).teleport.rpc(SalleTest.spawn_point(i))
			i += 1
	Events.announce_requested.emit("Salle de test : le téléporteur bleu ramène au lobby", MatchManager.ANNOUNCE_COLOR)


## Serveur (téléporteur de la salle) : retour au lobby pour tout le monde.
func server_quitter_salle_test() -> void:
	if niveau == Niveau.SALLE_TEST:
		_world.match_manager._cycle.enter_lobby()
