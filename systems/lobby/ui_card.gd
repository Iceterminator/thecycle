class_name UiCard
extends Button
## Carte cliquable des menus (lobby, boutique) : un titre, une ligne de détail, une ligne
## d'info (prix, verrou…) et un liseré de couleur (faction). Sélectionnée = bordure épaisse ;
## verrouillée = grisée (mais cliquable si `allow_locked`, pour voir l'info).

var _title: Label
var _sub: Label
var _info: Label
var _accent: Color = Color(0.6, 0.7, 0.8)
var _selected: bool = false
var _locked: bool = false


static func make(min_size: Vector2 = Vector2(190, 92)) -> UiCard:
	var card := UiCard.new()
	card.custom_minimum_size = min_size
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE
	card.clip_contents = true
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)
	card._title = card._label(box, 18, Color.WHITE)
	card._sub = card._label(box, 13, Color(1, 1, 1, 0.65))
	card._sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card._sub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card._info = card._label(box, 14, Color(1, 0.85, 0.4))
	card._restyle()
	return card


func _label(box: VBoxContainer, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(label)
	return label


func set_content(title: String, sub: String, info: String, accent: Color = Color(0.6, 0.7, 0.8)) -> void:
	_title.text = title
	_sub.text = sub
	_info.text = info
	_accent = accent
	_restyle()


func set_info(info: String, color: Color = Color(1, 0.85, 0.4)) -> void:
	_info.text = info
	_info.add_theme_color_override("font_color", color)


func set_state(selected: bool, locked: bool) -> void:
	if selected == _selected and locked == _locked:
		return
	_selected = selected
	_locked = locked
	_restyle()


func _restyle() -> void:
	var base := Color(0.10, 0.11, 0.14, 0.95)
	var border := _accent.darkened(0.35)
	if _selected:
		base = Color(0.14, 0.18, 0.16, 0.98)
		border = Color(0.55, 1.0, 0.6)
	if _locked:
		base = Color(0.07, 0.07, 0.08, 0.9)
		border = Color(0.3, 0.3, 0.3)
	add_theme_stylebox_override("normal", _style(base, border, 3 if _selected else 1))
	add_theme_stylebox_override("hover", _style(base.lightened(0.08), border.lightened(0.25), 3 if _selected else 2))
	add_theme_stylebox_override("pressed", _style(base.lightened(0.15), border.lightened(0.4), 3))
	add_theme_stylebox_override("disabled", _style(Color(0.07, 0.07, 0.08, 0.9), Color(0.25, 0.25, 0.25), 1))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if _title:
		_title.modulate = Color(1, 1, 1, 0.4) if _locked else Color.WHITE
		_sub.modulate = Color(1, 1, 1, 0.5) if _locked else Color.WHITE


func _style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.border_width_left = maxi(width, 5)  # liseré de couleur à gauche
	s.set_corner_radius_all(6)
	return s
