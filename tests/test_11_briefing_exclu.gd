extends "res://tests/net_test_aides.gd"
## Salle de briefing : un joueur resté au lobby n'entre pas dans la partie. L'hôte seul vote
## (1 / 1 = majorité) : la partie part, le client perd son joueur et attend la partie suivante.


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	await wait(1.0)
	var cid := client_id()
	match_manager().request_lobby_ready.rpc_id(1, true)
	if not await wait_until(func() -> bool: return match_manager().briefing_room.size() == 1, 10.0, "hôte dans la salle"):
		return
	match_manager().request_briefing_vote.rpc_id(1, true)
	if not await wait_until(func() -> bool: return phase() == MatchManager.Phase.PLAYING, 10.0, "départ au vote 1 / 1"):
		return
	if not await wait_until(func() -> bool: return player(cid) == null, 5.0, "joueur du client retiré"):
		return
	check(cid in match_manager().waiting, "client en attente de la partie suivante")
	send_step("verifie")  # le client attend cette vérification avant de quitter (sinon il est déjà déconnecté)
	if not await wait_step("fin_client"):
		return


func run_client() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2 and local_player() != null, 30.0, "2 joueurs dans le monde"):
		return
	if not await wait_until(func() -> bool: return phase() == MatchManager.Phase.PLAYING, 30.0, "partie lancée sans moi"):
		return
	if not await wait_until(func() -> bool: return local_player() == null, 5.0, "plus de joueur local"):
		return
	var waiting: WaitingScreen = null
	for child in match_manager().get_children():
		if child is WaitingScreen:
			waiting = child
	if not await wait_until(func() -> bool: return waiting == null or waiting.visible, 5.0, "écran d'attente affiché"):
		return
	if not await wait_step("verifie"):
		return
	send_step("fin_client")
