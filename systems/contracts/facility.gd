class_name Facility
extends ContractSite
## Contrat « Station à réactiver ». Autour de l'ordinateur central, data.count nœuds
## recouverts de biomasse. Maintenir E (hold_time) sur un nœud le nettoie et l'active,
## mais fait apparaître une vague (waves[0]) qui attaque celui qui l'a activé :
## mieux vaut les activer un par un. Une fois tous actifs, maintenir E sur l'ordinateur
## central -> data.points. Le site redevient utilisable après Config.CONTRACT_RESET_DELAY.
## Champs utilisés : count, radius, hold_time, points, waves, monster_*_mult, color.

const PART_SCRIPT := preload("res://systems/contracts/contract_part.gd")

var active_mask: int = 0   ## synchronisé : bit i = nœud i actif
var done: bool = false     ## synchronisé

var _parts: Array[ContractPart] = []
var _blobs: Array[Node3D] = []
var _lamps: Array[Node3D] = []


func _sync_props() -> Array[String]:
	return ["active_mask", "done"]


func _build_visual() -> void:
	add_cylinder_collision(0.9, 2.2)
	var desk := BoxMesh.new()
	desk.size = Vector3(1.6, 2.2, 1.0)
	var d := make_mesh(desk, Color(0.35, 0.38, 0.45))
	d.position.y = 1.1
	add_child(d)
	var screen := BoxMesh.new()
	screen.size = Vector3(1.2, 0.7, 0.05)
	var s := make_mesh(screen, data.color, true)
	s.position = Vector3(0, 1.5, 0.53)
	add_child(s)
	for i in data.count:
		var part: ContractPart = PART_SCRIPT.new()
		part.name = "Noeud%d" % i
		part.site = self
		part.index = i
		var a := TAU * i / data.count
		part.position = Vector3(cos(a), 0, sin(a)) * data.radius
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.2, 1.6, 1.2)
		shape.shape = box
		shape.position.y = 0.8
		part.add_child(shape)
		var core := BoxMesh.new()
		core.size = Vector3(1.0, 1.6, 1.0)
		var c := make_mesh(core, Color(0.4, 0.42, 0.5))
		c.position.y = 0.8
		part.add_child(c)
		var blob := SphereMesh.new()
		blob.radius = 0.9
		blob.height = 1.4
		var b := make_mesh(blob, Color(0.55, 0.3, 0.15))
		b.position.y = 0.8
		part.add_child(b)
		var lamp := make_mesh(SphereMesh.new(), data.color, true)
		lamp.scale = Vector3.ONE * 0.4
		lamp.position.y = 1.9
		part.add_child(lamp)
		add_child(part)
		_parts.append(part)
		_blobs.append(b)
		_lamps.append(lamp)


func _refresh() -> void:
	var n := 0
	for i in data.count:
		var on := active_mask & (1 << i) != 0
		n += int(on)
		_blobs[i].visible = not on
		_lamps[i].visible = on
	if done:
		_label.text = "%s\nRéactivée — de nouveau disponible bientôt" % data.display_name
	else:
		_label.text = "%s\n%d / %d nœuds actifs (+%d Fame)" % [data.display_name, n, data.count, data.points]


func _all_active() -> bool:
	return active_mask == (1 << data.count) - 1


# --- Ordinateur central ---------------------------------------------------

func get_prompt(_player: Player) -> String:
	if done:
		return ""
	if not _all_active():
		return "Ordinateur central : activez d'abord les %d nœuds" % data.count
	return "Maintenir E (%d s) : relancer la station (+%d Fame)" % [int(data.hold_time), data.points]


func get_hold_time(_player: Player) -> float:
	return data.hold_time if not done and _all_active() else 0.0


func server_interact(player: Player) -> void:
	if done or not _all_active():
		return
	done = true
	player.score.add_contract_fame(data.points)
	announce("%s a réactivé la %s (+%d Fame)" % [player_name(player.get_peer_id()), data.display_name.to_lower(), data.points])
	await get_tree().create_timer(Config.CONTRACT_RESET_DELAY).timeout
	if is_inside_tree():
		active_mask = 0
		done = false


# --- Nœuds (ContractPart) ------------------------------------------------

func part_prompt(i: int, _player: Player) -> String:
	if done or active_mask & (1 << i) != 0:
		return ""
	return "Maintenir E (%d s) : nettoyer et activer le nœud (attire des ennemis !)" % int(data.hold_time)


func part_hold_time(i: int, _player: Player) -> float:
	return 0.0 if done or active_mask & (1 << i) != 0 else data.hold_time


func part_interact(i: int, player: Player) -> void:
	if done or active_mask & (1 << i) != 0:
		return
	active_mask |= 1 << i
	if not data.waves.is_empty():
		spawn_wave(data.waves[0], _parts[i].global_position, player)


func part_can_be_hit(_i: int) -> bool:
	return false


func part_receive_hit(_i: int, _amount: float) -> bool:
	return false


func register_wave_monster(_monster: Monster) -> void:
	pass


func on_wave_monster_died(_monster: Monster) -> void:
	pass
