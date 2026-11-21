class_name Uplink
extends ContractSite
## Contrat « Relais satellite ». Maintenir E (data.hold_time) pour le capturer.
## Il rapporte data.points_per_second à son propriétaire, en continu, jusqu'à ce
## qu'un autre joueur le reprenne. Chaque capture est annoncée à tous les joueurs.
## Un seul relais est actif à la fois (uplink_first_time, uplink_active_time) : les autres sont éteints.
## Champs utilisés : hold_time, points_per_second, color.

var owner_id: int = 0  ## synchronisé
var _was_active: bool = false  ## serveur : état précédent (annonce à l'activation)


func _sync_props() -> Array[String]:
	return ["owner_id"]


func _ready() -> void:
	add_to_group("uplink_site")
	super()


func _build_visual() -> void:
	add_cylinder_collision(0.6, 4.0)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.15
	pole.bottom_radius = 0.4
	pole.height = 4.0
	var p := make_mesh(pole, Color(0.6, 0.6, 0.65))
	p.position.y = 2.0
	add_child(p)
	var dish := CylinderMesh.new()
	dish.top_radius = 1.3
	dish.bottom_radius = 0.2
	dish.height = 0.5
	var d := make_mesh(dish, Color(0.85, 0.85, 0.9))
	d.position = Vector3(0, 4.1, 0)
	d.rotation.x = deg_to_rad(35)
	add_child(d)
	var lamp := make_mesh(SphereMesh.new(), data.color, true)
	lamp.scale = Vector3.ONE * 0.4
	lamp.position.y = 4.6
	add_child(lamp)


func _label_height() -> float:
	return 5.6


# --- Rotation : un seul relais actif à la fois (calculée sur le temps de partie) --------------

func _elapsed() -> float:
	var world := get_parent().get_parent() as World
	return world.match_manager.elapsed if world and world.match_manager else 0.0


## Rang de ce relais parmi ceux de la partie (ordre de création = ordre d'activation).
func _rank() -> int:
	var sites := get_tree().get_nodes_in_group("uplink_site")
	sites.sort_custom(func(a: Node, b: Node) -> bool: return _uid_of(a) < _uid_of(b))
	return sites.find(self)


static func _uid_of(node: Node) -> int:
	return String(node.name).get_slice("_", 1).to_int()


## Secondes avant l'activation de ce relais (négatif ou nul : activé ou déjà passé).
func _starts_in() -> float:
	var rules := Config.match_rules
	return rules.uplink_first_time + _rank() * rules.uplink_active_time - _elapsed()


func is_active() -> bool:
	var left := _starts_in()
	return left <= 0.0 and -left < Config.match_rules.uplink_active_time


func _refresh() -> void:
	var rules := Config.match_rules
	var starts := _starts_in()
	var title := data.display_name
	if is_active():
		var who := "libre" if owner_id == 0 else player_name(owner_id)
		_label.text = "%s ACTIF — %s\n+%d pts/s, s'éteint dans %s" % [title, who, int(data.points_per_second), _clock(rules.uplink_active_time + starts)]
	elif starts > 0.0:
		_label.text = "%s — éteint\nS'active dans %s" % [title, _clock(starts)]
	else:
		_label.text = "%s — éteint" % title


static func _clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func get_prompt(player: Player) -> String:
	if not is_active():
		return "%s éteint" % data.display_name
	if owner_id == player.get_peer_id():
		return "%s sous votre contrôle (+%d pts d'objectif/s)" % [data.display_name, int(data.points_per_second)]
	return "Maintenir E (%d s) : capturer le %s" % [int(data.hold_time), data.display_name.to_lower()]


func get_hold_time(player: Player) -> float:
	return 0.0 if owner_id == player.get_peer_id() or not is_active() else data.hold_time


func server_interact(player: Player) -> void:
	if owner_id == player.get_peer_id() or not is_active():
		return
	var old := find_player(owner_id)
	if old:
		old.score.set_objective_rate(data.track, 0.0)
	owner_id = player.get_peer_id()
	player.score.set_objective_rate(data.track, data.points_per_second)
	announce("%s a capturé le %s !" % [player_name(owner_id), data.display_name.to_lower()])


## Écran Tab : le relais actif est toujours visible ; un relais éteint seulement de près, en gris.
func map_info() -> Dictionary:
	var info := super()
	var active := is_active()
	info["always"] = active
	if not active:
		info["color"] = Color(0.5, 0.5, 0.55)
	return info


func _physics_process(delta: float) -> void:
	var active := is_active()
	if active != _was_active:
		_was_active = active
		if active:
			announce("Nouveau relais actif : capturez-le !")
		else:
			_switch_off()
	if not active or owner_id == 0:
		return
	var owner := find_player(owner_id)
	if owner == null:
		owner_id = 0  # déconnecté
		return
	give_points_over_time(owner, data.points_per_second, delta)


## Le relais s'éteint : il ne rapporte plus (son propriétaire perd le gain continu).
func _switch_off() -> void:
	var old := find_player(owner_id)
	if old:
		old.score.set_objective_rate(data.track, 0.0)
	owner_id = 0
