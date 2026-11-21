extends "res://tests/net_test_aides.gd"
## Tableau de contrats : le client reçoit 4 contrats sans doublon, en active 2, un 3e est refusé ;
## la réputation de faction n'est donnée que pour un contrat actif (la Fame, elle, l'est toujours) ;
## la Prime active rapporte bounty_kill_fame au tueur d'un joueur éliminé.


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	var cid := client_id()
	if not await start_match():
		return
	var board := ContractBoard.current
	if not await wait_until(func() -> bool: return board._offers.get(cid, PackedStringArray()).size() == config.match_rules.contracts_offered, 10.0, "contrats tirés pour le client"):
		return
	# Les offres tirées peuvent contenir Prime et Alpha (sans paliers) : on impose 4 contrats à paliers.
	var pool := _regular(board._pool)
	board._offers[cid] = PackedStringArray(pool.slice(0, config.match_rules.contracts_offered))
	board._send_state(cid)
	send_step("offres")
	var ids := _regular(board._offers[cid])
	if not check(ids.size() >= 3, "au moins 3 contrats hors Prime parmi les proposés"):
		return
	# Contrat NON actif : la Fame est gagnée, pas la réputation.
	var inactive := ContractBoard.track_of(ids[2])
	var rep_before := _rep(cid, inactive.faction)
	var fame_before := player(cid).score.rank_points
	player(cid).score.add_objective_points(inactive, inactive.threshold(0))
	check(player(cid).score.rank_points > fame_before, "Fame du palier gagnée sans contrat actif")
	check(_rep(cid, inactive.faction) == rep_before, "pas de réputation sans contrat actif")
	send_step("sans_actif")
	if not await wait_step("actifs"):
		return
	check(board._active[cid].size() == 2 and board._active[cid].has(ids[0]) and board._active[cid].has(ids[1]), "serveur : 2 contrats actifs, le 3e refusé")
	var active := ContractBoard.track_of(ids[0])
	rep_before = _rep(cid, active.faction)
	player(cid).score.add_objective_points(active, active.threshold(0))
	check(_rep(cid, active.faction) > rep_before, "réputation gagnée avec un contrat actif")
	# Prime : active, un kill rapporte player_kill_fame + bounty_kill_fame ; inactive, seulement player_kill_fame.
	board._active[cid] = PackedStringArray(["prime"])
	fame_before = player(cid).score.rank_points
	events.player_died.emit(1, cid)
	var expected: int = config.economy.player_kill_fame + config.economy.bounty_kill_fame
	check(player(cid).score.rank_points - fame_before == expected, "Prime active : +%d Fame au tueur" % expected)
	board._active[cid] = PackedStringArray()
	fame_before = player(cid).score.rank_points
	events.player_died.emit(1, cid)
	check(player(cid).score.rank_points - fame_before == config.economy.player_kill_fame, "sans Prime active : Fame de kill seulement")
	send_step("fin_host")
	await wait_step("fin_client")


func run_client() -> void:
	if not await start_match():
		return
	var board := ContractBoard.current
	if not await wait_step("offres"):
		return
	var wanted: int = config.match_rules.contracts_offered
	if not await wait_until(func() -> bool: return board.offered.size() == wanted, 10.0, "client : %d contrats proposés" % wanted):
		return
	var distinct := {}
	for id in board.offered:
		distinct[id] = true
	if not check(distinct.size() == wanted, "contrats sans doublon"):
		return
	if not await wait_step("sans_actif"):
		return
	var ids := _regular(board.offered)
	board.request_activate.rpc_id(1, ids[0])
	board.request_activate.rpc_id(1, ids[1])
	if not await wait_until(func() -> bool: return board.active.size() == 2, 5.0, "2 contrats actifs reçus"):
		return
	board.request_activate.rpc_id(1, ids[2])
	await wait(1.0)
	check(board.active.size() == 2 and not board.active.has(ids[2]), "client : le 3e contrat est refusé")
	send_step("actifs")
	await wait_step("fin_host")
	send_step("fin_client")


## Contrats proposés hors Prime et Alpha (sans paliers de Fame).
func _regular(list: PackedStringArray) -> Array[String]:
	var result: Array[String] = []
	for id in list:
		if id != ContractBoard.PRIME_ID and id != "alpha":
			result.append(id)
	return result


func _rep(peer: int, faction: int) -> int:
	return int(ProfileManager._current.server_profile(peer)["rep"].get(str(faction), 0))
