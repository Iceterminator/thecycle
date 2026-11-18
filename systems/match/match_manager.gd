class_name MatchManager
extends Node
## Déroulé d'une partie (étape 6), décidé par le SERVEUR :
##   0:00 -> 19:10 : prospection (annonce de l'évac à 16:10) ; 19:10 : l'évac se pose ; 20:00 : décollage, fin de partie ;
##   écran de fin pendant Config.MATCH_RESTART_DELAY, puis nouvelle partie sur place.
## Créé en code par World sur tous les peers (même chemin partout, pour les RPC).
## Les clients reçoivent l'horloge (temps écoulé + phase) au début, à chaque changement
## et toutes les Config.MATCH_CLOCK_RESYNC s ; le HUD l'avance seul entre deux envois.
##
## Embarquement (voir EvacShip) : premier embarqué +EVAC_FIRST_BONUS, suivants
## +EVAC_OTHER_BONUS ; au décollage, les joueurs restés au sol perdent EVAC_MISSED_PENALTY.

## LOBBY (étape 9) : entre deux parties et au démarrage du serveur ; équipement, escouades,
## « prêt ». La partie démarre seulement quand tous les joueurs connectés sont prêts (pas de minuteur).
enum Phase { PLAYING, EVAC, ENDED, LOBBY }

static var _current: MatchManager

const ANNOUNCE_COLOR := Color(0.6, 0.85, 1.0)
const MONSTER_COLOR := Color(1.0, 0.5, 0.35)
const EVAC_COLOR := Color(1.0, 0.42, 0.38)  ## annonces de l'évac (bandeau rouge)

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
var _results: Array = []


func _ready() -> void:
	_current = self
	Events.match_clock_requested.connect(func() -> void: Events.match_clock_synced.emit(elapsed, phase))
	set_physics_process(multiplayer.is_server())
	set_process(not multiplayer.is_server())
	if not multiplayer.is_server():
		return
	Events.time_skip_requested.connect(func(seconds: float) -> void: _set_time(elapsed + seconds))
	Events.match_time_set_requested.connect(_set_time)
	Events.player_evacuated.connect(_on_player_evacuated)
	Events.player_joined.connect(_on_player_joined)
	Events.evac_pad_cleared.connect(_on_evac_pad_cleared)
	_broadcast_clock.call_deferred()


func _physics_process(delta: float) -> void:
	if phase == Phase.LOBBY:
		_server_lobby(delta)
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
	if phase != Phase.ENDED and phase != Phase.LOBBY:
		elapsed = minf(elapsed + delta, Config.MATCH_DURATION)


## Annonces : [temps (s), texte, couleur]. Déclenchées quand l'horloge franchit le temps.
func _announces() -> Array:
	var land := Config.EVAC_LANDING_TIME
	var end := Config.MATCH_DURATION
	return [
		[Config.EVAC_ANNOUNCE_TIME, "La navette d'évacuation arrivera dans %d secondes, au centre de la carte !" % roundi(land - Config.EVAC_ANNOUNCE_TIME), EVAC_COLOR],
		[end - 30.0, "Décollage de l'évac dans 30 secondes !", EVAC_COLOR],
		[end - 10.0, "Décollage dans 10 secondes !", EVAC_COLOR],
	]


## Fait avancer l'horloge jusqu'à `to` en déclenchant tout ce qui est franchi.
func _advance(to: float) -> void:
	var before := elapsed
	elapsed = minf(to, Config.MATCH_DURATION)
	for entry: Array in _announces():
		if before < entry[0] and elapsed >= entry[0]:
			Events.announce_requested.emit(entry[1], entry[2])
	if before < Config.EVAC_ANNOUNCE_TIME and elapsed >= Config.EVAC_ANNOUNCE_TIME:
		_set_pad_blocked(true)
		Events.evac_announced.emit()  # MonsterManager occupe la plateforme (ou la déclare libre)
		if pad_blocked:
			Events.announce_requested.emit("Des monstres occupent la plateforme d'évac : tuez-les pour que la navette puisse se poser !", EVAC_COLOR)
	if phase == Phase.PLAYING and pad_blocked and before < Config.EVAC_LANDING_TIME and elapsed >= Config.EVAC_LANDING_TIME:
		Events.announce_requested.emit("NAVETTE BLOQUÉE — NETTOYER LA PLATEFORME", EVAC_COLOR)
	if phase == Phase.PLAYING and not pad_blocked and elapsed >= Config.EVAC_LANDING_TIME:
		phase = Phase.EVAC
		Events.evac_landed.emit()
		Events.announce_requested.emit("L'évac se pose au centre ! Montez à bord par la rampe.", ANNOUNCE_COLOR)
		_broadcast_clock()
	# Niveau des monstres (1 au départ, puis 2 et 3 aux temps de Config).
	for i in Config.MONSTER_LEVEL_TIMES.size():
		var t: float = Config.MONSTER_LEVEL_TIMES[i]
		if before < t and elapsed >= t:
			Events.monster_level_changed.emit(i + 2)
			Events.announce_requested.emit("Les monstres passent au niveau %d : plus résistants, plus de crédits !" % (i + 2), MONSTER_COLOR)
	if before < Config.CRYSTAL_UPGRADE_TIME and elapsed >= Config.CRYSTAL_UPGRADE_TIME:
		Events.crystal_upgrade_requested.emit()
	if elapsed >= Config.MATCH_DURATION:
		_end_match()


