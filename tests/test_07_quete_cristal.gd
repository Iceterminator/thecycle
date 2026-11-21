extends "res://tests/net_test_aides.gd"
## Quête « cristal » : l'hôte pose un cristal facile à une position fixe
## (Events.crystal_spawn_requested) ; le client lance la foreuse (E maintenu) ; l'hôte tue
## les vagues (dégâts serveur au nom du client) ; le client extrait (E maintenu).
## Serveur : Events.quest_completed(cristal, client, points). Client : points d'objectif
## et Fame du premier palier (ObjectiveTrack) reçus.

const CRYSTAL_DATA := "res://data/quests/crystal_easy.tres"
const CRYSTAL_SPOT := Vector2(14.0, 4.0)

var _completed: Array = []


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	var cid := client_id()
	events.quest_completed.connect(func(quest: StringName, peer: int, points: int) -> void: _completed = [String(quest), peer, points])
	if not await start_match():
		return
	place(1, ground(Vector2(-14.0, -6.0)))
	events.crystal_spawn_requested.emit(CRYSTAL_DATA, ground(CRYSTAL_SPOT, 0.0))
	var crystal := _crystal_at(ground(CRYSTAL_SPOT))
	if not check(crystal != null, "cristal posé en %s" % CRYSTAL_SPOT):
		return
	send_step("cristal", String(crystal.name))
	# Le client lance la foreuse : la vague arrive après crystal_wave_delay.
	if not await wait_until(func() -> bool: return crystal.state == Crystal.State.DEFENSE, 15.0, "foreuse lancée par le client"):
		return
	# Toutes les vagues : on tue les monstres du cristal (par le serveur) jusqu'à l'extraction.
	var waves_seen := 0
	var deadline := Time.get_ticks_msec() + 60000
	while crystal.state != Crystal.State.EXTRACT and Time.get_ticks_msec() < deadline:
		waves_seen = maxi(waves_seen, crystal.wave_index)
		for m in monsters():
			if m.objective == crystal:
				kill_monster(m, cid)
		await get_tree().create_timer(0.3).timeout
	var wave_count := (load(CRYSTAL_DATA) as CrystalData).waves.size()
	if not check(crystal.state == Crystal.State.EXTRACT and waves_seen == wave_count, "toutes les vagues (%d/%d) tuées, extraction possible" % [waves_seen, wave_count]):
		return
	send_step("extraction")
	if not await wait_until(func() -> bool: return not _completed.is_empty(), 15.0, "Events.quest_completed"):
		return
	var data := load(CRYSTAL_DATA) as CrystalData
	if not check(_completed == [String(crystal.name), cid, data.objective_points], "quest_completed(cristal, client, %d) : reçu %s" % [data.objective_points, _completed]):
		return
	check(crystal.state == Crystal.State.DONE, "cristal épuisé")
	await wait_step("fin_client")


func _crystal_at(pos: Vector3) -> Crystal:
	for node in world().get_node("Crystals").get_children():
		if node is Crystal and (node as Node3D).global_position.distance_to(pos) < 1.0:
			return node
	return null


func run_client() -> void:
	if not await start_match():
		return
	if not await wait_step("cristal"):
		return
	var path := "Crystals/" + step_value("cristal")
	if not await wait_until(func() -> bool: return world().has_node(path), 5.0, "cristal reçu"):
		return
	var crystal := world().get_node(path) as Crystal
	# À 1,8 m du cristal (portée d'interaction mesurée depuis les yeux).
	await move_self_and_settle(ground(CRYSTAL_SPOT + Vector2(0.0, -1.8)))
	await hold_interact(crystal, Config.match_rules.crystal_activate_time)
	if not await wait_step("extraction"):
		return
	await hold_interact(crystal, Config.match_rules.crystal_extract_time)
	var data := load(CRYSTAL_DATA) as CrystalData
	var track := data.track
	var score := local_player().score
	if not await wait_until(func() -> bool: return int(score.objective_points.get(track.resource_path, 0)) == data.objective_points, 5.0, "points de Forage reçus"):
		return
	var fame := track.reward(0) if track.tiers_reached(data.objective_points) >= 1 else 0
	if not await wait_until(func() -> bool: return score.rank_points == fame, 5.0, "Fame du palier reçue (%d attendus)" % fame):
		return
	send_step("fin_client")
