extends RefCounted
## Salle de briefing (phase BRIEFING, serveur) : le premier « prêt » du lobby tire les quêtes et
## lance un compte à rebours (Config.match_rules.briefing_time). Chaque joueur prêt est téléporté
## dans la salle (BriefingRoom) avec son équipement. Départ à la fin du compte à rebours, ou dès
## qu'une majorité des joueurs de la salle a voté « départ » (touche E). Ceux restés au lobby
## attendent la partie suivante. Utilisé par MatchManager, qui garde l'état synchronisé et les RPC.

const SYNC_INTERVAL := 1.0

var _m: MatchManager
var _sync_left: float = 0.0
var _carte_debut_ms: int = 0         ## début du chargement de la carte (délai max : map_ready_timeout)
var _attente_signalee: bool = false  ## le départ attend les cartes (une seule ligne de journal)


func _init(manager: MatchManager) -> void:
	_m = manager


## Premier « prêt » : la carte est générée en asynchrone (Niveaux), puis remise à zéro (tirage des
## quêtes, monstres) quand celle du serveur est prête ; salle ouverte tout de suite.
func start() -> void:
	_m.world.niveaux.server_charger(Niveaux.Niveau.PARTIE)
	_carte_debut_ms = Time.get_ticks_msec()
	_attente_signalee = false
	if not Events.carte_chargee.is_connected(_on_carte_chargee):
		Events.carte_chargee.connect(_on_carte_chargee, CONNECT_ONE_SHOT)
	_m.phase = MatchManager.Phase.BRIEFING
	_m.elapsed = 0.0
	_m.briefing_left = Config.match_rules.briefing_time
	_m.briefing_room = []
	_m.briefing_votes = []
	_m._broadcast_clock()
	Events.announce_requested.emit("Salle de briefing ouverte : départ dans %d s" % roundi(_m.briefing_left), MatchManager.ANNOUNCE_COLOR)
	print("[Partie] Briefing : %d s" % roundi(_m.briefing_left))


## Joueur prêt : équipement du profil, remise à zéro, téléporté dans la salle.
func enter(peer: int) -> void:
	var player := _m.world.get_player(peer)
	if player == null or peer in _m.briefing_room:
		return
	var profiles := _m.world.get_node_or_null("ProfileManager") as ProfileManager
	if profiles:
		profiles.server_apply_loadout(peer)
	_m._cycle.reset_player(player)
	var room := _m.briefing_room.duplicate()
	room.append(peer)
	_m.briefing_room = room
	player.teleport.rpc(BriefingRoom.spawn_point(room.size() - 1))
	sync()


func leave(peer: int) -> void:
	_m.briefing_room.erase(peer)
	_m.briefing_votes.erase(peer)
	if _m.phase == MatchManager.Phase.BRIEFING:
		sync()


func vote(peer: int, value: bool) -> void:
	if not peer in _m.briefing_room:
		return
	var votes := _m.briefing_votes.duplicate()
	votes.erase(peer)
	if value:
		votes.append(peer)
	_m.briefing_votes = votes
	sync()


## Majorité stricte des joueurs présents dans la salle.
func vote_passed() -> bool:
	return not _m.briefing_room.is_empty() and _m.briefing_votes.size() * 2 > _m.briefing_room.size()


func tick(delta: float) -> void:
	_m.briefing_left = maxf(_m.briefing_left - delta, 0.0)
	_sync_left -= delta
	if _sync_left <= 0.0:
		sync()
	if _m.briefing_left > 0.0 and not vote_passed():
		return
	if _m.briefing_room.is_empty():
		_m._cycle.enter_lobby()  # plus personne dans la salle : retour au lobby
	elif cartes_pretes():
		finish()


## Départ possible : cartes prêtes, ou délai max écoulé (on part quand même, avec un message).
func cartes_pretes() -> bool:
	if _m.world.niveaux.server_cartes_pretes(_m.briefing_room):
		return true
	var attente := (Time.get_ticks_msec() - _carte_debut_ms) / 1000.0
	if attente >= Config.match_rules.map_ready_timeout:
		push_warning("[Partie] Cartes pas toutes prêtes après %d s : départ forcé" % roundi(attente))
		return true
	if not _attente_signalee:
		_attente_signalee = true
		print("[Partie] Départ en attente des cartes (serveur et joueurs de la salle)")
	return false


func _on_carte_chargee() -> void:
	if _m.phase == MatchManager.Phase.BRIEFING:
		_m._cycle.reset_world()


func sync() -> void:
	_sync_left = SYNC_INTERVAL
	_m._sync_briefing.rpc(_m.briefing_left, _m.briefing_votes, _m.briefing_room)


## Départ : les joueurs de la salle reçoivent leur point de largage ; les autres attendent.
func finish() -> void:
	var players: Array[Player] = []
	for node in _m.world.players.get_children():
		var player := node as Player
		if player == null:
			continue
		var peer := player.get_peer_id()
		if peer in _m.briefing_room:
			players.append(player)
		else:
			player.queue_free()
			_m.add_waiting(peer)
			_m._show_waiting.rpc_id(peer, true)
	_m.ready_players = {}
	_m._drop_points = DropPoints.assign(_m.world, players)
	print("[Partie] Fin du briefing (%s) : %s" % ["vote" if vote_passed() else "temps écoulé", _m._drop_points])
	_m._cycle.begin_drop()


## « Prêt » au lobby : le premier ouvre la salle ; chacun y est téléporté (plus d'annulation).
func on_ready(peer: int, value: bool) -> void:
	if _m.world.get_player(peer) == null or peer in _m.briefing_room:
		return
	if _m.phase != MatchManager.Phase.LOBBY and not (_m.phase == MatchManager.Phase.BRIEFING and value):
		return
	var d := _m.ready_players.duplicate()
	d[peer] = value
	_m.ready_players = d
	if value:
		if _m.phase == MatchManager.Phase.LOBBY:
			start()
		enter(peer)
	_m._broadcast_clock()


## Menu admin : lobby -> tout le monde dans la salle ; salle -> départ immédiat (dès que les cartes sont prêtes).
func force_start() -> void:
	if _m.phase == MatchManager.Phase.LOBBY:
		start()
		for node in _m.world.players.get_children():
			_m.ready_players[(node as Player).get_peer_id()] = true
			enter((node as Player).get_peer_id())
		_m._broadcast_clock()
	elif _m.phase == MatchManager.Phase.BRIEFING:
		_m.briefing_left = 0.0  # le prochain tick part dès que les cartes sont prêtes
