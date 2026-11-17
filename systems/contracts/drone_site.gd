class_name DroneSite
extends ContractSite
## Contrat « Sauvetage de drones ». data.count drones en panne autour d'une balise.
## Maintenir E (hold_time) sur la balise lance la protection : pendant data.duration s,
## des vagues de monstres attaquent les drones (data.target_health PV chacun).
## Ensuite, maintenir E (Config.COLLECT_HOLD_TIME) sur chaque drone survivant l'envoie
## -> data.points × (PV restants / PV max). Tous détruits = échec.
## Le site redevient utilisable après Config.CONTRACT_RESET_DELAY.
## Champs utilisés : count, radius, hold_time, duration, target_health, points, waves,
## monster_*_mult, color.

enum State { IDLE, DEFENSE, SEND, DONE }

const PART_SCRIPT := preload("res://systems/contracts/contract_part.gd")

var state: int = State.IDLE           ## synchronisé
var time_left: float = 0.0            ## synchronisé
var drone_hp: PackedFloat32Array = PackedFloat32Array()  ## synchronisé
var sent_mask: int = 0                ## synchronisé

var _parts: Array[ContractPart] = []
var _alive: Array[Monster] = []
var _waves_spawned: int = 0


func _sync_props() -> Array[String]:
	return ["state", "time_left", "drone_hp", "sent_mask"]


func _build_visual() -> void:
	add_cylinder_collision(0.4, 2.5)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.1
	pole.bottom_radius = 0.3
	pole.height = 2.5
	var p := make_mesh(pole, Color(0.6, 0.6, 0.65))
	p.position.y = 1.25
	add_child(p)
	var lamp := make_mesh(SphereMesh.new(), data.color, true)
	lamp.scale = Vector3.ONE * 0.5
	lamp.position.y = 2.7
	add_child(lamp)
	drone_hp.resize(data.count)
	for i in data.count:
		drone_hp[i] = data.target_health
		var part: ContractPart = PART_SCRIPT.new()
		part.name = "Drone%d" % i
		part.site = self
		part.index = i
		part.hit_radius = 0.9
		var a := TAU * i / data.count + 0.4
		part.position = Vector3(cos(a), 0, sin(a)) * data.radius
		part.rotation.y = randf() * TAU
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 0.7, 1.6)
		shape.shape = box
		shape.position.y = 0.35
		part.add_child(shape)
		var body := BoxMesh.new()
		body.size = Vector3(0.9, 0.5, 0.9)
		var b := make_mesh(body, Color(0.75, 0.75, 0.8))
		b.position.y = 0.35
		part.add_child(b)
		for k in 4:
			var arm := BoxMesh.new()
			arm.size = Vector3(0.7, 0.08, 0.1)
			var m := make_mesh(arm, Color(0.3, 0.3, 0.35))
			m.rotation.y = TAU * k / 4.0
			m.position = Vector3(cos(TAU * k / 4.0) * 0.6, 0.55, -sin(TAU * k / 4.0) * 0.6)
			part.add_child(m)
		add_child(part)
		_parts.append(part)


func _refresh() -> void:
	for i in _parts.size():
		_parts[i].visible = sent_mask & (1 << i) == 0
	match state:
		State.IDLE:
			_label.text = "%s\n%d drones à protéger (+%d Fame chacun)" % [data.display_name, data.count, data.points]
		State.DEFENSE:
			var hp_text := ""
			for hp in drone_hp:
				hp_text += "%d%% " % roundi(100.0 * hp / data.target_health)
			_label.text = "%s — tenez %d s\nDrones : %s" % [data.display_name, ceili(time_left), hp_text]
		State.SEND:
			_label.text = "%s\nEnvoyez les drones survivants (E)" % data.display_name
		State.DONE:
			_label.text = "%s\nTerminé — de nouveau disponible bientôt" % data.display_name


# --- Balise ---------------------------------------------------------------

