extends RefCounted
## Mises à jour du HUD : classement, objectifs de Fame, escouade, textes flottants des quêtes.

const HudWidgets := preload("res://systems/combat/hud_widgets.gd")


static func update_leaders(hud: CombatHud) -> void:
	var players: Array[Player] = []
	for node in hud._player.get_parent().get_children():
		if node is Player:
			players.append(node as Player)
	players.sort_custom(func(a: Player, b: Player) -> bool: return a.score.rank_points > b.score.rank_points)
	var rank := players.find(hud._player) + 1
	hud._rank_label.text = "%d%s" % [rank, "er" if rank == 1 else "e"]
	for child in hud._leaders_box.get_children():
		child.queue_free()
	for i in mini(players.size(), 3):
		var p := players[i]
		var label := HudWidgets.make_label("%d  %s   %d ★" % [i + 1, ProfileManager.name_of(p.get_peer_id()), p.score.rank_points], 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if p == hud._player:
			label.add_theme_color_override("font_color", CombatHud.GOLD)
		hud._leaders_box.add_child(label)



static func on_score_changed(hud: CombatHud) -> void:
	hud._fame_label.text = "★ %d" % hud._player.score.rank_points
	# Une ligne par objectif commencé : progression vers le prochain palier.
	for child in hud._objectives_box.get_children():
		child.queue_free()
	var objectives: Dictionary = hud._player.score.objective_points
	var rates: Dictionary = hud._player.score.objective_rates
	var paths: Array = objectives.keys()
	for path: String in rates:
		if not paths.has(path):
			paths.append(path)
	for path: String in paths:
		var track := load(path) as ObjectiveTrack
		if track == null:
			continue
		var pts: int = objectives.get(path, 0)
		var tier := track.tiers_reached(pts)
		var goal := track.threshold(tier)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		var dot := ColorRect.new()
		dot.color = track.color
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 1)
		row.add_child(col)
		var rate: float = rates.get(path, 0.0)
		var line := HudWidgets.make_label("%s   %d / %d   ★ +%d%s" % [track.display_name, pts, goal, track.reward(tier),
				"   (+%.1f/s)" % rate if rate > 0.0 else ""], 14)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(line)
		var bar := HudWidgets.make_bar(track.color, maxf(goal, 1.0))
		bar.custom_minimum_size = Vector2(190, 4)
		bar.value = pts
		col.add_child(bar)
		hud._objectives_box.add_child(row)



static func update_squad(hud: CombatHud) -> void:
	var allies: Array[Player] = []
	for node in hud._player.get_parent().get_children():
		var p := node as Player
		if p and p != hud._player and Allies.allied(hud._player.get_peer_id(), p.get_peer_id()):
			allies.append(p)
	var key := ",".join(allies.map(func(p: Player) -> String: return p.name))
	if key != hud._squad_key:
		hud._squad_key = key
		for child in hud._squad_box.get_children():
			child.queue_free()
		for p in allies:
			var row := VBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override("separation", 1)
			row.set_meta("peer", p.get_peer_id())
			var label := HudWidgets.make_label(ProfileManager.name_of(p.get_peer_id()), 15)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.add_child(label)
			var shield := HudWidgets.make_bar(CombatHud.SHIELD, 1.0)
			shield.custom_minimum_size = Vector2(190, 4)
			row.add_child(shield)
			var health := HudWidgets.make_bar(CombatHud.HEALTH, 1.0)
			health.custom_minimum_size = Vector2(190, 6)
			row.add_child(health)
			hud._squad_box.add_child(row)
	for row in hud._squad_box.get_children():
		var p := hud._player.get_parent().get_node_or_null(str(row.get_meta("peer", 0))) as Player
		if p == null or row.get_child_count() < 3:
			continue
		var h := p.health
		var label := row.get_child(0) as Label
		label.text = ProfileManager.name_of(p.get_peer_id()) + ("  — À TERRE" if h.is_downed else "  — mort" if h.is_dead else "")
		var shield := row.get_child(1) as ProgressBar
		shield.max_value = maxf(h.max_shield, 1.0)
		shield.value = h.shield
		var health := row.get_child(2) as ProgressBar
		health.max_value = maxf(h.get_max_health(), 1.0)
		health.value = h.health



static func update_quest_tags(hud: CombatHud) -> void:
	for node in hud.get_tree().get_nodes_in_group("map_marker"):
		if node.has_method("set_map_tag_visible"):
			node.set_map_tag_visible(MapView.in_reveal_range((node as Node3D).global_position, hud._player.global_position))
