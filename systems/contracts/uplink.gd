class_name Uplink
extends ContractSite
## Contrat « Relais satellite ». Maintenir E (data.hold_time) pour le capturer.
## Il rapporte data.points_per_second à son propriétaire, en continu, jusqu'à ce
## qu'un autre joueur le reprenne. Chaque capture est annoncée à tous les joueurs.
## Champs utilisés : hold_time, points_per_second, color.

var owner_id: int = 0  ## synchronisé


func _sync_props() -> Array[String]:
	return ["owner_id"]


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


func _refresh() -> void:
	var who := "libre" if owner_id == 0 else player_name(owner_id)
	_label.text = "%s — %s\n+%d pts/s" % [data.display_name, who, int(data.points_per_second)]


func get_prompt(player: Player) -> String:
	if owner_id == player.get_peer_id():
		return "%s sous votre contrôle (+%d pts d'objectif/s)" % [data.display_name, int(data.points_per_second)]
	return "Maintenir E (%d s) : capturer le %s" % [int(data.hold_time), data.display_name.to_lower()]


func get_hold_time(player: Player) -> float:
	return 0.0 if owner_id == player.get_peer_id() else data.hold_time


func server_interact(player: Player) -> void:
	if owner_id == player.get_peer_id():
		return
	owner_id = player.get_peer_id()
	announce("%s a capturé le %s !" % [player_name(owner_id), data.display_name.to_lower()])


func _physics_process(delta: float) -> void:
	if owner_id == 0:
		return
	var owner := find_player(owner_id)
	if owner == null:
		owner_id = 0  # déconnecté
		return
	give_points_over_time(owner, data.points_per_second, delta)