func get_prompt(_player: Player) -> String:
	if state != State.IDLE:
		return ""
	return "Maintenir E (%d s) : réparer les drones (vagues pendant %d s)" % [int(data.hold_time), int(data.duration)]


func get_hold_time(_player: Player) -> float:
	return data.hold_time if state == State.IDLE else 0.0


func server_interact(player: Player) -> void:
	if state != State.IDLE:
		return
	state = State.DEFENSE
	time_left = data.duration
	sent_mask = 0
	_waves_spawned = 0
	var hp := PackedFloat32Array()
	hp.resize(data.count)
	hp.fill(data.target_health)
	drone_hp = hp
	announce("%s répare des drones en panne" % player_name(player.get_peer_id()))


func _physics_process(delta: float) -> void:
	if state != State.DEFENSE:
		return
	time_left = maxf(time_left - delta, 0.0)
	# Les vagues arrivent à intervalles réguliers pendant la défense.
	var due := int((1.0 - time_left / data.duration) * data.waves.size()) + 1
	while _waves_spawned < mini(due, data.waves.size()):
		_spawn_wave_on_drones(data.waves[_waves_spawned])
		_waves_spawned += 1
	if time_left <= 0.0:
		for m in _alive:
			if is_instance_valid(m):
				m.queue_free()
		_alive.clear()
		state = State.SEND


func _spawn_wave_on_drones(wave: CampData) -> void:
	var alive_parts: Array[ContractPart] = []
	for i in _parts.size():
		if drone_hp[i] > 0.0:
			alive_parts.append(_parts[i])
	if alive_parts.is_empty():
		return
	for monster_data in wave.roll():
		var target: ContractPart = alive_parts.pick_random()
		var angle := randf() * TAU
		var pos := global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(16.0, 20.0)
		Events.wave_spawn_requested.emit(target, monster_data, pos, data.monster_health_mult, data.monster_damage_mult)


func _finish() -> void:
	state = State.DONE
	await get_tree().create_timer(Config.CONTRACT_RESET_DELAY).timeout
	if is_inside_tree():
		state = State.IDLE


# --- Drones (ContractPart) -----------------------------------------------

func _can_send(i: int) -> bool:
	return state == State.SEND and drone_hp[i] > 0.0 and sent_mask & (1 << i) == 0


func part_prompt(i: int, _player: Player) -> String:
	if not _can_send(i):
		return ""
	return "Maintenir E : envoyer le drone (+%d Fame)" % roundi(data.points * drone_hp[i] / data.target_health)


func part_hold_time(i: int, _player: Player) -> float:
	return Config.COLLECT_HOLD_TIME if _can_send(i) else 0.0


func part_interact(i: int, player: Player) -> void:
	if not _can_send(i):
		return
	sent_mask |= 1 << i
	player.score.add_contract_fame(roundi(data.points * drone_hp[i] / data.target_health))
	for k in data.count:
		if drone_hp[k] > 0.0 and sent_mask & (1 << k) == 0:
			return
	announce("Les drones ont été récupérés")
	_finish()


func part_can_be_hit(i: int) -> bool:
	return state == State.DEFENSE and drone_hp[i] > 0.0


func part_receive_hit(i: int, amount: float) -> bool:
	if not part_can_be_hit(i):
		return false
	var hp := drone_hp
	hp[i] = maxf(hp[i] - amount, 0.0)
	drone_hp = hp
	for k in data.count:
		if drone_hp[k] > 0.0:
			return hp[i] <= 0.0
	# Tous les drones sont détruits : échec.
	for m in _alive:
		if is_instance_valid(m):
			m.queue_free()
	_alive.clear()
	announce("Tous les drones ont été détruits")
	_finish()
	return true


func register_wave_monster(monster: Monster) -> void:
	_alive.append(monster)


func on_wave_monster_died(monster: Monster) -> void:
	_alive.erase(monster)
