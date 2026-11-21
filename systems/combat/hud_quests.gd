extends RefCounted
## Liste des quêtes du HUD (sous la minicarte) : une ligne par type de quête tiré.
## Objectif commencé : pastille (jauge jaune = progression du palier) + « points / palier - ★ Fame ».
## Pas encore commencé (ou sans points, ex. Drones) : pastille + nom de la quête.

const OBJECTIVES_DIR := "res://data/objectives/"
const BADGE_SIZE := 63.0


static func rebuild(hud: CombatHud) -> void:
	for child in hud._objectives_box.get_children():
		child.queue_free()
	var points: Dictionary = hud._player.score.objective_points
	var rates: Dictionary = hud._player.score.objective_rates
	var shown: Array = []
	var quests := hud._player.get_parent().get_parent().get_node_or_null("QuestManager") as QuestManager
	var drawn: Array = quests.drawn_list if quests else []
	for entry: Dictionary in drawn:
		var path := OBJECTIVES_DIR + str(entry.get("objective", "")) + ".tres"
		if str(entry.get("objective", "")) != "" and (points.has(path) or rates.has(path)):
			_add_track_row(hud, path, points, rates)
			shown.append(path)
		else:
			var name := _mark(hud, str(entry.get("objective", ""))) + str(entry["name"]) + ("   (plus tard)" if entry.get("later", false) else "")
			_add_row(hud, QuestBadge.make(QuestIcons.of(str(entry.get("icon", ""))), entry.get("color", Color.WHITE),
					BADGE_SIZE, 0.0), name)
			shown.append(path)
	# Objectifs commencés hors tirage (s'il y en a) : à la suite.
	for path: String in points.keys() + rates.keys():
		if not shown.has(path):
			_add_track_row(hud, path, points, rates)
			shown.append(path)
	# Contrats actifs sans ligne (ex. la Prime, qui n'a pas de quête sur la carte).
	var board := ContractBoard.current
	for id in board.active if board else PackedStringArray():
		var active_path := OBJECTIVES_DIR + id + ".tres"
		var track := load(active_path) as ObjectiveTrack
		if track and not shown.has(active_path):
			_add_row(hud, QuestBadge.make(track.icon, track.color, BADGE_SIZE, 0.0), _mark(hud, id) + track.display_name)
			shown.append(active_path)


static func _add_track_row(hud: CombatHud, path: String, points: Dictionary, rates: Dictionary) -> void:
	var track := load(path) as ObjectiveTrack
	if track == null:
		return
	var pts: int = points.get(path, 0)
	var tier := track.tiers_reached(pts)
	var goal := track.threshold(tier)
	var previous := track.threshold(tier - 1) if tier > 0 else 0
	var ratio := float(pts - previous) / maxf(goal - previous, 1.0)
	var text := _mark(hud, String(track.id)) + "%d / %d   -   ★ %d" % [pts, goal, track.reward(tier)]
	var rate: float = rates.get(path, 0.0)
	if rate > 0.0:
		text += "   (Production : %s/seconde)" % String.num(rate, 1).replace(".", ",")
	_add_row(hud, QuestBadge.make(track.icon, track.color, BADGE_SIZE, ratio), text)


static func _add_row(hud: CombatHud, badge: QuestBadge, text: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	row.add_child(badge)
	row.add_child(_label(text))
	hud._objectives_box.add_child(row)


## Texte d'une ligne : Barlow, blanc, ombre douce (lisible sur le décor, sans contour).
static func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UiStyle.text_font("Medium"))
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 4)
	return label


## Pastille devant un contrat actif du joueur (tableau de contrats).
static func _mark(_hud: CombatHud, objective_id: String) -> String:
	var board := ContractBoard.current
	return "◆ " if board and objective_id != "" and board.active.has(objective_id) else ""
