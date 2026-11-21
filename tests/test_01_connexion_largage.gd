extends "res://tests/net_test.gd"
## Connexion de 2 joueurs, profils chargés, mod de kit « Boucliers renforcés » (+100 de bouclier max
## côté serveur), lobby (prêts), salle de briefing (vote), capsules ouvertes.

var _drop_points: Array = []


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	if not check(phase() == MatchManager.Phase.LOBBY, "le serveur démarre au lobby"):
		return
	var cid := client_id()
	if not await wait_until(func() -> bool: return ProfileManager.name_of(cid) == "ZzTestClient", 10.0, "profil du client chargé"):
		return
	# Le client choisit « Boucliers renforcés » (niveau 2) : le serveur doit le voir dans le bouclier max.
	var kit := player(cid).kit
	var base_shield: float = kit.get_kit().shield if kit.get_kit().shield > 0.0 else config.combat.kit_default_shield
	if not await wait_until(func() -> bool: return is_equal_approx(player(cid).health.max_shield, base_shield + 100.0), 10.0, "bouclier max +100 (mod Boucliers renforcés)"):
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
	if not await wait_until(func() -> bool: return ProfileManager.name_of(my_id()) == "ZzTestClient", 10.0, "mon profil chargé"):
		return
	var profiles := world().get_node("ProfileManager") as ProfileManager
	profiles.request_set_loadout.rpc_id(1, {"kit": String(config.start_loadout.default_kit), "kit_mod": {"2": "stronger_shields"},
			"start_weapon": String(config.start_loadout.base_weapon), "shop": {"weapons": [], "gadgets": []}}, 0)
	if not await start_match():
		return
	if not check(_drop_points.size() >= 1, "points de largage reçus avec le mien"):
		return
	check(int(_drop_points[0][0]) == my_id(), "le point de largage reçu est le mien")
	check(ProfileManager.name_of(1) == "ZzTestHote", "pseudo de l'hôte reçu")
