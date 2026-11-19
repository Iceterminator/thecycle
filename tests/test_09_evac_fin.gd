extends "res://tests/net_test_aides.gd"
## Évac et fin de partie :
## - le client avance l'horloge (Admin.request_time_set) après l'annonce : des monstres
##   bloquent la plateforme ; l'hôte les tue au nom du client -> Events.evac_pad_cleared,
##   +evac_pad_clear_fame au client ;
## - heure d'atterrissage : la navette se pose (EvacShip LANDED) ; le client monte dans la
##   soute et embarque après evac_board_time (Player.is_evacuated) ;
## - fin (Events.match_time_set_requested côté serveur) : le client reçoit
##   Events.match_results_received (lui embarqué, l'hôte pénalisé), puis retour au LOBBY.

var _cleared_by: int = 0
var _results: Array = []


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	var cid := client_id()
	events.evac_pad_cleared.connect(func(killer: int) -> void: _cleared_by = killer)
	if not await start_match():
		return
	var rules := config.match_rules as MatchRules
	place(1, ground(Vector2(-25.0, -45.0)))  # l'hôte reste au sol, loin de l'évac et des camps
	send_step("pret")
	# Annonce de l'évac : la plateforme est occupée.
	if not await wait_until(func() -> bool: return match_manager().elapsed >= rules.evac_announce_time, 10.0, "horloge avancée après l'annonce de l'évac"):
		return
	var pad_monsters := monsters_near(Config.EVAC_POSITION, 12.0)
	if not check(match_manager().pad_blocked and not pad_monsters.is_empty(), "plateforme bloquée par %d monstres" % pad_monsters.size()):
		return
	for m in pad_monsters:
		kill_monster(m, cid)
	if not check(_cleared_by == cid and not match_manager().pad_blocked, "Events.evac_pad_cleared(client) : reçu %d" % _cleared_by):
		return
	send_step("degagee")
	# Atterrissage puis embarquement du client.
	if not await wait_until(func() -> bool: return match_manager().phase == MatchManager.Phase.EVAC, 10.0, "phase EVAC"):
		return
	if not await wait_until(func() -> bool: return cid in match_manager().evacuated, Config.EVAC_FLIGHT_TIME + rules.evac_board_time + 15.0, "client embarqué"):
		return
	if not check(player(cid).is_evacuated and not player(1).is_evacuated, "seul le client est à bord"):
		return
	# Fin de partie.
	events.match_time_set_requested.emit(rules.match_duration)
	if not check(match_manager().phase == MatchManager.Phase.ENDED, "partie finie"):
		return
	check(player(1).score.rank_points == -Config.economy.evac_missed_penalty, "hôte resté au sol : -%d" % Config.economy.evac_missed_penalty)
	if not await wait_until(func() -> bool: return MatchManager.is_lobby(), rules.match_restart_delay + 5.0, "retour au lobby"):
		return
	await wait_step("fin_client")


func run_client() -> void:
	events.match_results_received.connect(func(results: Array, _restart_in: float) -> void: _results = results)
	if not await start_match():
		return
	var rules := config.match_rules as MatchRules
	var me := local_player()
	if not await wait_step("pret"):
		return
	me.admin.request_time_set.rpc_id(1, rules.evac_announce_time + 5.0)
	if not await wait_step("degagee"):
		return
	if not await wait_until(func() -> bool: return me.score.rank_points == Config.economy.evac_pad_clear_fame, 5.0, "Fame du nettoyage de la plateforme reçue"):
		return
	me.admin.request_time_set.rpc_id(1, rules.evac_landing_time + 1.0)
	var ship := world().evac_ship
	if not await wait_until(func() -> bool: return ship.state == EvacShip.State.LANDED, Config.EVAC_FLIGHT_TIME + 5.0, "navette posée"):
		return
	# Dans la soute (plancher à 1,5 m au-dessus de la navette).
	move_self(ship.global_position + Vector3(0.0, 1.7, 0.0))
	if not await wait_until(func() -> bool: return me.is_evacuated, rules.evac_board_time + 5.0, "embarqué (is_evacuated)"):
		return
	if not await wait_until(func() -> bool: return not _results.is_empty(), 15.0, "résultats de fin reçus"):
		return
	var mine: Dictionary = {}
	var host: Dictionary = {}
	for entry: Dictionary in _results:
		if int(entry["peer"]) == my_id():
			mine = entry
		elif int(entry["peer"]) == 1:
			host = entry
	if not check(mine.get("evacuated", false) == true, "résultats : je suis embarqué (%s)" % [mine]):
		return
	var expected := Config.economy.evac_pad_clear_fame + Config.economy.evac_first_bonus
	if not check(int(mine.get("points", 0)) == expected, "résultats : mes points = %d (%s)" % [expected, mine]):
		return
	if not check(host.get("evacuated", true) == false and int(host.get("points", 0)) == -Config.economy.evac_missed_penalty, "résultats : l'hôte au sol, pénalisé (%s)" % [host]):
		return
	if not await wait_until(func() -> bool: return phase() == MatchManager.Phase.LOBBY, rules.match_restart_delay + 5.0, "retour au lobby"):
		return
	check(not me.is_evacuated, "au lobby, je ne suis plus à bord")
	send_step("fin_client")
