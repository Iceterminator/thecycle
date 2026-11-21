extends RefCounted
## Éclats d'orage sur la carte : éclats au sol et porteurs, visibles de TOUS à n'importe quelle
## distance (les éclats sont des repères de partie). Dessine sur le MapView `v`, pendant son _draw().

static func draw(v: MapView) -> void:
	var loot := v.world.get_node_or_null("Loot")
	if loot:
		for node in loot.get_children():
			var pickup := node as Pickup
			if pickup and pickup.item and pickup.item.carry_points_per_second > 0.0:
				_star(v, v.to_map(pickup.global_position), pickup.item.color, 6.0)
	var players := v.world.get_node_or_null("Players")
	if players == null:
		return
	for node in players.get_children():
		var other := node as Player
		if other == null or other.health.is_dead or other.is_evacuated:
			continue
		var item := StormShards.carried_item(other.inventory)
		if item:
			var p := v.to_map(other.global_position)
			v.draw_arc(p, 9.0, 0, TAU, 20, item.color, 2.5)
			_star(v, p, item.color, 5.0)


static func _star(v: MapView, p: Vector2, color: Color, r: float) -> void:
	var points := PackedVector2Array([p + Vector2(0, -r * 1.4), p + Vector2(r, 0), p + Vector2(0, r * 1.4), p + Vector2(-r, 0)])
	v.draw_colored_polygon(points, color)
	v.draw_polyline(points + PackedVector2Array([points[0]]), Color.BLACK, 1.0)
