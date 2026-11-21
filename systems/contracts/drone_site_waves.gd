extends RefCounted
## Monstres du contrat « Sauvetage de drones » (serveur) : meute présente sur le site, vagues
## du décollage, et changement de cible quand un drone disparaît.


## Meute déjà sur place : elle attaque les drones encore intacts.
static func spawn_pack(site: DroneSite) -> void:
	if site.data.pack:
		_spawn(site, site.data.pack.roll(), site.alive_drone_parts())


## Vague du décollage : elle attaque le porteur.
static func spawn_wave(site: DroneSite, wave: CampData) -> void:
	_spawn(site, wave.roll(), [site.carrier_part()])


static func _spawn(site: DroneSite, monsters: Array[MonsterData], targets: Array[ContractPart]) -> void:
	if targets.is_empty():
		return
	for monster_data in monsters:
		var angle := randf() * TAU
		var pos := site.global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(16.0, 20.0)
		Events.wave_spawn_requested.emit(targets.pick_random(), monster_data, pos,
				site.data.monster_health_mult, site.data.monster_damage_mult)


## Appelé quand un drone n'est plus attaquable (relancé, détruit) ou au décollage : ses monstres visent
## un drone restant, ou le porteur pendant le décollage. Sans cible, ils disparaissent d'eux-mêmes.
static func retarget(site: DroneSite) -> void:
	var targets: Array[ContractPart] = site.alive_drone_parts()
	if site.state == DroneSite.State.LAUNCH:
		targets = [site.carrier_part()]
	if targets.is_empty():
		return
	for m in site.alive_monsters():
		if not is_instance_valid(m.objective) or not m.objective.can_be_hit():
			m.objective = targets.pick_random()
			m.aggro_objective()


## Fin de contrat : les monstres restants disparaissent.
static func clear(site: DroneSite) -> void:
	for m in site.alive_monsters():
		m.queue_free()
	site.forget_monsters()


## Premier joueur vivant à portée de déclenchement du site (null si aucun).
static func player_near(site: DroneSite) -> Player:
	for node in site.players_root().get_children():
		var player := node as Player
		if player and player.can_be_hit() and player.global_position.distance_to(site.global_position) <= site.data.trigger_radius:
			return player
	return null


## Message d'alerte aux joueurs autres que `except_id`.
static func warn_others(site: DroneSite, except_id: int, text: String) -> void:
	for node in site.players_root().get_children():
		var player := node as Player
		if player and player.get_peer_id() != except_id:
			player.score.notify.rpc_id(player.get_peer_id(), text, Color(1.0, 0.4, 0.3))


## Vagues du décollage : réparties régulièrement sur `launch_time`, la 1re tout de suite.
static func spawn_due_waves(site: DroneSite) -> void:
	var count := site.data.waves.size()
	var due := mini(int((1.0 - site.time_left / site.data.launch_time) * count) + 1, count)
	while site.waves_spawned < due:
		spawn_wave(site, site.data.waves[site.waves_spawned])
		site.waves_spawned += 1
