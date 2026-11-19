extends RefCounted
## Construction des widgets de l'onglet Arsenal (catégories, filtres, grille, fiche).
## Remplit les champs du LobbyUiArsenal reçu (a : untyped pour éviter un préchargement circulaire).

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const ACCENT := UiStyle.ACCENT


static func build(lobby: LobbyUi, a: RefCounted) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	var cats := VBoxContainer.new()
	cats.custom_minimum_size = Vector2(220, 0)
	cats.add_theme_constant_override("separation", 4)
	row.add_child(cats)
	for i in LobbyUi.CAT_NAMES.size():
		var button := Button.new()
		button.text = LobbyUi.CAT_NAMES[i]
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 20)
		var cat := i
		button.pressed.connect(func() -> void:
			a.cat = cat
			a.sel = {}
			refresh_cat_buttons(a)
			a.rebuild_grid(lobby))
		cats.add_child(button)
		a.cat_buttons.append(button)
	refresh_cat_buttons(a)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	row.add_child(center)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 10)
	center.add_child(filters)
	a.sort_opt = OptionButton.new()
	for text in ["Prix le plus bas", "Prix le plus haut", "Nom"]:
		a.sort_opt.add_item(text)
	a.sort_opt.item_selected.connect(func(_i: int) -> void: a.rebuild_grid(lobby))
	filters.add_child(a.sort_opt)
	a.faction_opt = OptionButton.new()
	a.faction_opt.add_item("Toutes les factions")
	a.faction_opt.add_item("Départ")
	for f in FactionData.all():
		a.faction_opt.add_item(FactionData.name_of(f.id))
	a.faction_opt.item_selected.connect(func(_i: int) -> void: a.rebuild_grid(lobby))
	filters.add_child(a.faction_opt)
	a.pick_hint = W.label("", 15, ACCENT)
	a.pick_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(a.pick_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)
	a.grid_box = VBoxContainer.new()
	a.grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.grid_box.add_theme_constant_override("separation", 8)
	scroll.add_child(a.grid_box)

	var detail := W.panel(Vector2(470, 0))
	row.add_child(detail)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(detail_scroll)
	a.detail_box = VBoxContainer.new()
	a.detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.detail_box.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(a.detail_box)
	return row


static func refresh_cat_buttons(a: RefCounted) -> void:
	for i in a.cat_buttons.size():
		var active: bool = i == a.cat
		var style := StyleBoxFlat.new()
		style.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.14) if active else Color(0, 0, 0, 0)
		style.border_color = ACCENT
		style.border_width_left = 4 if active else 0
		style.content_margin_left = 14
		for state in ["normal", "hover", "pressed"]:
			a.cat_buttons[i].add_theme_stylebox_override(state, style)
		a.cat_buttons[i].add_theme_color_override("font_color", ACCENT if active else Color(1, 1, 1, 0.8))
