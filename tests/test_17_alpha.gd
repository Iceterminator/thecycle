extends "res://tests/net_test_aides.gd"
## Boss Alpha : à alpha_time l'Alpha apparaît (8000 PV, sans niveau de monstre) et les deux côtés le voient.
## Les dégâts sont infligés par le serveur au nom du client (8000 PV : trop long par tirs). Chaque tranche de 25 %
## des PV max infligés rapporte 25 Fame ; l'achever donne 25 de plus (125 au total) et lâche une biomasse or (450).


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	var cid := client_id()
	if not await start_match():
		return
	var board := ContractBoard.current
	check(board._pool.has("alpha") and board._pool.has("surtension"), "alpha et surtension dans les objectifs de la partie")
	var rules: MatchRules = config.match_rules
	events.match_time_set_requested.emit(rules.alpha_time + 1.0)
	if not await wait_until(func() -> bool: return _alpha() != null, 10.0, "l'Alpha apparaît"):
		return
	var boss := _alpha()
	if not check(is_equal_approx(boss.max_health, 8000.0), "Alpha : 8000 PV, sans niveau de monstre (%.0f)" % boss.max_health):
		return
	send_step("alpha", String(boss.name))
	if not await wait_step("alpha_vu"):  # le client voit l'Alpha avant qu'on l'achève (sinon apparition et mort partent dans la même image)
		return
	var fame := player(cid).score.rank_points
	boss.server_receive_hit(1900.0, cid)
	check(player(cid).score.rank_points == fame, "1900 PV infligés : pas encore de tranche")
	boss.server_receive_hit(100.0, cid)
	check(player(cid).score.rank_points == fame + 25, "25 % infligés : +25 Fame")
	boss.server_receive_hit(5900.0, cid)
	check(player(cid).score.rank_points == fame + 75, "75 % infligés : +75 Fame au total")
	boss.server_receive_hit(100.0, cid)  # dernier coup : tranche de 100 % + coup fatal
	if not check(player(cid).score.rank_points == fame + 125, "Alpha achevé : 125 Fame au maximum (%d)" % (player(cid).score.rank_points - fame)):
		return
	await wait(0.5)
	check(_alpha() == null, "l'Alpha est mort")
	check(_gold_biomass(), "échantillon de biomasse or (450) lâché")
	send_step("mort")
	await wait_step("fin_client")


func run_client() -> void:
	if not await start_match():
		return
	if not await wait_step("alpha"):
		return
	var path := "Monsters/" + step_value("alpha")
	if not await wait_until(func() -> bool: return world().has_node(path), 5.0, "Alpha reçu (%s)" % path):
		return
	var boss := world().get_node(path) as Monster
	check(boss.data.id == &"alpha" and is_equal_approx(boss.max_health, 8000.0), "client : Alpha de 8000 PV")
	send_step("alpha_vu")
	if not await wait_step("mort"):
		return
	if not await wait_until(func() -> bool: return local_player().score.rank_points >= 125, 5.0, "client : Fame de l'Alpha reçue"):
		return
	send_step("fin_client")


func _alpha() -> Monster:
	for m in monsters():
		if m.data.id == &"alpha":
			return m
	return null


func _gold_biomass() -> bool:
	for node in world().get_node("Loot").get_children():
		var pickup := node as Pickup
		if pickup and pickup.item.id == &"biomass" and pickup.amount == 450:
			return true
	return false
