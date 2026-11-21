extends "res://tests/net_test_aides.gd"
## Drones en panne : l'hôte pose le site ; l'approche du client fait apparaître la meute.
## L'hôte tue la meute et fixe l'état des drones (75 %, intact, détruit) ; le client relance
## les deux drones restants (E maintenu) : +70 puis +100 points d'objectif, puis le décollage
## commence (l'hôte reçoit « Empêchez le décollage ! »). Le porteur tient : +3 Fame au client.

const DATA := "res://data/contracts/drones.tres"
const SPOT := Vector2(14.0, 4.0)

var _messages: Array[String] = []


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	var cid := client_id()
	events.announcement.connect(func(text: String, _color: Color) -> void: _messages.append(text))
	if not await start_match():
		return
	place(1, ground(Vector2(-14.0, -6.0)))
	events.contract_spawn_requested.emit(&"drones", DATA, ground(SPOT, 0.0))
	var site := _site()
	if not check(site != null, "site de drones posé"):
		return
	send_step("site", String(site.name))
	if not await wait_until(func() -> bool: return site.state == DroneSite.State.ACTIVE, 20.0, "meute déclenchée par l'approche du client"):
		return
	var pack := _pack(site)
	if not check(not pack.is_empty(), "la meute attaque les drones (%d monstres)" % pack.size()):
		return
	for m in pack:
		kill_monster(m, cid)
	var data := site.data
	site.drone_hp = PackedFloat32Array([data.target_health * 0.75, data.target_health, 0.0, data.carrier_health])
	send_step("pret")
	var track := data.track
	if not await wait_until(func() -> bool: return site.state == DroneSite.State.LAUNCH, 20.0, "décollage déclenché"):
		return
	var points: int = player(cid).score.objective_points.get(track.resource_path, 0)
	if not check(points == 170, "points d'objectif : 70 (bon) + 100 (intact) = %d" % points):
		return
	check(_messages.has("Empêchez le décollage !"), "l'autre joueur reçoit « Empêchez le décollage ! »")
	var fame_before: int = player(cid).score.rank_points
	site.time_left = 0.5  # le porteur tient jusqu'au bout
	if not await wait_until(func() -> bool: return player(cid).score.rank_points == fame_before + data.launch_fame, 10.0, "+%d Fame au déclencheur" % data.launch_fame):
		return
	send_step("fin_hote")
	await wait_step("fin_client")


func run_client() -> void:
	if not await start_match():
		return
	if not await wait_step("site"):
		return
	var path := "Crystals/" + step_value("site")
	if not await wait_until(func() -> bool: return world().has_node(path), 5.0, "site reçu"):
		return
	var site := world().get_node(path) as DroneSite
	await move_self_and_settle(ground(SPOT + Vector2(0.0, -2.0)))
	if not await wait_step("pret"):
		return
	for i in 2:
		var drone := site.get_node("Drone%d" % i) as ContractPart
		await move_self_and_settle(drone.global_position + Vector3(1.5, 0.3, 0.0))
		await hold_interact(drone, Config.match_rules.collect_hold_time)
	await wait_step("fin_hote")
	send_step("fin_client")


func _site() -> DroneSite:
	for node in world().get_node("Crystals").get_children():
		if node is DroneSite and (node as Node3D).global_position.distance_to(ground(SPOT, 0.0)) < 1.0:
			return node
	return null


func _pack(site: DroneSite) -> Array[Monster]:
	var result: Array[Monster] = []
	for m in monsters():
		if m.objective is ContractPart and (m.objective as ContractPart).site == site:
			result.append(m)
	return result
