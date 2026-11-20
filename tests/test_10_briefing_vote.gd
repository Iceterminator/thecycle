extends "res://tests/net_test_aides.gd"
## Salle de briefing : le premier prêt ouvre la salle (quêtes tirées), on y est téléporté ;
## le second joueur, encore au lobby, la rejoint ; un vote sur 2 ne suffit pas, 2 sur 2 font partir.


func _in_room(p: Player) -> bool:
	return p != null and p.global_position.distance_to(BriefingRoom.ORIGIN) < 20.0


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	await wait(1.0)
	match_manager().request_lobby_ready.rpc_id(1, true)
	if not await wait_until(func() -> bool: return phase() == MatchManager.Phase.BRIEFING, 10.0, "salle ouverte au premier prêt"):
		return
	if not await wait_until(func() -> bool: return _in_room(player(1)), 10.0, "hôte téléporté dans la salle"):
		return
	send_step("salle_ouverte")
	if not await wait_until(func() -> bool: return match_manager().briefing_room.size() == 2, 20.0, "client entré dans la salle"):
		return
	match_manager().request_briefing_vote.rpc_id(1, true)
	await wait(1.5)
	if not check(phase() == MatchManager.Phase.BRIEFING, "1 vote sur 2 : pas de départ"):
		return
	send_step("vote_hote")
	if not await wait_until(func() -> bool: return phase() == MatchManager.Phase.PLAYING, 10.0, "départ au vote 2 / 2"):
		return
	if not check(match_manager().briefing_left > 5.0, "départ avant la fin du compte à rebours"):
		return
	await wait_step("fin_client")


func run_client() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2 and local_player() != null, 30.0, "2 joueurs dans le monde"):
		return
	if not await wait_step("salle_ouverte"):
		return
	if not check(not my_id() in match_manager().briefing_room, "pas encore dans la salle (pas prêt)"):
		return
	var quests := world().get_node_or_null("QuestManager") as QuestManager
	if not await wait_until(func() -> bool: return quests != null and not quests.drawn_list.is_empty(), 10.0, "quêtes tirées à l'ouverture de la salle"):
		return
	match_manager().request_lobby_ready.rpc_id(1, true)
	if not await wait_until(func() -> bool: return _in_room(local_player()) and my_id() in match_manager().briefing_room, 10.0, "téléporté dans la salle"):
		return
	if not check(local_player().is_dropping(), "pas de tir ni de dégâts dans la salle"):
		return
	if not await wait_step("vote_hote"):
		return
	match_manager().request_briefing_vote.rpc_id(1, true)
	if not await wait_until(func() -> bool: return phase() == MatchManager.Phase.PLAYING, 10.0, "départ au vote"):
		return
	send_step("fin_client")
