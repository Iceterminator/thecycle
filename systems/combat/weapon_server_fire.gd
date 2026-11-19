extends RefCounted
## Serveur : validation de cadence / charge / munitions d'un tir demandé, dispersion,
## puis déclenchement (gadget, hitscan ou projectile). Appelé par Weapon.request_fire.

var _w: Weapon


func _init(weapon: Weapon) -> void:
	_w = weapon


## Suite de request_fire une fois l'expéditeur et les valeurs vérifiés.
func handle_fire(origin: Vector3, direction: Vector3, aiming: bool) -> void:
	var data := _w.data
	var inventory := _w.inventory
	var player := _w.player
	var now := Time.get_ticks_msec()
	# Changement d'arme en cours ?
	if now < _w._srv.switch_until_ms:
		return
	# Rechargement en cours ?
	if _w._srv.reload_end_ms > 0:
		if now < _w._srv.reload_end_ms:
			return
		inventory.set_active_ammo(player.magazine_for(data))
		_w._srv.reload_end_ms = 0
	if inventory.get_active_ammo() <= 0:
		_w._sync_ammo.rpc_id(player.get_peer_id(), 0)
		return
	# Charge / montée en régime : la gâchette doit être tenue assez longtemps (10 % de marge).
	if not _trigger_ready(now):
		return

	# Cadence : seau de jetons. Il se remplit au rythme moyen de l'arme (une rafale
	# compte pour burst_count tirs par fire_interval_s) ; on tolère quelques tirs d'avance
	# (gigue réseau, rafale entière) mais sur la durée on ne peut pas tirer plus vite.
	_w._srv.tokens = minf(_w._srv.tokens + (now - _w._srv.last_ms) / 1000.0 / _shot_interval(), token_capacity())
	_w._srv.last_ms = now
	if _w._srv.tokens < 1.0:
		return
	_w._srv.tokens -= 1.0

	# L'origine doit être proche des yeux du joueur tels que le serveur les voit.
	if origin.distance_to(_w.camera.global_position) > Config.SHOT_ORIGIN_TOLERANCE:
		push_warning("[Weapon] Tir refusé : origine trop loin du joueur %d" % player.get_peer_id())
		return

	_after_trigger_shot()
	if data.gadget != WeaponData.GadgetKind.NONE:
		_w._gadgets.server_gadget(origin, direction.normalized())
		return
	inventory.set_active_ammo(inventory.get_active_ammo() - 1)
	if player.buffs:
		player.buffs.server_remove_with("cloak_breaks_on_fire")  # tirer révèle (Camouflage total)
	# Le flag « visée » vient du client : au pire un tricheur obtient la précision ADS.
	var aim_spread := data.ads_spread_deg if aiming else data.hip_spread_deg * data.hipfire_spread_multiplier
	var aim_dir := _apply_spread(direction.normalized(), aim_spread)
	for i in maxi(data.pellets, 1):
		# Fusil à pompe : chaque plomb part dans le cône spread_deg autour de la visée.
		var dir := _apply_spread(aim_dir, data.spread_deg) if data.pellets > 1 else aim_dir
		if data.is_projectile():
			_w._projectiles.launch(origin, dir)
		else:
			_w._damage.trace(origin, dir)


func _trigger_ready(now: int) -> bool:
	var delay := _w._gadgets.trigger_delay()
	if delay <= 0.0:
		return true
	return _w._srv.trigger_ms > 0 and now - _w._srv.trigger_ms >= int(delay * 900.0)


## Charge simple : une charge = un tir. Charge + rafale : une charge = une rafale.
## Rayon : la gâchette reste tenue.
func _after_trigger_shot() -> void:
	match _w.data.fire_mode:
		WeaponData.FireMode.CHARGE:
			_w._srv.trigger_ms = 0
		WeaponData.FireMode.CHARGE_BURST:
			_w._srv.trigger_shots += 1
			if _w._srv.trigger_shots >= _w.data.burst_count:
				_w._srv.trigger_ms = 0


func _shot_interval() -> float:
	return _w.data.get_fire_interval() / _w.data.get_shots_per_cycle() / _w._boost("fire_rate")


func token_capacity() -> float:
	if _w.data == null:
		return Config.FIRE_BURST_TOLERANCE
	return maxf(Config.FIRE_BURST_TOLERANCE, _w.data.get_shots_per_cycle() + 1.0)


## Direction aléatoire dans un cône de `spread_deg` degrés autour de `dir`.
static func _apply_spread(dir: Vector3, spread_deg: float) -> Vector3:
	if spread_deg <= 0.0:
		return dir
	var axis := dir.cross(Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT).normalized()
	var angle := deg_to_rad(spread_deg) * sqrt(randf())
	return dir.rotated(axis, angle).rotated(dir, randf() * TAU)
