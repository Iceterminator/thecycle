extends "res://tests/net_test_aides.gd"
## Tir validé par le serveur : le client tire (Weapon.request_fire) sur l'hôte placé devant lui.
## - au lobby : le tir est traité (munition consommée) mais ne blesse personne ;
## - en partie : l'hôte perd du bouclier ;
## - tir demandé avec l'arme d'un autre joueur : refusé (ni dégâts, ni munition).


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	var cid := client_id()
	var me := player(1)
	var target := player(cid)
	# --- Lobby ---
	place(1, BriefingRoom.spawn_point(0))  # lobby : pas de carte, on est dans la salle de briefing
	await wait(0.5)
	send_step("lobby_place")
	if not await wait_step("lobby_tir"):
		return
	await wait(1.0)
	if not check(target.inventory.get_active_ammo() < target.magazine_for(target.weapon.data), "lobby : le tir du client a été traité (munition consommée)"):
		return
	if not check(me.health.shield == me.health.max_shield and me.health.health == me.health.get_max_health(), "lobby : l'hôte n'a pris aucun dégât"):
		return
	send_step("lobby_verifie")
	# --- Partie ---
	if not await start_match():
		return
	place(1, ground(SPOT_HOST))
	await wait(0.5)
	var shield_before := me.health.shield
	var health_before := me.health.health
	send_step("place")
	if not await wait_step("tir"):
		return
	if not await wait_until(func() -> bool: return me.health.shield < shield_before or me.health.health < health_before, 5.0, "dégâts du tir du client sur l'hôte"):
		return
	if not check(me.health.shield < shield_before, "le bouclier absorbe d'abord (bouclier %.0f -> %.0f)" % [shield_before, me.health.shield]):
		return
	if not check(not me.health.is_dead, "l'hôte survit à un tir"):
		return
	send_step("touche")
	# --- Tir usurpé : le client demande un tir avec l'arme de l'hôte ---
	var my_ammo := me.inventory.get_active_ammo()
	if not await wait_step("usurpe"):
		return
	await wait(1.0)
	if not check(target.health.shield == target.health.max_shield, "tir usurpé : le client n'a pris aucun dégât"):
		return
	check(me.inventory.get_active_ammo() == my_ammo, "tir usurpé : aucune munition de l'hôte consommée")
	await wait_step("fin_client")


func run_client() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2 and local_player() != null, 30.0, "2 joueurs dans le monde"):
		return
	var host := player(1)
	# --- Lobby : tir sans effet ---
	if not await wait_step("lobby_place"):
		return
	await move_self_and_settle(BriefingRoom.spawn_point(3))
	fire_at(chest(host))
	await wait(0.3)
	send_step("lobby_tir")
	if not await wait_step("lobby_verifie"):  # l'hôte vérifie avant que le briefing ne recharge l'arme
		return
	# --- Partie ---
	if not await start_match():
		return
	if not await wait_step("place"):
		return
	await move_self_and_settle(ground(SPOT_CLIENT))
	var shield_before := host.health.shield
	fire_at(chest(host))
	send_step("tir")
	if not await wait_step("touche"):
		return
	# Le client voit la perte de bouclier de l'hôte (synchronisée).
	if not await wait_until(func() -> bool: return host.health.shield < shield_before, 5.0, "bouclier de l'hôte reçu en baisse"):
		return
	# Tir avec l'arme de l'hôte, visant le client : le serveur doit refuser.
	var origin := host.camera.global_position
	for i in 3:
		host.weapon.request_fire.rpc_id(1, origin, (chest(local_player()) - origin).normalized(), true)
		await wait(0.2)
	send_step("usurpe")
	await wait(1.5)
	check(local_player().health.shield == local_player().health.max_shield, "tir usurpé : mon bouclier est intact")
	send_step("fin_client")
