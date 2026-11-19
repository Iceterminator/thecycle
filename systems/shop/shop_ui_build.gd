extends RefCounted
## Construction de l'interface de la boutique (ShopUi) : fond, panneau, en-tête, trois colonnes.
## Remplit les membres de `ui` (étiquettes et colonnes) ; ne contient pas de logique de jeu.

static func build(ui: ShopUi) -> void:
	# Fond assombri qui capte les clics (ils ne doivent pas atteindre le jeu).
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.BG_TOP, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var style := UiStyle.panel_box()
	style.bg_color = Color(UiStyle.PANEL, 0.97)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	panel.theme = UiStyle.theme()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(880, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "BOUTIQUE"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_font_override("font", UiStyle.font("Bold"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	ui._credits_label = Label.new()
	ui._credits_label.add_theme_font_size_override("font_size", 24)
	ui._credits_label.add_theme_color_override("font_color", UiStyle.GOLD)
	ui._credits_label.add_theme_font_override("font", UiStyle.font("SemiBold"))
	header.add_child(ui._credits_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	box.add_child(columns)
	ui._gadget_col = _column(columns, "GADGETS ET CAPACITÉS — achetés, puis Q ou F ; déjà équipés : améliorer / recharger")
	ui._weapon_col = _column(columns, "ARMES — largage en %d s (livrées au palier acheté)" % int(Config.DROP_POD_FALL_TIME))
	ui._upgrade_col = _column(columns, "AMÉLIORATION — palier suivant de l'arme (gardé pour la partie)")

	ui._pending_label = Label.new()
	ui._pending_label.add_theme_color_override("font_color", UiStyle.ACCENT)
	ui._pending_label.add_theme_font_size_override("font_size", 18)
	box.add_child(ui._pending_label)
	ui._status_label = Label.new()
	ui._status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ui._status_label)
	var hint := Label.new()
	hint.text = "T ou Échap : fermer — la boutique se configure dans le lobby (onglet Boutique)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	box.add_child(hint)


static func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiStyle.DIM)
	return label


## Une colonne de la boutique (titre + cartes), ajoutée à `parent`.
static func _column(parent: HBoxContainer, title: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var label := _section(title)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(270, 64)
	column.add_child(label)
	var cards := VBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	column.add_child(cards)
	return cards
