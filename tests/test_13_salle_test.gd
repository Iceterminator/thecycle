extends "res://tests/net_test_aides.gd"
## Salle de test : au lobby il n'y a que la salle de briefing (pas de carte) ; le client demande la
## salle de test (Niveaux.request_salle_test) -> phase SALLE_TEST, salle construite des deux côtés,
## salle de briefing supprimée, objets de l'armurerie et monstres figés posés par le serveur ; le
## client ramasse une capacité ; le téléporteur (Interactor) ramène tout le monde au lobby.

const Plan := preload("res://systems/salle_test/salle_test_plan.gd")


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	if not check(not world().niveaux.carte_construite() and world().has_node("BriefingRoom"), "lobby : salle de briefing seule, pas de carte"):
		return
	if not await wait_until(func() -> bool: return phase() == MatchManager.Phase.SALLE_TEST, 15.0, "phase salle de test"):
		return
	var attendus := Plan.armurerie().size()
	if not await wait_until(func() -> bool: return _objets_salle() >= attendus, 10.0, "%d objets posés dans l'armurerie" % attendus):
		return
	var monstres_attendus := Plan.bestiaire().size()
	if not await wait_until(func() -> bool: return monsters().size() == monstres_attendus, 10.0, "%d monstres figés" % monstres_attendus):
		return
	var m := monsters()[0]
	var pos := m.global_position
	await wait(1.5)
	if not check(m.global_position.distance_to(pos) < 0.05, "monstre figé (n'a pas bougé)"):
		return
	if not await wait_step("fin_client", 60.0):
		return
	check(monsters().is_empty() and _objets_salle() == 0, "retour au lobby : monstres et objets retirés")


func run_client() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2 and local_player() != null, 30.0, "2 joueurs dans le monde"):
		return
	await wait(1.0)
	world().niveaux.request_salle_test.rpc_id(1)
	if not await wait_until(func() -> bool: return world().has_node("SalleTest") and not world().has_node("BriefingRoom"), 10.0, "salle de test construite, briefing supprimé"):
		return
	if not await wait_until(func() -> bool: return local_player().global_position.distance_to(SalleTest.ORIGIN) < 20.0, 10.0, "client téléporté dans la salle"):
		return
	# Ramasse une capacité de l'armurerie.
	if not await wait_until(func() -> bool: return _capacite() != null, 10.0, "une capacité au sol"):
		return
	var capa := _capacite()
	var id := String(capa.item.id)
	await move_self_and_settle(capa.global_position + Vector3(1.0, 0.3, 0.0))
	await hold_interact(capa, 0.0)
	if not await wait_until(func() -> bool: return local_player().abilities.pending == id, 5.0, "capacité ramassée (attend Q / F)"):
		return
	# Téléporteur : retour au lobby.
	var sortie := world().get_node("SalleTest/Sortie") as Node3D
	await move_self_and_settle(sortie.global_position + Vector3(1.5, 0.5, 0.0))
	await hold_interact(sortie, 0.0)
	if not await wait_until(func() -> bool: return phase() == MatchManager.Phase.LOBBY and world().has_node("BriefingRoom") and not world().has_node("SalleTest"), 10.0, "retour au lobby (salle de test supprimée)"):
		return
	send_step("fin_client")


func _objets_salle() -> int:
	var n := 0
	for node in world().get_node("Loot").get_children():
		if node is Pickup and (node as Pickup).global_position.distance_to(SalleTest.ORIGIN) < 150.0:
			n += 1
	return n


func _capacite() -> Pickup:
	for node in world().get_node("Loot").get_children():
		if node is Pickup and (node as Pickup).item.kind == ItemData.Kind.ABILITY and not (node as Pickup).is_taken():
			return node
	return null
