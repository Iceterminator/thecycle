class_name MatchManager
extends Node
## Déroulé d'une partie (étape 6), décidé par le SERVEUR :
##   0:00 -> 19:10 : prospection (annonce de l'évac à 16:10) ; 19:10 : l'évac se pose ; 20:00 : décollage, fin de partie ;
##   écran de fin pendant Config.match_rules.match_restart_delay, puis nouvelle partie sur place.
## Créé en code par World sur tous les peers (même chemin partout, pour les RPC).
## Les clients reçoivent l'horloge (temps écoulé + phase) au début, à chaque changement
## et toutes les Config.MATCH_CLOCK_RESYNC s ; le HUD l'avance seul entre deux envois.
##
## Embarquement (voir EvacShip) : premier embarqué +EVAC_FIRST_BONUS, suivants
## +EVAC_OTHER_BONUS ; au décollage, les joueurs restés au sol perdent EVAC_MISSED_PENALTY.

## LOBBY (étape 9) : entre deux parties et au démarrage du serveur ; équipement, escouades,
## « prêt ». La partie démarre seulement quand tous les joueurs connectés sont prêts (pas de minuteur).
## DROP : écran de largage (carte + quêtes), puis chute en capsule ; le chrono démarre à la fin de l'écran.
enum Phase { PLAYING, EVAC, ENDED, LOBBY, DROP }

static var _current: MatchManager

const ANNOUNCE_COLOR := Color(0.6, 0.85, 1.0)
const MONSTER_COLOR := Color(1.0, 0.5, 0.35)
const EVAC_COLOR := Color(1.0, 0.42, 0.38)  ## annonces de l'évac (bandeau rouge)
const MatchClock := preload("res://systems/match/match_clock.gd")
const MatchCycle := preload("res://systems/match/match_cycle.gd")
const MatchEvac := preload("res://systems/match/match_evac.gd")

@onready var world: World = get_parent()

var phase: Phase = Phase.LOBBY
## Lobby : joueurs prêts (peer -> true) et secondes avant le départ.
var ready_players: Dictionary = {}
var elapsed: float = 0.0
## Serveur : ids des joueurs embarqués, dans l'ordre.
var evacuated: Array[int] = []
## Des monstres occupent la plateforme d'évac : la navette ne peut pas se poser (copié chez les clients).
var pad_blocked: bool = false

var _resync_left: float = 0.0
var _restart_left: float = 0.0
var _drop_left: float = 0.0
var _drop_points: Dictionary = {}  # peer -> point de largage
## Serveur : clients connectés pendant une partie, sans joueur jusqu'au prochain lobby.
var waiting: Array[int] = []
var _waiting_screen: WaitingScreen
var _results: Array = []
var _clock: MatchClock
var _cycle: MatchCycle
var _evac: MatchEvac


func _ready() -> void:
	_clock = MatchClock.new(self)
	_cycle = MatchCycle.new(self)
	_evac = MatchEvac.new(self)
	_current = self
	Events.match_clock_requested.connect(func() -> void: Events.match_clock_synced.emit(elapsed, phase))
	set_physics_process(multiplayer.is_server())
	set_process(not multiplayer.is_server())
	if not multiplayer.is_server():
		_waiting_screen = WaitingScreen.new()
		add_child(_waiting_screen)
	if not multiplayer.is_server():
		return
	Events.time_skip_requested.connect(func(seconds: float) -> void: _set_time(elapsed + seconds))
	Events.match_time_set_requested.connect(_set_time)
	Events.player_evacuated.connect(_on_player_evacuated)
	Events.player_joined.connect(_on_player_joined)
	Events.player_left.connect(func(peer: int) -> void: waiting.erase(peer))
	Events.evac_pad_cleared.connect(_on_evac_pad_cleared)
	_broadcast_clock.call_deferred()


func _physics_process(delta: float) -> void:
	if phase == Phase.LOBBY:
		_server_lobby(delta)
		return
	if phase == Phase.DROP:
		_drop_left -= delta
		if _drop_left <= 0.0:
			_begin_drop()
		return
	if phase == Phase.ENDED:
		_restart_left -= delta
		if _restart_left <= 0.0:
			_enter_lobby()
		return
	_advance(elapsed + delta)
	_resync_left -= delta
	if _resync_left <= 0.0:
		_broadcast_clock()


## Clients : copie locale de l'horloge, avancée entre deux envois du serveur.
func _process(delta: float) -> void:
	if phase != Phase.ENDED and phase != Phase.LOBBY and phase != Phase.DROP:
		elapsed = minf(elapsed + delta, Config.match_rules.match_duration)


