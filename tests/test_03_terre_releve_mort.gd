extends "res://tests/net_test_aides.gd"
## Escouade formée au lobby (SquadManager.request_create / request_join), puis en partie :
## l'hôte est mis à terre par un monstre (a un allié debout), le client le relève en
## maintenant E (Interactor), puis l'hôte meurt pour de bon et réapparaît (RespawnManager).

var _revived_by: int = 0


func squads() -> SquadManager:
	return world().get_node("SquadManager") as SquadManager


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	var cid := client_id()
	events.player_revived.connect(func(_peer: int, by_id: int) -> void: _revived_by = by_id)
	# --- Escouade : l'hôte la crée, le client la rejoint ---
	squads().request_create.rpc_id(1)
	if not await wait_until(func() -> bool: return SquadManager.same_squad(1, cid), 10.0, "le client a rejoint l'escouade de l'hôte"):
		return
	if not await start_match():
		return
	var me := player(1)
	place(1, ground(SPOT_HOST))
	await wait(0.5)
	# --- À terre ---
	me.health.apply_damage(99999.0, Config.MONSTER_KILLER_ID)
	if not check(me.health.is_downed and not me.health.is_dead, "avec un allié debout, l'hôte est à terre (pas mort)"):
		return
	send_step("a_terre")
	# --- Relevé par le client ---
	if not await wait_until(func() -> bool: return not me.health.is_downed, 15.0, "relevé par le client"):
		return
	if not check(_revived_by == cid, "Events.player_revived : relevé par le client (%d)" % _revived_by):
		return
	if not check(not me.health.is_dead and me.health.health > 0.0, "relevé avec des PV"):
		return
	send_step("releve")
	# --- Mort réelle : à terre puis achevé ---
	me.health.apply_damage(99999.0, Config.MONSTER_KILLER_ID)
	me.health.apply_damage(99999.0, Config.MONSTER_KILLER_ID)
	if not check(me.health.is_dead and not me.health.is_downed, "achevé à terre : l'hôte est mort"):
		return
	if not check(me.health.killer_id == Config.MONSTER_KILLER_ID, "tueur = monstre"):
		return
	# --- Réapparition ---
	if not await wait_until(func() -> bool: return not me.health.is_dead, 10.0, "réapparition de l'hôte"):
		return
	check(me.health.health == me.health.get_max_health(), "réapparu avec tous ses PV")
	await wait_step("fin_client")


func run_client() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2 and local_player() != null, 30.0, "2 joueurs dans le monde"):
		return
	if not await wait_until(func() -> bool: return SquadManager.squad_of(1) != 0, 10.0, "escouade de l'hôte reçue"):
		return
	squads().request_join.rpc_id(1, SquadManager.squad_of(1))
	if not await wait_until(func() -> bool: return SquadManager.same_squad(1, my_id()), 10.0, "je suis dans l'escouade de l'hôte"):
		return
	if not await start_match():
		return
	var host := player(1)
	if not await wait_step("a_terre"):
		return
	if not await wait_until(func() -> bool: return host.health.is_downed, 5.0, "état « à terre » de l'hôte reçu"):
		return
	# Juste à côté de l'hôte, puis E maintenu le temps de relever.
	await move_self_and_settle(ground(SPOT_HOST + Vector2(0.0, 1.5)))
	await hold_interact(host, Config.combat.revive_time)
	if not await wait_step("releve", 10.0):
		return
	if not await wait_until(func() -> bool: return host.health.is_dead, 5.0, "mort de l'hôte reçue"):
		return
	if not await wait_until(func() -> bool: return not host.health.is_dead, 10.0, "réapparition de l'hôte reçue"):
		return
	send_step("fin_client")
