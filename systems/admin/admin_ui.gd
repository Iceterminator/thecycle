class_name AdminUi
extends CanvasLayer
## Interface du menu admin (joueur local), construite en code.
## 0 ouvre / ferme, Échap ferme. Pendant qu'elle est ouverte, la souris est libre
## (donc pas de tir, pas de visée, pas d'interaction). Le menu reste ouvert après
## chaque demande pour en enchaîner plusieurs.

const CREDIT_AMOUNTS: Array[int] = [100, 500, 1000, 5000]
const TIME_SKIPS: Array[float] = [60.0, 300.0, 600.0]

var _player: Player
var _admin: Admin
var _status_label: Label
var _status_tween: Tween


func setup(player: Player, admin: Admin) -> void:
	_player = player
	_admin = admin
	layer = 11
	visible = false
	_build()
	admin.admin_result.connect(_on_result)
	player.health.dead_changed.connect(func(dead: bool) -> void:
		if dead and visible:
			close())


func _input(event: InputEvent) -> void:
	if visible:
		if event.is_action_pressed("admin_menu") or event.is_action_pressed("toggle_mouse"):
			close()
			get_viewport().set_input_as_handled()
	# Pas d'ouverture par-dessus un autre menu (boutique) : la souris doit être capturée.
	elif event.is_action_pressed("admin_menu") and not _player.health.is_dead \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		open()
		get_viewport().set_input_as_handled()


## Menu ouvert : rien de ce que l'interface n'a pas pris (molette en bout de liste,
## clics) ne doit atteindre le jeu (changement d'arme, recapture de la souris).
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_result(ok: bool, message: String) -> void:
	_status_label.text = message
	_status_label.modulate = Color(0.5, 1.0, 0.5) if ok else Color(1.0, 0.45, 0.4)
	if _status_tween:
		_status_tween.kill()
	_status_tween = create_tween()
	_status_tween.tween_interval(2.5)
	_status_tween.tween_property(_status_label, "modulate:a", 0.0, 0.5)


func _build() -> void:
	# Fond assombri qui capte les clics (ils ne doivent pas atteindre le jeu).
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
	style.border_color = Color(0.7, 0.5, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := Label.new()
	title.text = "MENU ADMIN — apparaît devant vous"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	box.add_child(HSeparator.new())

	# --- Armes (toutes celles de data/weapons/) ---
	box.add_child(_section("Armes"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for item in Items.get_items_of_kind(ItemData.Kind.WEAPON):
		var button := _button(item.display_name, func() -> void:
			_admin.request_spawn_item.rpc_id(1, String(item.id), 1))
		button.tooltip_text = _weapon_tooltip(item.weapon)
		button.add_theme_color_override("font_color", item.color)
		grid.add_child(button)

	# --- Kits (équipés tout de suite) ---
	box.add_child(_section("Kits"))
	var kits_row := _row()
	box.add_child(kits_row)
	for kit_data in KitController.list_kits():
		var kit_button := _button(KitController.kit_name(kit_data), func() -> void:
			_admin.request_set_kit.rpc_id(1, String(kit_data.id)))
		kit_button.custom_minimum_size = Vector2(150, 34)
		kits_row.add_child(kit_button)

	# --- Crédits ---
	box.add_child(_section("Crédits (au sol)"))
	var credits_row := _row()
	box.add_child(credits_row)
	for amount in CREDIT_AMOUNTS:
		credits_row.add_child(_button("+%d" % amount, func() -> void:
			_admin.request_spawn_item.rpc_id(1, "credits", amount)))

	# --- Quêtes ---
	box.add_child(_section("Quêtes : cristal + foreuse"))
	var quest_row := _row()
	box.add_child(quest_row)
	for crystal in Admin.get_crystal_datas():
		var button := _button("Cristal %s" % crystal.difficulty_name, func() -> void:
			_admin.request_spawn_crystal.rpc_id(1, crystal.resource_path))
		button.add_theme_color_override("font_color", crystal.color)
		quest_row.add_child(button)

	# --- Temps ---
	box.add_child(_section("Temps de partie (on ne peut qu'avancer)"))
	var time_row := _row()
	box.add_child(time_row)
	for seconds in TIME_SKIPS:
		time_row.add_child(_button("+%d min" % int(seconds / 60.0), func() -> void:
			_admin.request_time_skip.rpc_id(1, seconds)))
	# Juste avant chaque moment clé : niveau 2 des monstres (5:00), tempête (7:00),
	# niveau 3 + cristaux (10:00), tempête (12:00), évac (15:00), tempête (18:00), décollage.
	var goto_row := _row()
	box.add_child(goto_row)
	var targets: Array[float] = [290.0, 410.0, 590.0, 710.0, Config.EVAC_LANDING_TIME - 10.0, 1070.0, Config.MATCH_DURATION - 10.0]
	for target in targets:
		var label := "→ %d:%02d" % [floori(target / 60.0), int(target) % 60]
		var button := _button(label, func() -> void:
			_admin.request_time_set.rpc_id(1, target))
		button.custom_minimum_size = Vector2(100, 34)
		goto_row.add_child(button)

	box.add_child(HSeparator.new())
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status_label)
	var hint := Label.new()
	hint.text = "0 ou Échap : fermer"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	box.add_child(hint)


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	return label


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	return row


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(176, 34)
	button.pressed.connect(on_pressed)
	return button


## Résumé de l'arme au survol : type de tir et chiffres principaux.
func _weapon_tooltip(w: WeaponData) -> String:
	if w == null:
		return ""
	var modes := ["auto", "coup par coup", "rafale", "charge", "rafale chargée", "rayon"]
	var shots := ["instantané", "projectile", "projectile explosif"]
	var text := "%s — %s, %s\n%d dégâts, %d coups/min, chargeur %d" % [
		w.display_name, modes[w.fire_mode], shots[w.projectile_type], int(w.damage), int(w.rpm), w.magazine]
	if w.is_explosive():
		text += "\nExplosion : %d dégâts sur %.1f m" % [int(w.aoe_damage), w.aoe_radius_m]
	if w.role != "":
		text += "\n" + w.role
	return text
