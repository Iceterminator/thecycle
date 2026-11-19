extends RefCounted
## Petits widgets partagés par l'écran du lobby et ses onglets (fonctions statiques, sans état).


static func panel(min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	return panel


static func box_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := UiStyle.chamfer_box(bg, border, width, 6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	return s


## Style arrondi plus grand (boutons de la page Équipement).
static func round_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := UiStyle.chamfer_box(bg, border, 2, 10)
	s.content_margin_left = 14
	s.content_margin_right = 14
	return s


static func flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	return flow


static func label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	if size >= 20:
		label.add_theme_font_override("font", UiStyle.font("SemiBold"))
	label.add_theme_color_override("font_color", color)
	return label


static func clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


static func action(text: String, enabled: bool, callback: Callable) -> Button:
	var accent := UiStyle.ACCENT
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.custom_minimum_size = Vector2(0, 40)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_stylebox_override("normal", box_style(Color(0.13, 0.21, 0.31), Color(accent, 0.55), 1))
	button.add_theme_stylebox_override("hover", box_style(Color(0.17, 0.27, 0.39), accent, 1))
	button.add_theme_stylebox_override("pressed", box_style(Color(0.26, 0.2, 0.13), accent, 2))
	button.add_theme_stylebox_override("disabled", box_style(Color(0.08, 0.11, 0.15), Color(1, 1, 1, 0.1), 1))
	button.pressed.connect(callback)
	return button


## Gros bouton de la page Équipement (FERMER, CHANGER, ÉQUIPER).
static func big_button(text: String, primary: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(200, 50)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_font_override("font", UiStyle.font("Bold"))
	var color := UiStyle.ACCENT if primary else Color(1, 1, 1, 0.5)
	button.add_theme_stylebox_override("normal", round_box(Color(color, 0.12), color))
	button.add_theme_stylebox_override("hover", round_box(Color(color, 0.3), color))
	button.add_theme_stylebox_override("pressed", round_box(Color(color, 0.5), color))
	button.add_theme_stylebox_override("disabled", round_box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.15)))
	button.pressed.connect(callback)
	return button


## Bouton PRÊT à bascule ; on_toggled reçoit l'état (bool).
static func ready_toggle(min_size: Vector2, font: int, on_toggled: Callable) -> Button:
	var accent := UiStyle.ACCENT
	var button := Button.new()
	button.toggle_mode = true
	button.text = "PRÊT"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", font)
	button.add_theme_color_override("font_color", Color(0.05, 0.08, 0.07))
	button.add_theme_color_override("font_pressed_color", Color(0.05, 0.08, 0.07))
	button.add_theme_color_override("font_hover_color", Color(0.05, 0.08, 0.07))
	button.add_theme_font_override("font", UiStyle.font("Bold"))
	var ready_color := Color(0.5, 0.92, 0.6)  # vert : prêt
	button.add_theme_stylebox_override("normal", box_style(accent, accent, 0))
	button.add_theme_stylebox_override("hover", box_style(accent.lightened(0.2), accent, 0))
	button.add_theme_stylebox_override("pressed", box_style(ready_color, ready_color, 0))
	button.add_theme_stylebox_override("hover_pressed", box_style(ready_color.lightened(0.2), ready_color, 0))
	button.toggled.connect(on_toggled)
	return button
