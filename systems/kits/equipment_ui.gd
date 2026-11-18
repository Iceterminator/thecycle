class_name EquipmentUi
extends CanvasLayer
## Menu Équipement (touche K, joueur local) : choisir son kit.
## Le changement n'est accepté par le serveur qu'au largage / à la réapparition
## (Config.match_rules.kit_change_window s après) ou quand on est mort. Construit en code.

var _player: Player
var _kit: KitController
var _status_label: Label
var _window_label: Label
var _rows: Array[Dictionary] = []  # { kit, button }


func setup(player: Player, kit: KitController) -> void:
	_player = player
	_kit = kit
	layer = 11
	visible = false
	_build()
	kit.changed.connect(_refresh)
	kit.kit_result.connect(_on_result)


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("equipment") or event.is_action_pressed("toggle_mouse"):
			close()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("equipment") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		open()
		get_viewport().set_input_as_handled()


## Menu ouvert : les clics et la molette restent dans le menu.
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


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	if _window_label == null:
		return
	var open_now := _kit.can_change_kit_now()
	_window_label.text = "Changement possible maintenant" if open_now \
			else "Changement possible seulement au largage ou à la réapparition (%d s après)" % int(Config.match_rules.kit_change_window)
	_window_label.modulate = Color(0.5, 1.0, 0.5) if open_now else Color(1.0, 0.7, 0.4)
	for row in _rows:
		var data: KitData = row["kit"]
		var button: Button = row["button"]
		var current := String(data.id) == (_kit.kit_id if _kit.kit_id != "" else String(Config.start_loadout.default_kit))
		button.text = "Équipé" if current else "Équiper"
		button.disabled = current or not open_now


func _on_result(ok: bool, message: String) -> void:
	_status_label.text = message
	_status_label.modulate = Color(0.5, 1.0, 0.5) if ok else Color(1.0, 0.45, 0.4)
	if ok:
		close()


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
	style.border_color = Color(0.5, 0.9, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(820, 0)
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "ÉQUIPEMENT — kit"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	_window_label = Label.new()
	box.add_child(_window_label)
	box.add_child(HSeparator.new())
	for data in KitController.list_kits():
		box.add_child(_make_row(data))
	box.add_child(HSeparator.new())
	var note := Label.new()
	note.text = "Capacités et gadgets (Q / F) : achetez-les en boutique (T), puis Q ou F pour les équiper"
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	box.add_child(note)
	box.add_child(HSeparator.new())
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status_label)
	var hint := Label.new()
	hint.text = "K ou Échap : fermer — le kit change de niveau en partie (XP : kills, contrats)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	box.add_child(hint)


func _make_row(data: KitData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = KitController.kit_name(data)
	name_label.add_theme_font_size_override("font_size", 20)
	info.add_child(name_label)
	var hp := data.health if data.health > 0.0 else Config.combat.kit_default_health
	var sh := data.shield if data.shield > 0.0 else Config.combat.kit_default_shield
	var sp := data.move_speed_mps if data.move_speed_mps > 0.0 else Config.combat.kit_default_speed
	var stats := Label.new()
	stats.text = "PV %d — Bouclier %d — Vitesse %.1f m/s\n%s" % [hp, sh, sp, data.playstyle]
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.custom_minimum_size = Vector2(640, 0)
	stats.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	info.add_child(stats)
	var button := Button.new()
	button.custom_minimum_size = Vector2(120, 40)
	button.pressed.connect(func() -> void: _kit.request_kit.rpc_id(1, String(data.id)))
	row.add_child(button)
	_rows.append({"kit": data, "button": button})
	return row
