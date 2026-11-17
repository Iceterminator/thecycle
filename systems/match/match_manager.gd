class_name MatchManager
extends Node
## Déroulé d'une partie (étape 6), décidé par le SERVEUR :
##   0:00 -> 15:00 : prospection ; 15:00 : l'évac se pose ; 20:00 : décollage, fin de partie ;
##   écran de fin pendant Config.MATCH_RESTART_DELAY, puis nouvelle partie sur place.
## Créé en code par World sur tous les peers (même chemin partout, pour les RPC).
## Les clients reçoivent l'horloge (temps écoulé + phase) au début, à chaque changement
## et toutes les Config.MATCH_CLOCK_RESYNC s ; le HUD l'avance seul entre deux envois.
##
## Embarquement (voir EvacShip) : premier embarqué +EVAC_FIRST_BONUS, suivants
## +EVAC_OTHER_BONUS ; au décollage, les joueurs restés au sol perdent EVAC_MISSED_PENALTY.

enum Phase { PLAYING, EVAC, ENDED }

const ANNOUNCE_COLOR := Color(0.6, 0.85, 1.0)

@onready var world: World = get_parent()

var phase: Phase = Phase.PLAYING
var elapsed: float = 0.0
## Serveur : ids des joueurs embarqués, dans l'ordre.
var evacuated: Array[int] = []

var _resync_left: float = 0.0
var _restart_left: float = 0.0
var _results: Array = []


func _ready() -> void:
	Events.match_clock_requested.connect(func() -> void: Events.match_clock_synced.emit(elapsed, phase))
	set_physics_process(multiplayer.is_server())
	set_process(not multiplayer.is_server())
	if not multiplayer.is_server():
		return
	Events.time_skip_requested.connect(func(seconds: float) -> void: _set_time(elapsed + seconds))
	Events.match_time_set_requested.connect(_set_time)
	Events.player_evacuated.connect(_on_player_evacuated)
	Events.player_joined.connect(_on_player_joined)
	_broadcast_clock.call_deferred()


func _physics_process(delta: float) -> void:
	if phase == Phase.ENDED:
		_restart_left -= delta
		if _restart_left <= 0.0:
			_restart()
		return
	_advance(elapsed + delta)
	_resync_left -= delta
	if _resync_left <= 0.0:
		_broadcast_clock()


## Clients : copie locale de l'horloge, avancée entre deux envois du serveur.
func _process(delta: float) -> void:
	if phase != Phase.ENDED:
		elapsed = minf(elapsed + delta, Config.MATCH_DURATION)


## Annonces : [temps (s), texte]. Déclenchées quand l'horloge franchit le temps.
func _announces() -> Array:
	var land := Config.EVAC_LANDING_TIME
	var end := Config.MATCH_DURATION
	return [
		[land - 60.0, "L'évac arrive dans 1 minute, au centre de la carte !"],
		[end - 60.0, "Décollage de l'évac dans 1 minute !"],
		[end - 10.0, "Décollage dans 10 secondes !"],
	]


## Fait avancer l'horloge jusqu'à `to` en déclenchant tout ce qui est franchi.
func _advance(to: float) -> void:
	var before := elapsed
	elapsed = minf(to, Config.MATCH_DURATION)
	for entry: Array in _announces():
		if before < entry[0] and elapsed >= entry[0]:
			Events.announce_requested.emit(entry[1], ANNOUNCE_COLOR)
	if phase == Phase.PLAYING and elapsed >= Config.EVAC_LANDING_TIME:
		phase = Phase.EVAC
		Events.evac_landed.emit()
		Events.announce_requested.emit("L'évac se pose au centre ! Montez à bord par la rampe.", ANNOUNCE_COLOR)
		_broadcast_clock()
	if elapsed >= Config.MATCH_DURATION:
		_end_match()


## Menu admin : on ne peut qu'avancer (revenir en arrière défairait l'évac).
func _set_time(seconds: float) -> void:
	if phase == Phase.ENDED or not is_finite(seconds) or seconds <= elapsed:
		return
	_advance(seconds)
	if phase != Phase.ENDED:
		_broadcast_clock()


