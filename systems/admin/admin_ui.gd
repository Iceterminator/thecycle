class_name AdminUi
extends CanvasLayer
## Interface du menu admin (joueur local), construite en code.
## 0 ouvre / ferme, Échap ferme. Pendant qu'elle est ouverte, la souris est libre
## (donc pas de tir, pas de visée, pas d'interaction). Le menu reste ouvert après
## chaque demande pour en enchaîner plusieurs.

const Catalog := preload("res://systems/admin/admin_ui_catalog.gd")
const Tools := preload("res://systems/admin/admin_ui_tools.gd")

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
	box.custom_minimum_size = Vector2(980, 0)
	box.add_theme_constant_override("separation", 8)
	# Le menu est long (armes, kits, capacités…) : il défile, hauteur limitée à l'écran.
	var outer := ScrollContainer.new()
	outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.custom_minimum_size = Vector2(1000, minf(820.0, get_viewport().get_visible_rect().size.y - 80.0) if get_viewport() else 760.0)
	panel.add_child(outer)
	outer.add_child(box)

	var title := Label.new()
	title.text = "MENU ADMIN — apparaît devant vous"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)
	box.add_child(HSeparator.new())

	Catalog.add_weapons(box, _admin)
	Catalog.add_kits(box, _admin)
	Catalog.add_abilities(box, _admin)
	Tools.add_credits(box, _admin)
	Tools.add_quests(box, _admin)
	Tools.add_time(box, _admin)
	Tools.add_dev_tools(box, _admin, _player, _start_grip_tuner)

	box.add_child(HSeparator.new())
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status_label)
	var hint := Label.new()
	hint.text = "0 ou Échap : fermer"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	box.add_child(hint)


## Ferme le menu et lance l'outil de réglage de la prise (un seul à la fois).
func _start_grip_tuner() -> void:
	close()
	var parent := get_parent()
	if parent.has_node("GripTuner"):
		return
	var tuner := GripTuner.new()
	tuner.name = "GripTuner"
	tuner.layer = 12
	parent.add_child(tuner)
	tuner.setup(_player)

