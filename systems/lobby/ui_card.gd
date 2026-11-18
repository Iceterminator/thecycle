class_name UiCard
extends Button
## Carte cliquable des menus (lobby, boutique) : un titre, une ligne de détail, une icône
## d'arme facultative, une ligne d'info (prix, verrou…) et un liseré de couleur (faction).
## Sélectionnée = bordure vert menthe ; verrouillée = assombrie, bordure rouge et cadenas
## (reste cliquable pour voir sa fiche, sauf si `disabled`).

const ACCENT := UiStyle.ACCENT
const LOCKED := UiStyle.LOCKED

var _title: Label
var _sub: Label
var _info: Label
var _visual_slot: Control  ## emplacement du visuel (arme, capacité ou kit)
var _visual: Control
var _lock: LockIcon
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
	margin.add_theme_constant_override("margin_left", 14)
	card.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)
	card._title = card._label(box, 19, Color.WHITE)
	card._title.add_theme_font_override("font", UiStyle.font("SemiBold"))
	card._sub = card._label(box, 13, Color(1, 1, 1, 0.65))
	# Une ligne (coupée par « … ») : le visuel garde toute la place libre.
	card._sub.visible = false
	card._visual_slot = Control.new()
	card._visual_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card._visual_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card._visual_slot.custom_minimum_size = Vector2(0, 44)
	card._visual_slot.visible = false
	box.add_child(card._visual_slot)
	card._info = card._label(box, 15, UiStyle.GOLD)
	card._info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	card._lock = LockIcon.new()
	card._lock.visible = false
	card.add_child(card._lock)
	card._lock.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	card._lock.offset_left = -30
	card._lock.offset_right = -10
	card._lock.offset_top = 10
	card._lock.offset_bottom = 34
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
	_sub.visible = sub != ""
	_info.text = info
	_accent = accent
	_restyle()


func set_info(info: String, color: Color = Color(1, 0.82, 0.4)) -> void:
	_info.text = info
	_info.add_theme_color_override("font_color", color)


## Visuel de l'objet `id` (arme, gadget, capacité ou kit) dans la carte ; "" = aucun.
func set_visual(id: String) -> void:
	if _visual and _visual.get_meta("id", "") == id:
		return
	if _visual:
		_visual.queue_free()
	_visual = ItemVisual.make(id)
	_visual_slot.visible = _visual != null
	if _visual:
		_visual.set_meta("id", id)
		_visual_slot.add_child(_visual)
		_visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ItemVisual.set_colors(_visual, _locked)


func set_state(selected: bool, locked: bool) -> void:
	if selected == _selected and locked == _locked:
		return
	_selected = selected
	_locked = locked
	_restyle()


func _restyle() -> void:
	var base := UiStyle.CARD
	var border := Color(_accent.darkened(0.15), 0.75)
	if _selected:
		base = UiStyle.CARD_SELECTED
		border = ACCENT
	if _locked:
		base = UiStyle.CARD_LOCKED
		border = LOCKED.darkened(0.25) if not _selected else ACCENT
	add_theme_stylebox_override("normal", _style(base, border, 3 if _selected else 1))
	add_theme_stylebox_override("hover", _style(UiStyle.CARD_HOVER if not (_selected or _locked) else base.lightened(0.08), border.lightened(0.25), 3 if _selected else 2))
	add_theme_stylebox_override("pressed", _style(base.lightened(0.15), border.lightened(0.4), 3))
	add_theme_stylebox_override("disabled", _style(Color(0.07, 0.07, 0.08, 0.9), Color(0.25, 0.25, 0.25), 1))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if _title:
		_title.modulate = Color(1, 1, 1, 0.55) if _locked else Color.WHITE
		_sub.modulate = Color(1, 1, 1, 0.55) if _locked else Color.WHITE
		ItemVisual.set_colors(_visual, _locked)
		_lock.visible = _locked


func _style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	# Coins coupés ; le liseré du bas, plus épais, porte la couleur de la faction.
	var s := UiStyle.chamfer_box(bg, border, width, UiStyle.CHAMFER)
	s.border_width_bottom = maxi(width, 3)
	return s
