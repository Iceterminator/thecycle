extends RefCounted
## Modes « gâchette maintenue » de WeaponClient : charge (CHARGE, CHARGE_BURST) et rayon (BEAM).
## L'état (_holding, _hold_time, _hold_hp) reste dans Weapon ; le serveur est prévenu par
## request_trigger au début de la charge.

var _w: Weapon
var _c: RefCounted  # WeaponClient (tir, rechargement)


func _init(weapon: Weapon, client: RefCounted) -> void:
	_w = weapon
	_c = client


## Charge : appuyer démarre la charge (le serveur est prévenu) ; le tir part tout seul
## quand elle est pleine ; relâcher avant annule.
func process_charge(delta: float) -> void:
	if not _w._holding:
		if Input.is_action_just_pressed("fire") and _w._fire_cooldown <= 0.0:
			if _w.ammo <= 0:
				_c.start_reload()
				return
			start_holding()
		return
	if not Input.is_action_pressed("fire"):
		stop_holding()  # relâché trop tôt : pas de tir
		return
	# Balise de rappel : des dégâts pendant la charge l'interrompent.
	if _w.data.gadget == WeaponData.GadgetKind.RECALL and _w.health.health + _w.health.shield < _w._hold_hp - 0.5:
		stop_holding()
		return
	_w._hold_time += delta
	var delay := _w._gadgets.trigger_delay()
	_w.charge_changed.emit(clampf(_w._hold_time / maxf(delay, 0.01), 0.0, 1.0))
	if _w._hold_time >= delay:
		# Charge pleine : pas de « relâché » envoyé au serveur (il arriverait avant le tir et
		# l'annulerait) ; le serveur remet lui-même la charge à zéro après le tir / la rafale.
		_w._holding = false
		_w._hold_time = 0.0
		_w.charge_changed.emit(0.0)
		_c.pull_trigger()


## Rayon : maintenir ; après la montée en régime, un tick à chaque intervalle.
func process_beam(delta: float) -> void:
	if not Input.is_action_pressed("fire"):
		stop_holding()
		return
	if _w.ammo <= 0:
		stop_holding()
		_c.start_reload()
		return
	if not _w._holding:
		start_holding()
	_w._hold_time += delta
	var delay := _w._gadgets.trigger_delay()
	_w.charge_changed.emit(clampf(_w._hold_time / maxf(delay, 0.01), 0.0, 1.0) if _w._hold_time < delay else 0.0)
	if _w._hold_time >= delay and _w._fire_cooldown <= 0.0:
		_w._fire_cooldown += _w.data.get_fire_interval() / _w._boost("fire_rate")
		_c.fire_one()


func start_holding() -> void:
	_w._holding = true
	_w._hold_time = 0.0
	_w._hold_hp = _w.health.health + _w.health.shield
	_w.request_trigger.rpc_id(1, true)


func stop_holding() -> void:
	if not _w._holding:
		return
	_w._holding = false
	_w._hold_time = 0.0
	_w.charge_changed.emit(0.0)
	if _w.is_inside_tree() and _w.multiplayer.has_multiplayer_peer():
		_w.request_trigger.rpc_id(1, false)

