extends RefCounted
## Couches « entités » de la carte (MapView) : repères de quêtes, monstres, joueurs repérés,
## partenaires / scanner, butin au sol. Dessine sur le MapView `v`, pendant son _draw().

static func draw_markers(v: MapView) -> void:
	for node in v.get_tree().get_nodes_in_group("map_marker"):
		var marker := node as Node3D
		if marker == null or not marker.is_inside_tree() or not marker.has_method("map_info"):
			continue
		var info: Dictionary = marker.map_info()
		var kind: String = info.get("kind", "")
		var pos: Vector3 = info.get("position", marker.global_position)
		var always: bool = kind == "evac" or info.get("always", false)
		if not always and not (kind in MapView.NEARBY_KINDS and MapView.in_reveal_range(pos, v.player.global_position)):
			continue
		var p := v.to_map(pos)
		var color: Color = info.get("color", Color.WHITE)
		var title: String = String(info.get("text", "")).get_slice("\n", 0)
		var icon: Texture2D = info.get("icon")
		if icon:
			# Quête : son logo, teinté à sa couleur, à la place du nom.
			var half := Vector2(11, 11) * clampf(v._scale, 1.0, 1.6)
			v.draw_texture_rect(icon, Rect2(p - half - Vector2(1, 1), half * 2.0 + Vector2(2, 2)), false, Color(0, 0, 0, 0.8))
			v.draw_texture_rect(icon, Rect2(p - half, half * 2.0), false, color)
			continue
		match kind:
			"evac":
				v.draw_arc(p, 12.0 * v._scale, 0, TAU, 32, color, 2.5)
				if v.show_labels:
					v._text(p + Vector2(0, -12.0 * v._scale - 4), title, 15, color)
				continue
			"crystal":
				var diamond := PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, 0), p + Vector2(0, 7), p + Vector2(-6, 0)])
				v.draw_colored_polygon(diamond, color)
			_:
				v.draw_circle(p, 5.0, color)
				v.draw_arc(p, 5.0, 0, TAU, 12, Color.BLACK, 1.0)
		if v.show_labels:
			v._text(p + Vector2(0, -12), title, 13, color)


## Monstres vivants proches (position répliquée chez tous les clients).
static func draw_monsters(v: MapView) -> void:
	var monsters := v.world.get_node_or_null("Monsters")
	if monsters == null:
		return
	for node in monsters.get_children():
		var monster := node as Monster
		if monster == null or monster.health <= 0.0 or not MapView.in_reveal_range(monster.global_position, v.player.global_position):
			continue
		var p := v.to_map(monster.global_position)
		var radius := clampf(monster.data.radius * 4.0, 3.0, 6.0) if monster.data else 4.0
		v.draw_circle(p, radius, MapView.MONSTER_COLOR)
		v.draw_arc(p, radius, 0, TAU, 12, Color.BLACK, 1.0)


## Joueurs repérés par vos balises d'écoute (quelle que soit la distance), quelques secondes.
static func draw_revealed(v: MapView) -> void:
	var now := Time.get_ticks_msec()
	v._revealed = v._revealed.filter(func(r: Array) -> bool: return r[1] > now)
	for r: Array in v._revealed:
		var p := v.to_map(r[0])
		var diamond := PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)])
		v.draw_colored_polygon(diamond, Color(1.0, 0.2, 0.6))
		v.draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color.BLACK, 1.0)


## Partenaire de pacte (toujours) ; Scanner directionnel : joueurs non alliés à moins de
## Config.combat.scanner_range ; crédits et ressources au sol à moins de Config.MAP_REVEAL_RADIUS.
static func draw_scanner(v: MapView) -> void:
	var players := v.world.get_node_or_null("Players")
	if players:
		for node in players.get_children():
			var other := node as Player
			if other == null or other == v.player or other.health.is_dead or other.is_evacuated:
				continue
			var p := v.to_map(other.global_position)
			if Allies.allied(v.player.get_peer_id(), other.get_peer_id()):
				v.draw_circle(p, 6.0, Color(0.4, 1.0, 0.6))
				v.draw_arc(p, 6.0, 0, TAU, 16, Color.BLACK, 1.5)
			elif other.global_position.distance_to(v.player.global_position) <= Config.combat.scanner_range:
				var tri := PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, 5), p + Vector2(-6, 5)])
				v.draw_colored_polygon(tri, Color(1.0, 0.3, 0.25))
	var loot := v.world.get_node_or_null("Loot")
	if loot == null:
		return
	for node in loot.get_children():
		var pickup := node as Pickup
		if pickup == null or pickup.item == null:
			continue
		if pickup.item.kind != ItemData.Kind.CREDITS and pickup.item.kind != ItemData.Kind.RESOURCE:
			continue
		if not MapView.in_reveal_range(pickup.global_position, v.player.global_position):
			continue
		v.draw_circle(v.to_map(pickup.global_position), 3.0, pickup.item.color)
