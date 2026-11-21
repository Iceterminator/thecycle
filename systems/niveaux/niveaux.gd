class_name Niveaux
extends Node
## Ce qui est construit dans le monde selon l'activité. Le serveur décide (server_charger,
## server_retirer_briefing) ; chaque peer construit lui-même (décor local, rien de lourd sur le réseau) :
## - LOBBY : la salle de briefing seule, les joueurs y attendent pendant les menus ;
## - PARTIE : la carte (relief, décor), générée au début du briefing en asynchrone (NiveauxCarte :
##   threads + création par tranches, aucune image longue) ; la salle disparaît au largage ;
## - SALLE_TEST : la salle de test seule (systems/salle_test/).
## Serveur : Events.carte_chargee (carte du serveur entièrement prête, collision comprise) puis
## carte_liberee préviennent monstres, quêtes et loot. Chaque client signale au serveur que SA carte
## est prête (request_carte_prete) : MatchBriefing n'ouvre le départ qu'ensuite (server_cartes_pretes).

const NiveauxCarte := preload("res://systems/niveaux/niveaux_carte.gd")
const NiveauxNoeuds := preload("res://systems/niveaux/niveaux_noeuds.gd")

enum Niveau { LOBBY, PARTIE, SALLE_TEST }

var niveau: Niveau = Niveau.LOBBY
var briefing_present: bool = true
## Tous peers : la carte de quelqu'un n'est pas encore prête (message « Chargement de la carte… »).
var carte_en_chargement: bool = false

@onready var _world: World = get_parent()
var _carte_construite := false   ## le niveau est PARTIE (la carte est construite ou en construction)
var _carte_prete := false        ## la carte de CE peer est entièrement construite
var _construction: NiveauxCarte
var _jeton: int = 0              ## numéro du chargement en cours (serveur : incrémenté à chaque server_charger)
var _prets: Dictionary = {}      ## serveur : peers clients dont la carte est prête


func _ready() -> void:
	_appliquer(niveau, briefing_present, _jeton)
	if multiplayer.is_server():
		Events.player_joined.connect(_on_player_joined)
		Events.player_left.connect(func(peer: int) -> void:
			_prets.erase(peer)
			_maj_chargement())


func _exit_tree() -> void:
	if _construction:
		_construction.annuler()


## Niveau PARTIE (carte construite ou en construction) ; carte_prete() : construction terminée.
func carte_construite() -> bool:
	return _carte_construite


func carte_prete() -> bool:
	return _carte_prete


## Serveur : change d'activité chez tout le monde.
func server_charger(n: Niveau) -> void:
	_jeton += 1
	_appliquer.rpc(n, n != Niveau.SALLE_TEST, _jeton)


## Serveur : largage, la salle de briefing n'existe plus.
func server_retirer_briefing() -> void:
	_appliquer.rpc(niveau, false, _jeton)


## Serveur : la carte du serveur et celle de chaque joueur de `peers` sont prêtes.
func server_cartes_pretes(peers: Array) -> bool:
	if not _carte_prete:
		return false
	for peer: int in peers:
		if peer != 1 and not _prets.has(peer):
			return false
	return true


func _on_player_joined(peer: int) -> void:
	_prets.erase(peer)
	_appliquer.rpc_id(peer, niveau, briefing_present, _jeton)
	_maj_chargement()
	_sync_chargement.rpc_id(peer, carte_en_chargement)


@rpc("authority", "call_local", "reliable")
func _appliquer(n: int, briefing: bool, jeton: int) -> void:
	var avant := niveau
	niveau = n as Niveau
	briefing_present = briefing
	_jeton = jeton
	NiveauxNoeuds.maj_briefing(_world, briefing)
	NiveauxNoeuds.maj_salle_test(_world, n == Niveau.SALLE_TEST)
	var carte := n == Niveau.PARTIE
	if carte != _carte_construite:
		_carte_construite = carte
		_construire_carte() if carte else _liberer_carte()
	if multiplayer.is_server() and avant != n:
		_prets = {}
		if avant != Niveau.LOBBY:  # monstres, objets, quêtes de la carte ou de la salle de test retirés
			Events.carte_liberee.emit()
		_maj_chargement()


## Client -> serveur : ma carte est entièrement construite (jeton = chargement concerné).
@rpc("any_peer", "call_remote", "reliable")
func request_carte_prete(jeton: int) -> void:
	if not multiplayer.is_server() or jeton != _jeton or niveau != Niveau.PARTIE:
		return
	_prets[multiplayer.get_remote_sender_id()] = true
	_maj_chargement()


## Serveur : prévient tout le monde quand « une carte est en chargement » change.
func _maj_chargement() -> void:
	var attente := niveau == Niveau.PARTIE and not server_cartes_pretes(Array(multiplayer.get_peers()))
	if attente != carte_en_chargement:
		_sync_chargement.rpc(attente)


@rpc("authority", "call_local", "reliable")
func _sync_chargement(attente: bool) -> void:
	carte_en_chargement = attente


func _construire_carte() -> void:
	_carte_prete = false
	var map := _world.get_node_or_null("Map")
	if map == null:
		_on_carte_prete.call_deferred()  # pas de carte dans ce monde : rien à attendre
		return
	_construction = NiveauxCarte.new()
	_construction.lancer(_world, map, _on_carte_prete)  # coroutine : on n'attend pas


func _on_carte_prete() -> void:
	_carte_prete = true
	if multiplayer.is_server():
		Events.carte_chargee.emit()  # navmesh des monstres ; MatchBriefing repart de là
		_maj_chargement()
	else:
		request_carte_prete.rpc_id(1, _jeton)


func _liberer_carte() -> void:
	if _construction:
		_construction.annuler()  # construction en cours : elle s'arrête au prochain point d'attente
		_construction = null
	_carte_prete = false
	NiveauxNoeuds.liberer_carte(_world)


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
