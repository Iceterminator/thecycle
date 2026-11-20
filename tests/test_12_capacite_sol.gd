extends "res://tests/net_test_aides.gd"
## Capacités au sol : le serveur pose 2 capacités ; le client ramasse la 1re (E) et la met
## sur Q (request_assign) ; puis la 2e sur Q : elle remplace la 1re, qui retombe au sol.

const CAPA_A := "stim_boost"
const CAPA_B := "shock_grenade"


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	if not await start_match():
		return
	if not await wait_step("en_place"):
		return
	var pos := ground(SPOT_CLIENT)
	Events.loot_drop_requested.emit(StringName(CAPA_A), 1, -1, pos + Vector3(1.5, 0.0, 0.0), false)
	Events.loot_drop_requested.emit(StringName(CAPA_B), 1, -1, pos + Vector3(-1.5, 0.0, 0.0), false)
	send_step("poses")
	await wait_step("fin_client", 60.0)


func run_client() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2 and local_player() != null, 30.0, "2 joueurs dans le monde"):
		return
	var me := local_player()
	if not await start_match():
		return
	await move_self_and_settle(ground(SPOT_CLIENT))
	send_step("en_place")
	if not await wait_step("poses"):
		return
	if not await _prendre_sur_q(me, CAPA_A):
		return
	if not await _prendre_sur_q(me, CAPA_B):
		return
	if not await wait_until(func() -> bool: return _au_sol(CAPA_A) != null, 5.0, "%s retombée au sol après remplacement" % CAPA_A):
		return
	send_step("fin_client")


## Ramasse la capacité au sol (E), puis l'assigne à Q.
func _prendre_sur_q(me: Player, id: String) -> bool:
	if not await wait_until(func() -> bool: return _au_sol(id) != null, 10.0, "%s posée au sol" % id):
		return false
	var p := _au_sol(id)
	if not check(p.item.kind == ItemData.Kind.ABILITY, "%s est un objet Capacité" % id):
		return false
	await move_self_and_settle(p.global_position + Vector3(1.0, 0.3, 0.0))
	await hold_interact(p, 0.0)
	if not await wait_until(func() -> bool: return me.abilities.pending == id, 5.0, "%s en attente de Q / F" % id):
		return false
	me.abilities.request_assign.rpc_id(1, 0)
	return await wait_until(func() -> bool: return me.abilities.loadout[0] == id, 5.0, "%s équipée sur Q" % id)


func _au_sol(id: String) -> Pickup:
	for node in world().get_node("Loot").get_children():
		if node is Pickup and String((node as Pickup).item.id) == id and not (node as Pickup).is_taken():
			return node
	return null