## Menu admin : on ne peut qu'avancer (revenir en arrière défairait l'évac).
func _set_time(seconds: float) -> void:
	if phase == Phase.ENDED or phase == Phase.LOBBY or not is_finite(seconds) or seconds <= elapsed:
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
	var text := "%s a embarqué dans l'évac !" % ProfileManager.name_of(peer_id)
	if bonus > 0:
		text += " (premier à bord : +%d)" % bonus
	Events.announce_requested.emit(text, ANNOUNCE_COLOR)
	print("[Partie] Joueur %d embarqué (+%d)" % [peer_id, bonus])


func _set_pad_blocked(blocked: bool) -> void:
	pad_blocked = blocked
	_sync_pad.rpc(blocked)


## Contrat « Nettoyer la plateforme » rempli : Fame au tueur, la navette peut se poser
## (tout de suite si elle est déjà là, sinon à Config.EVAC_LANDING_TIME).
func _on_evac_pad_cleared(killer_id: int) -> void:
	if not pad_blocked or phase != Phase.PLAYING:
		return
	_set_pad_blocked(false)
	var killer := world.get_player(killer_id)
	if killer:
		killer.score.add_contract_fame(Config.EVAC_PAD_CLEAR_FAME)
		Events.announce_requested.emit("%s a nettoyé la plateforme d'évac ! (+%d)" % [ProfileManager.name_of(killer_id), Config.EVAC_PAD_CLEAR_FAME], EVAC_COLOR)
	else:
		Events.announce_requested.emit("La plateforme d'évac est dégagée !", EVAC_COLOR)
	_advance(elapsed)  # se pose tout de suite si l'heure est passée


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
	# Niveau 1 d'abord : les camps sont repeuplés pendant match_reset_requested.
	Events.monster_level_changed.emit(1)
	Events.match_reset_requested.emit()
	# Équipement du profil (choisi dans le lobby), puis largage : une escouade au même endroit.
	var profiles := world.get_node_or_null("ProfileManager") as ProfileManager
	var squad_spawns := {}
	var squad_index := {}
	for node in world.players.get_children():
		var player := node as Player
		if player == null:
			continue
		if profiles:
			profiles.server_apply_loadout(player.get_peer_id())
		var squad := SquadManager.squad_of(player.get_peer_id())
		var spawn := world.pick_spawn_point()
		if squad != 0:
			if not squad_spawns.has(squad):
				squad_spawns[squad] = spawn
			squad_index[squad] = int(squad_index.get(squad, 0)) + 1
			spawn = squad_spawns[squad] + Vector3(1.5 * (int(squad_index[squad]) - 1), 0, 0)
		_reset_player(player, spawn)
	ready_players = {}
	evacuated.clear()
	_set_pad_blocked(false)
	_results = []
	phase = Phase.PLAYING
	elapsed = 0.0
	_broadcast_clock()
	Events.announce_requested.emit("Nouvelle partie !", ANNOUNCE_COLOR)
	print("[Partie] Nouvelle partie")


func _reset_player(player: Player, pos: Vector3) -> void:
	player.set_evacuated.rpc(false)
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
	_sync_pad.rpc_id(peer_id, pad_blocked)
	if phase == Phase.LOBBY:
		_sync_lobby.rpc_id(peer_id, ready_players)
	for id in evacuated:
		var player := world.get_player(id)
		if player:
			player.set_evacuated.rpc_id(peer_id, true)
	if phase == Phase.ENDED:
		_show_results.rpc_id(peer_id, _results, _restart_left)


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

static func is_lobby() -> bool:
	return _current != null and _current.phase == Phase.LOBBY


## Serveur : décompte du lobby (seulement s'il y a des joueurs) ; départ quand tous sont prêts.
func _server_lobby(delta: float) -> void:
	var count := world.players.get_child_count()
	if count == 0:
		return
	var all_ready := true
	for node in world.players.get_children():
		if not ready_players.get((node as Player).get_peer_id(), false):
			all_ready = false
	_resync_left -= delta
	if _resync_left <= 0.0:
		_broadcast_clock()
	if all_ready:
		print("[Partie] Départ : les %d joueurs sont prêts" % count)
		_restart()


## Après l'écran de fin : retour au lobby (les joueurs restent dans le monde, sans dégâts).
func _enter_lobby() -> void:
	phase = Phase.LOBBY
	ready_players = {}
	for node in world.players.get_children():
		var player := node as Player
		if player:
			player.set_evacuated.rpc(false)
			player.health.server_reset()
	_broadcast_clock()
	Events.announce_requested.emit("Lobby : préparez votre équipement, la partie démarre quand tout le monde est prêt", ANNOUNCE_COLOR)


@rpc("any_peer", "call_local", "reliable")
func request_lobby_ready(value: bool) -> void:
	if not multiplayer.is_server() or phase != Phase.LOBBY:
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
