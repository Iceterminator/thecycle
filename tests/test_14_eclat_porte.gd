extends "res://tests/net_test_aides.gd"
## Éclat d'orage porté : le serveur pose un éclat ; le client le ramasse (E) et gagne des points
## d'objectif tant qu'il le porte ; un dégât reçu le fait retomber au sol, où il se ramasse encore.

const SHARD := "storm_shard"


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	var cid := client_id()
	if not await start_match():
		return
	if not await wait_step("en_place"):
		return
	var track := Items.get_item(StringName(SHARD)).carry_track
	Events.loot_drop_requested.emit(StringName(SHARD), 1, -1, ground(SPOT_CLIENT) + Vector3(1.0, 0.0, 0.0), false)
	if not await wait_until(func() -> bool: return player(cid).inventory.get_resource(StringName(SHARD)) == 1, 15.0, "éclat porté par le client"):
		return
	var before: int = player(cid).score.objective_points.get(track.resource_path, 0)
	await wait(3.0)
	var gained: int = player(cid).score.objective_points.get(track.resource_path, 0) - before
	if not check(gained >= 5, "points d'objectif gagnés en 3 s de port : %d" % gained):
		return
	player(cid).health.apply_damage(5.0, Config.MONSTER_KILLER_ID)
	if not await wait_until(func() -> bool: return player(cid).inventory.get_resource(StringName(SHARD)) == 0, 5.0, "éclat lâché après un dégât"):
		return
	if not check(_au_sol() != null, "l'éclat est retombé au sol"):
		return
	send_step("lache")
	await wait_step("fin_client", 30.0)


func run_client() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2 and local_player() != null, 30.0, "2 joueurs dans le monde"):
		return
	var me := local_player()
	if not await start_match():
		return
	await move_self_and_settle(ground(SPOT_CLIENT))
	send_step("en_place")
	if not await wait_until(func() -> bool: return _au_sol() != null, 15.0, "éclat posé au sol"):
		return
	await move_self_and_settle(_au_sol().global_position + Vector3(0.6, 0.3, 0.0))
	await hold_interact(_au_sol(), 0.0)
	if not await wait_until(func() -> bool: return me.inventory.get_resource(StringName(SHARD)) == 1, 5.0, "éclat ramassé"):
		return
	if not await wait_step("lache"):
		return
	if not await wait_until(func() -> bool: return me.inventory.get_resource(StringName(SHARD)) == 0, 5.0, "client : plus d'éclat sur soi"):
		return
	await move_self_and_settle(_au_sol().global_position + Vector3(0.6, 0.3, 0.0))
	await hold_interact(_au_sol(), 0.0)
	if not await wait_until(func() -> bool: return me.inventory.get_resource(StringName(SHARD)) == 1, 5.0, "éclat ramassé à nouveau"):
		return
	send_step("fin_client")


func _au_sol() -> Pickup:
	for node in world().get_node("Loot").get_children():
		if node is Pickup and String((node as Pickup).item.id) == SHARD and not (node as Pickup).is_taken():
			return node
	return null