## Fait avancer l'horloge jusqu'à `to` en déclenchant tout ce qui est franchi.
func _advance(to: float) -> void:
	_clock.advance(to)


## Menu admin : on ne peut qu'avancer (revenir en arrière défairait l'évac).
func _set_time(seconds: float) -> void:
	if phase == Phase.ENDED or phase == Phase.LOBBY or phase == Phase.DROP or not is_finite(seconds) or seconds <= elapsed:
		return
	_advance(seconds)
	if phase != Phase.ENDED:
		_broadcast_clock()


func _on_player_evacuated(peer_id: int) -> void:
	_evac.on_player_evacuated(peer_id)


func _set_pad_blocked(blocked: bool) -> void:
	pad_blocked = blocked
	_sync_pad.rpc(blocked)


func _on_evac_pad_cleared(killer_id: int) -> void:
	_evac.on_evac_pad_cleared(killer_id)


func _end_match() -> void:
	_cycle.end_match()


## Nouvelle partie : remise à zéro puis phase LARGAGE (voir MatchCycle.restart).
func _restart() -> void:
	_cycle.restart()


## Fin de l'écran de largage : la partie démarre, chacun descend dans sa capsule.
func _begin_drop() -> void:
	_cycle.begin_drop()


## Un joueur arrive en cours de partie : horloge, joueurs déjà embarqués, classement.
## Petit délai : son client doit d'abord recevoir le monde et les joueurs.
func _on_player_joined(peer_id: int) -> void:
	await get_tree().create_timer(1.0).timeout
	if not peer_id in multiplayer.get_peers():
		return
	_cycle.sync_new_player(peer_id)


func _broadcast_clock() -> void:
	_resync_left = 1.0 if phase == Phase.LOBBY else Config.MATCH_CLOCK_RESYNC
	_sync_clock.rpc(elapsed, phase)
	if phase == Phase.LOBBY:
		_sync_lobby.rpc(ready_players)


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
func _sync_pad(blocked: bool) -> void:
	pad_blocked = blocked


## HUD : la plateforme d'évac est-elle occupée par des monstres ?
static func is_pad_blocked() -> bool:
	return _current != null and _current.pad_blocked


@rpc("authority", "call_local", "reliable")
func _show_results(results: Array, restart_in: float) -> void:
	Events.match_results_received.emit(results, restart_in)


# =========================================================================
# Lobby (étape 9)
# =========================================================================

## Serveur : un nouvel arrivant devient joueur seulement au lobby.
func accepts_new_players() -> bool:
	return phase == Phase.LOBBY


func add_waiting(peer_id: int) -> void:
	if not peer_id in waiting:
		waiting.append(peer_id)


@rpc("authority", "call_local", "reliable")
func _show_waiting(value: bool) -> void:
	if _waiting_screen:
		_waiting_screen.show_waiting(value)


static func is_drop_phase() -> bool:
	return _current != null and _current.phase == Phase.DROP


static func is_lobby() -> bool:
	return _current != null and _current.phase == Phase.LOBBY


## Serveur : décompte du lobby (seulement s'il y a des joueurs) ; départ quand tous sont prêts.
func _server_lobby(delta: float) -> void:
	_cycle.server_lobby(delta)


## Après l'écran de fin : retour au lobby (les joueurs restent dans le monde, sans dégâts).
func _enter_lobby() -> void:
	_cycle.enter_lobby()


@rpc("any_peer", "call_local", "reliable")
func request_lobby_ready(value: bool) -> void:
	if not multiplayer.is_server() or phase != Phase.LOBBY or world.get_player(multiplayer.get_remote_sender_id()) == null:
		return
	var d := ready_players.duplicate()
	d[multiplayer.get_remote_sender_id()] = value
	ready_players = d
	_broadcast_clock()


## Menu admin : lancer la partie tout de suite.
func server_force_start() -> void:
	if phase == Phase.LOBBY:
		_restart()


@rpc("authority", "call_local", "reliable")
func _sync_lobby(ready: Dictionary) -> void:
	if not multiplayer.is_server():
		ready_players = ready
	Events.lobby_synced.emit(ready)


## Client : écran de largage (points visibles : le sien et ceux de son escouade).
@rpc("authority", "call_local", "reliable")
func _show_drop(points: Array, seconds: float) -> void:
	Events.drop_phase_started.emit(points, seconds)
