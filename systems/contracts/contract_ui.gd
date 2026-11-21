class_name ContractUi
extends CanvasLayer
## Tableau de contrats du joueur local : s'ouvre au largage et avec la touche J. Liste les contrats
## proposés (faction, paliers) avec Activer / Abandonner. Tout est vérifié par le ContractBoard (serveur).

const COLOR := Color(1.0, 0.75, 0.3)

var _player: Player
var _list: VBoxContainer


func setup(player: Player) -> void:
	_player = player
	layer = 11
	visible = false
	_build()
	Events.contracts_changed.connect(_refresh)
	Events.drop_phase_started.connect(func(_points: Array, _seconds: float) -> void: open())


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("contracts") or event.is_action_pressed("toggle_mouse"):
			close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("contracts") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		open()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _board() -> ContractBoard:
	return ContractBoard.current


func _refresh() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var board := _board()
	if board == null or board.offered.is_empty():
		var empty := Label.new()
		empty.text = "Aucun contrat proposé pour l'instant."
		_list.add_child(empty)
		return
	for id in board.offered:
		var track := ContractBoard.track_of(id)
		if track:
			_list.add_child(_row(board, id, track))


func _row(board: ContractBoard, id: String, track: ObjectiveTrack) -> Control:
	var is_active := board.active.has(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "%s  -  %s%s" % [track.display_name, FactionData.name_of(track.faction), "   (ACTIF)" if is_active else ""]
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", COLOR if is_active else track.color.lightened(0.3))
	text.add_child(title)
	var detail := Label.new()
	detail.text = _tiers_text(track)
	detail.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	text.add_child(detail)
	row.add_child(text)
	var button := Button.new()
	button.custom_minimum_size = Vector2(130, 36)
	if is_active:
		button.text = "Abandonner"
		button.pressed.connect(func() -> void: board.request_abandon.rpc_id(1, id))
	else:
		button.text = "Activer"
		button.disabled = board.active.size() >= Config.match_rules.max_active_contracts
		button.pressed.connect(func() -> void: board.request_activate.rpc_id(1, id))
	row.add_child(button)
	return row


static func _tiers_text(track: ObjectiveTrack) -> String:
	if track.id == &"prime":
		return "%d Fame par joueur éliminé tant que la Prime est active" % Config.economy.bounty_kill_fame
	var parts: PackedStringArray = []
	for tier in 3:
		parts.append("%d pts (★ %d)" % [track.threshold(tier), track.reward(tier)])
	return "Paliers : " + "  /  ".join(parts)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.95)
	style.border_color = COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(700, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "CONTRATS"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var rules := Label.new()
	rules.text = "%d contrats actifs au plus. La réputation de faction n'est gagnée que sur les contrats actifs." % Config.match_rules.max_active_contracts
	rules.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	box.add_child(rules)
	box.add_child(HSeparator.new())
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	box.add_child(_list)
	box.add_child(HSeparator.new())
	var hint := Label.new()
	hint.text = "J ou Échap : fermer"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	box.add_child(hint)
