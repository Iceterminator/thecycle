extends RefCounted
## Onglet Factions du lobby : faction de prédilection, réputation et déblocages par niveau.

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const Catalog := preload("res://systems/lobby/lobby_ui_catalog.gd")
const DIM := UiStyle.DIM

var faction_cards: Array[Dictionary] = []   # { id, card }
var progress_columns: Array[Dictionary] = []


func build(lobby: LobbyUi) -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	box.add_child(W.label("FACTION DE PRÉDILECTION — +%d %% de réputation avec elle" % roundi(Config.economy.preferred_faction_bonus * 100.0), 16, DIM))
	var factions := HBoxContainer.new()
	factions.add_theme_constant_override("separation", 10)
	box.add_child(factions)
	var none := UiCard.make(Vector2(180, 60))
	none.set_content("Aucune", "", "", Color(0.5, 0.5, 0.5))
	none.pressed.connect(func() -> void:
		lobby._preferred = 0
		lobby._changed())
	factions.add_child(none)
	faction_cards.append({"id": 0, "card": none})
	for f in FactionData.all():
		var card := UiCard.make(Vector2(180, 60))
		card.set_content(FactionData.name_of(f.id), "", "", f.color)
		var fid := f.id
		card.pressed.connect(func() -> void:
			lobby._preferred = fid
			lobby._changed())
		factions.add_child(card)
		faction_cards.append({"id": fid, "card": card})
	box.add_child(W.label("RÉPUTATION — gagnée avec les contrats de chaque faction ; chaque niveau débloque des objets", 16, DIM))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	box.add_child(columns)
	var unlocks := Catalog.unlock_table(lobby._catalog)
	for f in FactionData.all():
		_build_column(columns, f, unlocks.get(f.id, {}))
	return scroll


func _build_column(columns: HBoxContainer, f: FactionData, faction_unlocks: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.11, 0.95)
	style.border_color = f.color
	style.border_width_top = 4
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	columns.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	col.add_child(W.label(FactionData.name_of(f.id), 26, f.color))
	var level_label := W.label("", 20)
	col.add_child(level_label)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = f.color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.08)
	back.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", back)
	col.add_child(bar)
	var points := W.label("", 14, Color(1, 1, 1, 0.7))
	col.add_child(points)
	col.add_child(HSeparator.new())
	var rows: Array[Dictionary] = []
	for level in range(1, Config.economy.rep_levels.size() + 1):
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var mark := W.label("·", 16)
		mark.custom_minimum_size = Vector2(20, 0)
		line.add_child(mark)
		var names: Array = faction_unlocks.get(level, [])
		var text := W.label("Niv. %d (%d pts) : %s" % [level, Config.economy.rep_levels[level - 1], ", ".join(names) if not names.is_empty() else "—"], 14)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size = Vector2(200, 0)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(text)
		col.add_child(line)
		rows.append({"level": level, "label": line, "mark": mark})
	progress_columns.append({"faction": f.id, "level": level_label, "bar": bar, "points": points, "rows": rows})


func refresh(lobby: LobbyUi) -> void:
	for e in faction_cards:
		(e["card"] as UiCard).set_state(int(e["id"]) == lobby._preferred, false)
	for col in progress_columns:
		var faction: int = col["faction"]
		var points := ProfileManager.rep_points(lobby._me(), faction)
		var level := ProfileManager.rep_level_of_points(points)
		var maxed := level >= Config.economy.rep_levels.size()
		var previous: int = Config.economy.rep_levels[level - 1] if level > 0 else 0
		var next: int = previous if maxed else Config.economy.rep_levels[level]
		(col["level"] as Label).text = "NIVEAU %d" % level
		var bar: ProgressBar = col["bar"]
		bar.max_value = maxf(next - previous, 1)
		bar.value = bar.max_value if maxed else points - previous
		(col["points"] as Label).text = "%d points — niveau maximum" % points if maxed \
				else "%d / %d points → niveau %d" % [points, next, level + 1]
		for row: Dictionary in col["rows"]:
			var unlocked: bool = level >= int(row["level"])
			(row["label"] as Control).modulate = Color(1, 1, 1, 1.0) if unlocked else Color(1, 1, 1, 0.38)
			(row["mark"] as Label).text = "✔" if unlocked else "·"
