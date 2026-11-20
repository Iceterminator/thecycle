extends "res://tests/net_test.gd"
## Connexion de 2 joueurs, profils chargés, lobby (prêts), salle de briefing (vote), capsules ouvertes.

var _drop_points: Array = []


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	if not check(phase() == MatchManager.Phase.LOBBY, "le serveur démarre au lobby"):
		return
	var cid := client_id()
	if not await wait_until(func() -> bool: return ProfileManager.name_of(cid) == "ZzTestClient", 10.0, "profil du client chargé"):
		return
	if not await start_match():
		return
	for p: Player in [player(1), player(cid)]:
		if not check(not p.is_dropping() and not p.health.is_dead, "joueur %d prêt à jouer" % p.get_peer_id()):
			return
	# Le chrono tourne.
	var t := match_manager().elapsed
	await wait(1.0)
	check(match_manager().elapsed > t, "le chrono de partie avance")


func run_client() -> void:
	events.drop_phase_started.connect(func(points: Array, _s: float) -> void: _drop_points = points)
	if not await start_match():
		return
	if not check(_drop_points.size() >= 1, "points de largage reçus avec le mien"):
		return
	check(int(_drop_points[0][0]) == my_id(), "le point de largage reçu est le mien")
	check(ProfileManager.name_of(1) == "ZzTestHote", "pseudo de l'hôte reçu")
