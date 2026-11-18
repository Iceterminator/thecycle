class_name PactUi
extends CanvasLayer
## Menu Pactes (touche P, joueur local) : proposer un pacte, accepter / refuser une
## proposition reçue, rompre son pacte (trahison). Tout est vérifié par le PactManager.

var _player: Player
var _list: VBoxContainer
var _refresh_left: float = 0.0


func setup(player: Player) -> void:
	_player = player
	layer = 11
	visible = false
	_build()


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("pact") or event.is_action_pressed("toggle_mouse"):
			close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
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


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.3
		_refresh()


func _manager() -> PactManager:
	return _player.get_parent().get_parent().get_node_or_null("PactManager") as PactManager


func _refresh() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var manager := _manager()
	if manager == null:
		return
	var me := _player.get_peer_id()
	var partner := PactManager.partner_of(me)
	var proposer := PactManager.proposal_for(me)
	var players := _player.get_parent()
	for node in players.get_children():
		var other := node as Player
		if other == null or other == _player:
			continue
		var id := other.get_peer_id()
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := Label.new()
		name_label.text = "%s — %d Fame" % [ProfileManager.name_of(id), other.score.rank_points]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 18)
		row.add_child(name_label)
		if id == partner:
			name_label.text += "   (partenaire)"
			name_label.add_theme_color_override("font_color", PactManager.COLOR)
			row.add_child(_button("Rompre (trahir)", func() -> void: manager.request_break.rpc_id(1)))
		elif id == proposer:
			name_label.text += "   vous propose un pacte"
			row.add_child(_button("Accepter", func() -> void: manager.request_answer.rpc_id(1, id, true)))
			row.add_child(_button("Refuser", func() -> void: manager.request_answer.rpc_id(1, id, false)))
		else:
			var b := _button("Proposer un pacte", func() -> void: manager.request_propose.rpc_id(1, id))
			b.disabled = partner != 0 or PactManager.partner_of(id) != 0
			row.add_child(b)
		_list.add_child(row)
	if _list.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "Aucun autre joueur dans la partie."
		_list.add_child(empty)


func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 34)
	b.pressed.connect(on_pressed)
	return b


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
	style.border_color = PactManager.COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PACTES"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	var rules := Label.new()
	rules.text = "Partenaires : pas de dégâts entre vous, Fame des contrats partagée moitié / moitié,\nrelève quand l'autre est à terre. Rompre le pacte prévient l'autre (trahison)."
	rules.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	box.add_child(rules)
	box.add_child(HSeparator.new())
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	box.add_child(_list)
	box.add_child(HSeparator.new())
	var hint := Label.new()
	hint.text = "P ou Échap : fermer"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	box.add_child(hint)
