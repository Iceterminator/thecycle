extends RefCounted
## Logique client propriétaire de Weapon : lecture du clic, cadence, charge, rayon,
## Modes de tir : AUTO (maintenir), SEMI (un clic = un tir), BURST (burst_count tirs
## espacés de burst_interval_s), CHARGE (maintenir charge_time_s, relâcher avant = pas de tir ;
## CHARGE_BURST : puis une rafale), BEAM (après spin_up_s, un tick par fire_interval_s,
## 1 munition par tick). Types : HITSCAN, PROJECTILE, EXPLOSIVE_PROJECTILE.
## rafale, rechargement, recul. L'état (ammo, _fire_cooldown…) reste dans Weapon ; charge et rayon
## sont dans weapon_client_hold.gd.

const WeaponClientHold := preload("res://systems/combat/weapon_client_hold.gd")

var _w: Weapon
var _hold: WeaponClientHold


func _init(weapon: Weapon) -> void:
	_w = weapon
	_hold = WeaponClientHold.new(weapon, self)


## Appelé à chaque image par Weapon._process (client propriétaire).
func update(delta: float) -> void:
	var data := _w.data
	var health := _w.health
	var player := _w.player
	_w._fire_cooldown = maxf(_w._fire_cooldown - delta, 0.0)
	var can_act := not health.is_dead and not health.is_downed and not player.is_evacuated and not player.is_dropping() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_w.is_aiming = can_act and Input.is_action_pressed("aim")
	var target_fov: float = data.get_ads_fov(Config.ADS_FOV, Config.DEFAULT_FOV) if _w.is_aiming else Config.DEFAULT_FOV
	# ads_time_s : temps pour faire l'essentiel du passage en visée.
	_w.camera.fov = lerpf(_w.camera.fov, target_fov, clampf(4.0 / maxf(data.ads_time_s, 0.05) * delta, 0.0, 1.0))

	if _w.is_reloading:
		_w._reload_left -= delta
		if _w._reload_left <= 0.0:
			_w.is_reloading = false
			_w.ammo = player.magazine_for(data)
			_w._emit_ammo()
		return
	if not can_act:
		_w._burst_left = 0
		stop_holding()
		return

	# Rafale en cours : elle part jusqu'au bout même si on relâche le clic.
	if _w._burst_left > 0:
		_w._burst_timer -= delta
		if _w._burst_timer <= 0.0:
			if _w.ammo <= 0:
				_w._burst_left = 0
			else:
				fire_one()
				_w._burst_left -= 1
				_w._burst_timer += data.burst_interval_s
		return

	# Rayon vital : clic droit = se soigner soi-même.
	if data.gadget == WeaponData.GadgetKind.HEAL_BEAM and Input.is_action_just_pressed("aim"):
		_w.request_gadget_alt.rpc_id(1)
	if Input.is_action_just_pressed("reload") and _w.ammo < player.magazine_for(data):
		stop_holding()
		start_reload()
		return
	match data.fire_mode:
		WeaponData.FireMode.CHARGE, WeaponData.FireMode.CHARGE_BURST:
			_hold.process_charge(delta)
		WeaponData.FireMode.BEAM:
			_hold.process_beam(delta)
		WeaponData.FireMode.AUTO:
			if Input.is_action_pressed("fire") and _w._fire_cooldown <= 0.0:
				_try_pull_trigger()
		_:
			if Input.is_action_just_pressed("fire") and _w._fire_cooldown <= 0.0:
				_try_pull_trigger()


func _try_pull_trigger() -> void:
	if _w.ammo <= 0:
		start_reload()
	else:
		pull_trigger()


## Un appui de gâchette : un tir, ou le début d'une rafale.
func pull_trigger() -> void:
	_w._fire_cooldown += _w.data.get_fire_interval() / _w._boost("fire_rate")
	fire_one()
	if _w.data.is_burst():
		_w._burst_left = _w.data.burst_count - 1
		_w._burst_timer = _w.data.burst_interval_s


func stop_holding() -> void:
	_hold.stop_holding()


func fire_one() -> void:
	# Poser la balise de rappel ne consomme rien ; la téléportation, si.
	if not (_w.data.gadget == WeaponData.GadgetKind.RECALL and not _w._gadgets.own_beacon()):
		_w.ammo -= 1
	_w.request_fire.rpc_id(1, _w.camera.global_position, -_w.camera.global_basis.z, _w.is_aiming)
	_apply_recoil()
	_w._emit_ammo()


func start_reload() -> void:
	if _w.data.consumable:
		return  # gadget à usage limité : pas de rechargement
	_w.is_reloading = true
	_w._burst_left = 0
	_w._reload_left = _w.data.reload_s
	_w.request_reload.rpc_id(1)
	_w._emit_ammo()


func _apply_recoil() -> void:
	var player := _w.player
	var kick := deg_to_rad(_w.data.recoil_deg * _w.data.recoil_multiplier) * (0.5 if _w.is_aiming else 1.0)
	if player.buffs:
		kick *= player.buffs.get_mult("recoil_mult")  # Pied ferme : balancement réduit
	_w.head.rotation.x = clampf(_w.head.rotation.x + kick, deg_to_rad(-89), deg_to_rad(89))
	player.rotate_y(randf_range(-0.3, 0.3) * kick)
	# Recul visuel de l'arme en main : ~1 pour une arme qui recule de 2° par tir.
	if player.held_weapon:
		player.held_weapon.kick(clampf(rad_to_deg(kick) / 2.0, 0.3, 1.2))
