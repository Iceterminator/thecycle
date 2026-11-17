class_name Collector
extends ContractSite
## Contrat « collecteur » : on y dépose une ressource portée (biomasse lâchée par les
## monstres, Lumicèpes ramassés sur la carte). Maintenir E (Config.COLLECT_HOLD_TIME)
## dépose tout -> data.points par unité.
## Champs utilisés : resource_item, points, color.


func _build_visual() -> void:
	add_cylinder_collision(0.8, 2.0)
	var body := BoxMesh.new()
	body.size = Vector3(1.4, 2.0, 1.0)
	var b := make_mesh(body, Color(0.45, 0.47, 0.5))
	b.position.y = 1.0
	add_child(b)
	var screen := BoxMesh.new()
	screen.size = Vector3(1.0, 0.6, 0.05)
	var s := make_mesh(screen, data.color, true)
	s.position = Vector3(0, 1.4, 0.53)
	add_child(s)


func _label_height() -> float:
	return 3.0


func _refresh() -> void:
	var res_name := data.resource_item.display_name if data.resource_item else "?"
	_label.text = "%s\n%s : %d pts l'unité" % [data.display_name, res_name, data.points]


func get_prompt(player: Player) -> String:
	var n := player.inventory.get_resource(data.resource_item.id)
	if n <= 0:
		return "%s : apportez des %ss" % [data.display_name, data.resource_item.display_name.to_lower()]
	return "Maintenir E : déposer %d %s (+%d pts)" % [n, data.resource_item.display_name.to_lower(), n * data.points]


func get_hold_time(player: Player) -> float:
	return Config.COLLECT_HOLD_TIME if player.inventory.get_resource(data.resource_item.id) > 0 else 0.0


func server_interact(player: Player) -> void:
	var n := player.inventory.take_resource(data.resource_item.id)
	if n > 0:
		player.score.add_quest_points(n * data.points)
		print("[Contrat] %s : %d %s déposés (+%d)" % [player_name(player.get_peer_id()), n, data.resource_item.id, n * data.points])
