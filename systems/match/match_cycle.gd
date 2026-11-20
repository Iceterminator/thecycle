extends RefCounted
## Enchaînement des parties (serveur) : fin de partie, remise à zéro, largage, retour au lobby
## (la salle de briefing entre le lobby et le largage : match_briefing.gd).
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


## Nouvelle partie (début du briefing) : chaque système de carte se remet à zéro (Events : tirage
## des quêtes, monstres). Les joueurs sont remis à zéro en entrant dans la salle (MatchBriefing).
func reset_world() -> void:
	# Niveau 1 d'abord : les camps sont repeuplés pendant match_reset_requested.
	Events.monster_level_changed.emit(1)
	Events.match_reset_requested.emit()
	_m.evacuated.clear()
	_m._set_pad_blocked(false)
	_m._results = []


## Fin du briefing : la partie démarre, chacun descend dans sa capsule ; chaque joueur reçoit
## son point de largage et ceux de son escouade (Events.drop_phase_started).
func begin_drop() -> void:
	_m.phase = MatchManager.Phase.PLAYING
	_m.elapsed = 0.0
	_m._broadcast_clock()
	for peer: int in _m._drop_points:
		var player := _m.world.get_player(peer)
		if player:
			_send_drop_points(peer)
			player.drop.server_start(_m._drop_points[peer])
	Events.announce_requested.emit("Nouvelle partie !", MatchManager.ANNOUNCE_COLOR)
	print("[Partie] Nouvelle partie : largage")


func _send_drop_points(peer: int) -> void:
	var squad := SquadManager.squad_of(peer)
	var points: Array = []
	for other_peer: int in _m._drop_points:
		if other_peer == peer or (squad != 0 and SquadManager.squad_of(other_peer) == squad):
			points.append([other_peer, _m._drop_points[other_peer]])
	_m._show_drop.rpc_id(peer, points, 0.0)


func reset_player(player: Player) -> void:
	player.set_evacuated.rpc(false)
	player.health.server_reset()
	player.inventory.server_reset()
	player.score.server_reset()
	player.weapon.server_refill()


## Après l'écran de fin : retour au lobby (les joueurs restent dans le monde, sans dégâts).
func enter_lobby() -> void:
	_m.phase = MatchManager.Phase.LOBBY
	_m.ready_players = {}
	_m.briefing_room = []
	_m.briefing_votes = []
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
	Events.announce_requested.emit("Lobby : préparez votre équipement, le premier prêt ouvre la salle de briefing", MatchManager.ANNOUNCE_COLOR)


## Un nouvel arrivant reçoit l'horloge, le lobby, les joueurs embarqués, l'écran d'attente ou de fin.
func sync_new_player(peer_id: int) -> void:
	_m._sync_clock.rpc_id(peer_id, _m.elapsed, _m.phase)
	_m._sync_pad.rpc_id(peer_id, _m.pad_blocked)
	if _m.phase == MatchManager.Phase.LOBBY or _m.phase == MatchManager.Phase.BRIEFING:
		_m._sync_lobby.rpc_id(peer_id, _m.ready_players)
		_m._sync_briefing.rpc_id(peer_id, _m.briefing_left, _m.briefing_votes, _m.briefing_room)
	for id in _m.evacuated:
		var player := _m.world.get_player(id)
		if player:
			player.set_evacuated.rpc_id(peer_id, true)
	if peer_id in _m.waiting:
		_m._show_waiting.rpc_id(peer_id, true)
		return
	if _m.phase == MatchManager.Phase.ENDED:
		_m._show_results.rpc_id(peer_id, _m._results, _m._restart_left)


## Lobby : resynchronise l'état « prêt » (le briefing démarre au premier prêt, voir MatchManager).
func server_lobby(delta: float) -> void:
	_m._resync_left -= delta
	if _m._resync_left <= 0.0 and _m.world.players.get_child_count() > 0:
		_m._broadcast_clock()


## Pas de physique serveur : minuteur de la phase en cours, ou avancée de l'horloge de partie.
func server_tick(delta: float) -> void:
	if _m.phase == MatchManager.Phase.LOBBY:
		server_lobby(delta)
		return
	if _m.phase == MatchManager.Phase.BRIEFING:
		_m._briefing.tick(delta)
		return
	if _m.phase == MatchManager.Phase.ENDED:
		_m._restart_left -= delta
		if _m._restart_left <= 0.0:
			enter_lobby()
		return
	_m._clock.advance(_m.elapsed + delta)
	_m._resync_left -= delta
	if _m._resync_left <= 0.0:
		_m._broadcast_clock()


## Un joueur arrive : horloge, joueurs déjà embarqués, classement. Petit délai : son client
## doit d'abord recevoir le monde et les joueurs.
func on_player_joined(peer_id: int) -> void:
	await _m.get_tree().create_timer(1.0).timeout
	if peer_id in _m.multiplayer.get_peers():
		sync_new_player(peer_id)
