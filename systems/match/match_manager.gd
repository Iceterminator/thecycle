class_name MatchManager
extends Node
## Déroulé d'une partie (étape 6), décidé par le SERVEUR (créé en code par World sur tous les peers) :
##   LOBBY (équipement, « prêt ») -> BRIEFING (salle 3D, match_briefing.gd) -> 0:00 largage ; 16:10 annonce
##   de l'évac ; 19:10 elle se pose ; 20:00 décollage, fin -> écran de fin -> LOBBY. Horloge envoyée
##   aux clients à chaque changement et toutes les Config.MATCH_CLOCK_RESYNC s ; bonus d'embarquement : EvacShip.
enum Phase { PLAYING, EVAC, ENDED, LOBBY, BRIEFING, SALLE_TEST }  ## SALLE_TEST : systems/salle_test/, sans horloge

static var _current: MatchManager

const ANNOUNCE_COLOR := Color(0.6, 0.85, 1.0)
const MONSTER_COLOR := Color(1.0, 0.5, 0.35)
const EVAC_COLOR := Color(1.0, 0.42, 0.38)  ## annonces de l'évac (bandeau rouge)
const MatchClock := preload("res://systems/match/match_clock.gd")
const MatchCycle := preload("res://systems/match/match_cycle.gd")
const MatchEvac := preload("res://systems/match/match_evac.gd")
const MatchBriefing := preload("res://systems/match/match_briefing.gd")

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
var briefing_left: float = 0.0  ## salle de briefing : secondes restantes
var briefing_votes: Array = []  ## peers ayant voté « départ »
var briefing_room: Array = []   ## peers dans la salle
var _drop_points: Dictionary = {}  # peer -> point de largage
## Serveur : clients connectés pendant une partie, sans joueur jusqu'au prochain lobby.
var waiting: Array[int] = []
var _waiting_screen: WaitingScreen
var _results: Array = []
var _clock: MatchClock
var _cycle: MatchCycle
var _evac: MatchEvac
var _briefing: MatchBriefing


func _ready() -> void:
	_clock = MatchClock.new(self)
	_cycle = MatchCycle.new(self)
	_evac = MatchEvac.new(self)
	_briefing = MatchBriefing.new(self)
	_current = self
	Events.match_clock_requested.connect(func() -> void: Events.match_clock_synced.emit(elapsed, phase))
	set_physics_process(multiplayer.is_server())
	set_process(not multiplayer.is_server())
	if not Net.is_dedicated_server:
		_waiting_screen = WaitingScreen.new()
		add_child(_waiting_screen)
	if not multiplayer.is_server():
		return
	Events.time_skip_requested.connect(func(seconds: float) -> void: _clock.set_time(elapsed + seconds))
	Events.match_time_set_requested.connect(_clock.set_time)
	Events.player_evacuated.connect(_evac.on_player_evacuated)
	Events.player_joined.connect(_cycle.on_player_joined)
	Events.player_left.connect(func(peer: int) -> void:
		waiting.erase(peer)
		_briefing.leave(peer))
	Events.evac_pad_cleared.connect(_evac.on_evac_pad_cleared)
	_broadcast_clock.call_deferred()


func _physics_process(delta: float) -> void:
	_cycle.server_tick(delta)


## Clients : copie locale de l'horloge, avancée entre deux envois du serveur.
func _process(delta: float) -> void:
	if phase == Phase.BRIEFING:
		briefing_left = maxf(briefing_left - delta, 0.0)
	elif phase != Phase.ENDED and phase != Phase.LOBBY:
		elapsed = minf(elapsed + delta, Config.match_rules.match_duration)


func _set_pad_blocked(blocked: bool) -> void:
	pad_blocked = blocked
	_sync_pad.rpc(blocked)


func _broadcast_clock() -> void:
	_resync_left = 1.0 if phase == Phase.LOBBY else Config.MATCH_CLOCK_RESYNC
	_sync_clock.rpc(elapsed, phase)
	if phase == Phase.LOBBY or phase == Phase.BRIEFING:
		_sync_lobby.rpc(ready_players)


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


## Serveur : un nouvel arrivant devient joueur au lobby ou pendant le briefing.
func accepts_new_players() -> bool:
	return phase in [Phase.LOBBY, Phase.BRIEFING, Phase.SALLE_TEST]


func add_waiting(peer_id: int) -> void:
	if not peer_id in waiting:
		waiting.append(peer_id)


@rpc("authority", "call_local", "reliable")
func _show_waiting(value: bool) -> void:
	if _waiting_screen:
		_waiting_screen.show_waiting(value)


static func is_briefing() -> bool:
	return _current != null and _current.phase == Phase.BRIEFING


static func is_lobby() -> bool:
	return _current != null and _current.phase == Phase.LOBBY


## Lobby : « prêt » ouvre la salle de briefing et y téléporte le joueur (MatchBriefing.on_ready).
@rpc("any_peer", "call_local", "reliable")
func request_lobby_ready(value: bool) -> void:
	if multiplayer.is_server():
		_briefing.on_ready(multiplayer.get_remote_sender_id(), value)


## Salle de briefing : vote « départ immédiat » (majorité des joueurs présents).
@rpc("any_peer", "call_local", "reliable")
func request_briefing_vote(value: bool) -> void:
	if multiplayer.is_server() and phase == Phase.BRIEFING:
		_briefing.vote(multiplayer.get_remote_sender_id(), value)


## Menu admin : lancer la partie (MatchBriefing.force_start).
func server_force_start() -> void:
	_briefing.force_start()


@rpc("authority", "call_local", "reliable")
func _sync_lobby(ready: Dictionary) -> void:
	if not multiplayer.is_server():
		ready_players = ready
	Events.lobby_synced.emit(ready)


@rpc("authority", "call_local", "reliable")
func _sync_briefing(left: float, votes: Array, room: Array) -> void:
	if not multiplayer.is_server():
		briefing_left = left
		briefing_votes = votes
		briefing_room = room
	Events.briefing_synced.emit(left, votes, room)


## Client : départ de la partie, points de largage (le sien et ceux de son escouade).
@rpc("authority", "call_local", "reliable")
func _show_drop(points: Array, seconds: float) -> void:
	Events.drop_phase_started.emit(points, seconds)
