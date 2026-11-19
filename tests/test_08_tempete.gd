extends "res://tests/net_test_aides.gd"
## Tempête (Grande Marée) : le client avance l'horloge avec le menu admin
## (Admin.request_time_set) juste avant la première phase de data/storm/, puis dedans.
## Avant : pas de tempête, avertissement (next_in). Après : Events.storm_started côté serveur,
## StormManager.is_in_storm vrai des deux côtés. La tempête ne blesse pas (pas de zone).

var _storm_shards: int = -1


func first_phase() -> StormPhaseData:
	var storm := world().get_node("StormManager") as StormManager
	return storm.phases[0] if not storm.phases.is_empty() else null


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	events.storm_started.connect(func(count: int) -> void: _storm_shards = count)
	if not await start_match():
		return
	var phase := first_phase()
	if not check(phase != null, "au moins une phase de tempête dans data/storm/"):
		return
	place(1, ground(SPOT_HOST))
	if not await wait_step("avant"):
		return
	if not check(not StormManager.is_in_storm(Vector3.ZERO) and _storm_shards == -1, "serveur : pas encore de tempête"):
		return
	var me := player(1)
	var health_before := me.health.health + me.health.shield
	send_step("ok_avant")
	if not await wait_until(func() -> bool: return _storm_shards >= 0, 10.0, "Events.storm_started"):
		return
	if not check(_storm_shards == phase.shard_count and StormManager.is_in_storm(Vector3.ZERO), "serveur : tempête active (%d éclats)" % _storm_shards):
		return
	await wait(2.0)
	check(me.health.health + me.health.shield >= health_before, "la tempête ne blesse pas")
	await wait_step("fin_client")


func run_client() -> void:
	if not await start_match():
		return
	var phase := first_phase()
	if not check(phase != null, "au moins une phase de tempête dans data/storm/"):
		return
	var storm := world().get_node("StormManager") as StormManager
	var admin := local_player().admin
	# Juste avant la tempête, dans la fenêtre d'avertissement.
	var before_time := phase.start_time - phase.warning_time * 0.5
	admin.request_time_set.rpc_id(1, before_time)
	if not await wait_until(func() -> bool: return match_manager().elapsed >= before_time, 5.0, "horloge reçue à %d s" % before_time):
		return
	var s := storm.compute_state(match_manager().elapsed)
	if not check(not s["active"] and s["next_in"] > 0.0, "avant : avertissement sans tempête (%s)" % [s]):
		return
	if not check("débute" in StormManager.hud_text(Vector3.ZERO), "avant : texte du HUD « débute dans »"):
		return
	send_step("avant")
	if not await wait_step("ok_avant"):
		return
	admin.request_time_set.rpc_id(1, phase.start_time + 1.0)
	if not await wait_until(func() -> bool: return StormManager.is_in_storm(local_player().global_position), 5.0, "client : tempête active"):
		return
	check(storm.compute_state(match_manager().elapsed)["active"], "client : compute_state actif")
	send_step("fin_client")
