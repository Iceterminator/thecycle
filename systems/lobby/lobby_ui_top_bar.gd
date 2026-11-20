extends RefCounted
## Barre du haut du lobby : escouade, onglets, statut, pseudo, compte à rebours, bouton PRÊT.

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const ACCENT := UiStyle.ACCENT
const GOLD := UiStyle.GOLD
const DIM := UiStyle.DIM

var nav: Array[Button] = []
var squad_chip: Label
var countdown: Label
var status: Label


func build(lobby: LobbyUi) -> Control:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UiStyle.BAR
	style.content_margin_left = 18
	style.content_margin_right = 18
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	squad_chip = W.label("ESCOUADE 1/4", 15, DIM)
	squad_chip.custom_minimum_size = Vector2(130, 0)
	squad_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(squad_chip)
	for i in 5:
		var button := Button.new()
		button.text = ["DÉCOLLAGE", "ÉQUIPEMENT", "ARSENAL", "FACTIONS", "ESCOUADE"][i]
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(150, 60)
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_font_override("font", UiStyle.font("SemiBold"))
		var page := i
		button.pressed.connect(func() -> void:
			if page != LobbyUi.Page.ARSENAL:
				lobby._selected_case = -1
			lobby._show_page(page))
		row.add_child(button)
		nav.append(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	status = W.label("", 14)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(status)
	var me := W.label(ProfileManager.name_of(lobby._me()), 16, GOLD)
	me.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	me.custom_minimum_size = Vector2(110, 0)
	me.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(me)
	countdown = W.label("", 18)
	countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown.custom_minimum_size = Vector2(150, 0)
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(countdown)
	return bar


## Met en évidence l'onglet actif.
func style_nav(page: int) -> void:
	for i in nav.size():
		var active := i == page
		var style := StyleBoxFlat.new()
		style.bg_color = Color(ACCENT, 0.12) if active else Color(0, 0, 0, 0)
		style.border_color = ACCENT
		style.border_width_bottom = 3 if active else 0
		for state in ["normal", "hover", "pressed"]:
			nav[i].add_theme_stylebox_override(state, style)
		nav[i].add_theme_color_override("font_color", ACCENT if active else Color(1, 1, 1, 0.75))
		nav[i].add_theme_color_override("font_hover_color", ACCENT.lightened(0.2))


func set_status(text: String, color: Color) -> void:
	status.text = text
	status.add_theme_color_override("font_color", color)