func _on_player_evacuated(peer_id: int) -> void:
	if phase != Phase.EVAC or peer_id in evacuated:
		return
	var player := world.get_player(peer_id)
	if player == null:
		return
	evacuated.append(peer_id)
	var bonus := Config.EVAC_FIRST_BONUS if evacuated.size() == 1 else Config.EVAC_OTHER_BONUS
	player.score.add_rank_points(bonus)
	player.set_evacuated.rpc(true)
	var text := "Joueur %d a embarqué dans l'évac !" % peer_id
	if bonus > 0:
		text += " (premier à bord : +%d)" % bonus
	Events.announce_requested.emit(text, ANNOUNCE_COLOR)
	print("[Partie] Joueur %d embarqué (+%d)" % [peer_id, bonus])


func _end_match() -> void:
	phase = Phase.ENDED
	elapsed = Config.MATCH_DURATION
	Events.evac_departed.emit()
	_results = []
	for node in world.players.get_children():
		var player := node as Player
		if player == null:
			continue
		var peer := player.get_peer_id()
		var aboard := peer in evacuated
		if not aboard:
			player.score.add_rank_points(-Config.EVAC_MISSED_PENALTY)
		_results.append({"peer": peer, "points": player.score.rank_points, "evacuated": aboard})
	_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["points"] > b["points"])
	_restart_left = Config.MATCH_RESTART_DELAY
	Events.match_ended.emit()
	Events.announce_requested.emit("L'évac a décollé ! Fin de la partie.", ANNOUNCE_COLOR)
	print("[Partie] Fin : %s" % [_results])
	_broadcast_clock()
	_show_results.rpc(_results, _restart_left)


## Nouvelle partie : chaque système de carte se remet à zéro (Events), puis les joueurs.
func _restart() -> void:
	Events.match_reset_requested.emit()
	for node in world.players.get_children():
		var player := node as Player
		if player:
			_reset_player(player)
	evacuated.clear()
	_results = []
	phase = Phase.PLAYING
	elapsed = 0.0
	_broadcast_clock()
	Events.announce_requested.emit("Nouvelle partie !", ANNOUNCE_COLOR)
	print("[Partie] Nouvelle partie")


func _reset_player(player: Player) -> void:
	player.set_evacuated.rpc(false)
	var pos := world.pick_spawn_point()
	player.global_position = pos
	player.teleport.rpc_id(player.get_peer_id(), pos)
	player.health.server_reset()
	player.inventory.server_reset()
	player.score.server_reset()
	player.weapon.server_refill()


## Un joueur arrive en cours de partie : horloge, joueurs déjà embarqués, classement.
## Petit délai : son client doit d'abord recevoir le monde et les joueurs.
func _on_player_joined(peer_id: int) -> void:
	await get_tree().create_timer(1.0).timeout
	if not peer_id in multiplayer.get_peers():
		return
	_sync_clock.rpc_id(peer_id, elapsed, phase)
	for id in evacuated:
		var player := world.get_player(id)
		if player:
			player.set_evacuated.rpc_id(peer_id, true)
	if phase == Phase.ENDED:
		_show_results.rpc_id(peer_id, _results, _restart_left)


func _broadcast_clock() -> void:
	_resync_left = Config.MATCH_CLOCK_RESYNC
	_sync_clock.rpc(elapsed, phase)


# =========================================================================
# Clients (et hôte)
# =========================================================================

@rpc("authority", "call_local", "reliable")
func _sync_clock(server_elapsed: float, server_phase: int) -> void:
	if not multiplayer.is_server():
		elapsed = server_elapsed
		phase = server_phase as Phase
	Events.match_clock_synced.emit(server_elapsed, server_phase)


@rpc("authority", "call_local", "reliable")
func _show_results(results: Array, restart_in: float) -> void:
	Events.match_results_received.emit(results, restart_in)
