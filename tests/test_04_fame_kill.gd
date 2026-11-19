extends "res://tests/net_test_aides.gd"
## Fame d'un kill : l'hôte (pas allié, presque mort) est achevé par un tir du client.
## Serveur : mort de l'hôte, tueur = client, +player_kill_fame (economy.tres) au client.
## Client : sa Fame (Score.rank_points, synchronisée) a augmenté d'autant.

var _died: Array = []


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	var cid := client_id()
	events.player_died.connect(func(victim: int, killer: int) -> void: _died = [victim, killer])
	if not await start_match():
		return
	var me := player(1)
	var fame_before := player(cid).score.rank_points
	place(1, ground(SPOT_HOST))
	await wait(0.5)
	# Plus de bouclier, 1 PV : un tir suffit. Par apply_damage (attaquant 0 = personne) pour
	# relancer le délai de régénération.
	me.health.apply_damage(me.health.shield + me.health.health - 1.0, 0)
	me.health.shield = 0.0
	me.health.health = 1.0
	send_step("pret")
	if not await wait_until(func() -> bool: return me.health.is_dead, 10.0, "hôte tué par le tir du client"):
		return
	if not check(_died == [1, cid], "Events.player_died(hôte, client) : reçu %s" % [_died]):
		return
	if not check(player(cid).score.rank_points == fame_before + Config.economy.player_kill_fame, "Fame du tueur +%d (serveur : %d)" % [Config.economy.player_kill_fame, player(cid).score.rank_points]):
		return
	check(me.score.rank_points == 0, "la victime ne perd pas de Fame")
	await wait_step("fin_client")


func run_client() -> void:
	if not await start_match():
		return
	var host := player(1)
	var fame_before := local_player().score.rank_points
	if not await wait_step("pret"):
		return
	await move_self_and_settle(ground(SPOT_CLIENT))
	# Quelques tirs au plus (cadence respectée), jusqu'à la mort de l'hôte.
	for i in 5:
		if host.health.is_dead:
			break
		fire_at(chest(host))
		await wait(0.5)
	var expected := fame_before + Config.economy.player_kill_fame
	if not await wait_until(func() -> bool: return local_player().score.rank_points == expected, 5.0, "ma Fame reçue = %d (actuelle : %d)" % [expected, local_player().score.rank_points]):
		return
	send_step("fin_client")
