extends "res://tests/net_test_aides.gd"
## Boutique + inventaire : achat refusé au lobby ; en partie, crédits donnés par le serveur,
## achat d'une arme (Shop.request_buy) -> crédits débités, capsule puis objet au sol ;
## le client le ramasse (Interactor) -> emplacement 2 rempli ; changement d'arme
## (Inventory.request_switch) reçu.

const ITEM := "s76_pdw"
const START_CREDITS := 1000

var _results: Array = []  # [ok, message] reçus du serveur
var _pickup: Pickup  # objet acheté, posé au sol


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	var cid := client_id()
	if not await wait_step("lobby_achat"):
		return
	if not await start_match():
		return
	var inv := player(cid).inventory
	inv.add_credits(START_CREDITS)
	send_step("credits")
	if not await wait_until(func() -> bool: return inv.credits == START_CREDITS - Items.get_item(ITEM).price, 10.0, "crédits du client débités"):
		return
	if not await wait_until(func() -> bool: return inv.slot_ids[1] == ITEM, 20.0, "arme achetée dans l'emplacement 2 du client"):
		return
	await wait_step("fin_client")


func run_client() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2 and local_player() != null, 30.0, "2 joueurs dans le monde"):
		return
	var me := local_player()
	me.shop.purchase_result.connect(func(ok: bool, message: String) -> void: _results.append([ok, message]))
	# --- Lobby : achat refusé ---
	await wait(1.0)
	me.shop.request_buy.rpc_id(1, ITEM)
	if not await wait_until(func() -> bool: return _results.size() == 1, 5.0, "réponse de la boutique au lobby"):
		return
	if not check(not _results[0][0] and "lobby" in String(_results[0][1]), "achat refusé au lobby (reçu : %s)" % [_results[0]]):
		return
	send_step("lobby_achat")
	# --- Partie ---
	if not await start_match():
		return
	if not await wait_step("credits"):
		return
	if not await wait_until(func() -> bool: return me.inventory.credits == START_CREDITS, 5.0, "crédits reçus"):
		return
	await move_self_and_settle(ground(SPOT_CLIENT))
	me.shop.request_buy.rpc_id(1, ITEM)
	if not await wait_until(func() -> bool: return _results.size() == 2, 5.0, "réponse de la boutique en partie"):
		return
	if not check(_results[1][0], "achat accepté (reçu : %s)" % [_results[1]]):
		return
	var price := Items.get_item(ITEM).price
	if not await wait_until(func() -> bool: return me.inventory.credits == START_CREDITS - price, 5.0, "crédits débités de %d" % price):
		return
	# La capsule tombe (Config.DROP_POD_FALL_TIME), puis l'objet est posé au sol.
	var find := func() -> bool:
		for node in world().get_node("Loot").get_children():
			if node is Pickup and String((node as Pickup).item.id) == ITEM:
				_pickup = node
				return true
		return false
	if not await wait_until(find, Config.DROP_POD_FALL_TIME + 5.0, "objet acheté posé au sol"):
		return
	# Ramassage (emplacement 2 vide : interaction simple).
	await move_self_and_settle(_pickup.global_position + Vector3(1.0, 0.3, 0.0))
	await hold_interact(_pickup, 0.0)
	if not await wait_until(func() -> bool: return me.inventory.slot_ids[1] == ITEM and me.inventory.active_slot == 1, 5.0, "arme ramassée et équipée (emplacement 2)"):
		return
	if not await wait_until(func() -> bool: return me.weapon.data == Items.get_item(ITEM).weapon, 3.0, "arme en main = %s" % ITEM):
		return
	# Changement d'arme demandé au serveur.
	await wait(1.0)
	me.inventory.request_switch.rpc_id(1, 0)
	if not await wait_until(func() -> bool: return me.inventory.active_slot == 0, 5.0, "retour à l'emplacement 1"):
		return
	check(me.weapon.data == Items.get_item(me.inventory.slot_ids[0]).weapon, "arme en main = arme de départ")
	send_step("fin_client")
