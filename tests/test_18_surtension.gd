extends "res://tests/net_test_aides.gd"
## Surtension : surge_lead s avant la Grande Marée, annonce + surge_count cristaux au sol ; le client en ramasse un
## (E) et gagne surge_points points de l'objectif « surtension » ; les autres disparaissent après surge_lifetime.

const ITEM := "surge_crystal"

var _announced: bool = false


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	var cid := client_id()
	var rules: MatchRules = config.match_rules
	rules.surge_lifetime = 8.0  # en mémoire seulement
	events.announcement.connect(func(text: String, _color: Color) -> void:
		if "Surtension" in text:
			_announced = true)
	if not await start_match():
		return
	var storm := world().get_node("StormManager") as StormManager
	events.match_time_set_requested.emit(storm.phases[0].start_time - rules.surge_lead + 1.0)
	if not await wait_until(func() -> bool: return _crystals().size() == rules.surge_count, 10.0, "%d cristaux de surtension au sol" % rules.surge_count):
		return
	check(_announced, "annonce « Surtension détectée »")
	send_step("cristaux")
	var track := Items.get_item(StringName(ITEM)).objective_track
	if not await wait_until(func() -> bool: return player(cid).score.objective_points.get(track.resource_path, 0) == rules.surge_points, 20.0, "client : %d points de surtension" % rules.surge_points):
		return
	if not await wait_until(func() -> bool: return _crystals().is_empty(), 15.0, "les cristaux restants disparaissent"):
		return
	send_step("fin_host")
	await wait_step("fin_client")


func run_client() -> void:
	if not await start_match():
		return
	if not await wait_step("cristaux"):
		return
	if not await wait_until(func() -> bool: return not _crystals().is_empty(), 5.0, "cristal visible chez le client"):
		return
	var crystal := _crystals()[0]
	await move_self_and_settle(crystal.global_position + Vector3(0.6, 0.3, 0.0))
	await hold_interact(crystal, 0.0)
	if not await wait_step("fin_host", 30.0):
		return
	send_step("fin_client")


func _crystals() -> Array[Pickup]:
	var result: Array[Pickup] = []
	for node in world().get_node("Loot").get_children():
		var pickup := node as Pickup
		if pickup and String(pickup.item.id) == ITEM and not pickup.is_taken():
			result.append(pickup)
	return result
