extends RefCounted
## Événements du jeu d'origine sur la carte, visibles de TOUS à n'importe quelle distance :
## cristaux de surtension au sol et boss (Alpha). Dessine sur le MapView `v`, pendant son _draw().


static func draw(v: MapView) -> void:
	var loot := v.world.get_node_or_null("Loot")
	if loot:
		for node in loot.get_children():
			var pickup := node as Pickup
			if pickup and pickup.item and pickup.item.id == SurgeCrystals.ITEM:
				_crystal(v, v.to_map(pickup.global_position), pickup.item.color)
	var monsters := v.world.get_node_or_null("Monsters")
	if monsters == null:
		return
	for node in monsters.get_children():
		var boss := node as Monster
		if boss and boss.data and boss.data.boss and boss.health > 0.0:
			var p := v.to_map(boss.global_position)
			v.draw_circle(p, 8.0, boss.data.color)
			v.draw_arc(p, 8.0, 0, TAU, 20, Color.WHITE, 2.0)
			v.draw_arc(p, 12.0, 0, TAU, 24, boss.data.color, 1.5)


static func _crystal(v: MapView, p: Vector2, color: Color) -> void:
	var points := PackedVector2Array([p + Vector2(0, -9), p + Vector2(6, 0), p + Vector2(0, 9), p + Vector2(-6, 0)])
	v.draw_colored_polygon(points, color)
	v.draw_polyline(points + PackedVector2Array([points[0]]), Color.BLACK, 1.0)
	v.draw_arc(p, 12.0, 0, TAU, 20, color, 1.5)
