extends RefCounted
## Enchaînement des parties (serveur) : fin de partie, remise à zéro, largage, retour au lobby.
## Utilisé par MatchManager, qui garde l'état et les RPC.

var _m: MatchManager


func _init(manager: MatchManager) -> void:
	_m = manager


func end_match() -> void:
	var world := _m.world
	_m.phase = MatchManager.Phase.ENDED
	_m.elapsed = Config.match_rules.match_duration
	Events.evac_departed.emit()
	_m._results = []
	for node in world.players.get_children():
		var player := node as Player
		if player == null:
			continue
		var peer := player.get_peer_id()
		var aboard := peer in _m.evacuated
		if not aboard:
			player.score.add_rank_points(-Config.economy.evac_missed_penalty)
		_m._results.append({"peer": peer, "points": player.score.rank_points, "evacuated": aboard})
	_m._results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["points"] > b["points"])
	_m._restart_left = Config.match_rules.match_restart_delay
	Events.match_ended.emit()
	Events.announce_requested.emit("L'évac a décollé ! Fin de la partie.", MatchManager.ANNOUNCE_COLOR)
	print("[Partie] Fin : %s" % [_m._results])
	_m._broadcast_clock()
	_m._show_results.rpc(_m._results, _m._restart_left)


## Nouvelle partie, étape 1 : chaque système de carte se remet à zéro (Events : tirage des
## quêtes, monstres), puis les joueurs ; puis phase LARGAGE (écran carte + quêtes). Le chrono
## de partie reste à 0 jusqu'à begin_drop (fin de l'écran).
func restart() -> void:
	var world := _m.world
	# Niveau 1 d'abord : les camps sont repeuplés pendant match_reset_requested.
	Events.monster_level_changed.emit(1)
	Events.match_reset_requested.emit()
	# Équipement du profil (choisi dans le lobby).
	var profiles := world.get_node_or_null("ProfileManager") as ProfileManager
	var players: Array[Player] = []
	for node in world.players.get_children():
		var player := node as Player
		if player == null:
			continue
		if profiles:
			profiles.server_apply_loadout(player.get_peer_id())
		_reset_player(player)
		players.append(player)
	_m.ready_players = {}
	_m.evacuated.clear()
	_m._set_pad_blocked(false)
	_m._results = []
	_m.phase = MatchManager.Phase.DROP
	_m.elapsed = 0.0
	_m._drop_left = Config.match_rules.drop_screen_time
	_m._drop_points = DropPoints.assign(world, players)
	_m._broadcast_clock()
	for player in players:
		send_drop_screen(player.get_peer_id())
	print("[Partie] Largage dans %d s : %s" % [roundi(_m._drop_left), _m._drop_points])


## Écran de largage d'un joueur : son point et ceux de son escouade (temps restant).
func send_drop_screen(peer: int) -> void:
	if _m.world.get_player(peer) == null:
		return
	var squad := SquadManager.squad_of(peer)
	var points: Array = []
	for other_peer: int in _m._drop_points:
		if other_peer == peer or (squad != 0 and SquadManager.squad_of(other_peer) == squad):
			points.append([other_peer, _m._drop_points[other_peer]])
	_m._show_drop.rpc_id(peer, points, _m._drop_left)


## Fin de l'écran de largage : la partie démarre, chacun descend dans sa capsule.
func begin_drop() -> void:
	_m.phase = MatchManager.Phase.PLAYING
	_m.elapsed = 0.0
	_m._broadcast_clock()
	for peer: int in _m._drop_points:
		var player := _m.world.get_player(peer)
		if player:
			player.drop.server_start(_m._drop_points[peer])
	Events.announce_requested.emit("Nouvelle partie !", MatchManager.ANNOUNCE_COLOR)
	print("[Partie] Nouvelle partie : largage")


func _reset_player(player: Player) -> void:
	player.set_evacuated.rpc(false)
	player.health.server_reset()
	player.inventory.server_reset()
	player.score.server_reset()
	player.weapon.server_refill()


## Après l'écran de fin : retour au lobby (les joueurs restent dans le monde, sans dégâts).
func enter_lobby() -> void:
	_m.phase = MatchManager.Phase.LOBBY
	_m.ready_players = {}
	for peer in _m.waiting:  # ceux arrivés en cours de partie entrent maintenant
		if peer in _m.multiplayer.get_peers():
			_m.world.add_player(peer)
			_m._show_waiting.rpc_id(peer, false)
	_m.waiting.clear()
	for node in _m.world.players.get_children():
		var player := node as Player
		if player:
			player.set_evacuated.rpc(false)
			player.health.server_reset()
			player.drop.server_cancel()
	_m._broadcast_clock()
	Events.announce_requested.emit("Lobby : préparez votre équipement, la partie démarre quand tout le monde est prêt", MatchManager.ANNOUNCE_COLOR)


## Un nouvel arrivant reçoit l'horloge, le lobby, les joueurs embarqués, l'écran d'attente ou de fin.
func sync_new_player(peer_id: int) -> void:
	_m._sync_clock.rpc_id(peer_id, _m.elapsed, _m.phase)
	_m._sync_pad.rpc_id(peer_id, _m.pad_blocked)
	if _m.phase == MatchManager.Phase.LOBBY:
		_m._sync_lobby.rpc_id(peer_id, _m.ready_players)
	for id in _m.evacuated:
		var player := _m.world.get_player(id)
		if player:
			player.set_evacuated.rpc_id(peer_id, true)
	if peer_id in _m.waiting:
		_m._show_waiting.rpc_id(peer_id, true)
		return
	if _m.phase == MatchManager.Phase.ENDED:
		_m._show_results.rpc_id(peer_id, _m._results, _m._restart_left)


## Décompte du lobby (seulement s'il y a des joueurs) ; départ quand tous sont prêts.
func server_lobby(delta: float) -> void:
	var count := _m.world.players.get_child_count()
	if count == 0:
		return
	var all_ready := true
	for node in _m.world.players.get_children():
		if not _m.ready_players.get((node as Player).get_peer_id(), false):
			all_ready = false
	_m._resync_left -= delta
	if _m._resync_left <= 0.0:
		_m._broadcast_clock()
	if all_ready:
		print("[Partie] Départ : les %d joueurs sont prêts" % count)
		restart()
