class_name PauseMenu
extends CanvasLayer
## Menu Échap du joueur local : onglets « Touches » et « HUD ».
## Le jeu continue derrière (multijoueur) ; la souris est libre tant qu'il est ouvert.
## Échap ouvre (seulement si aucun autre menu n'a libéré la souris) et ferme.

const Store := preload("res://systems/settings/settings_store.gd")
const KeysTab := preload("res://systems/settings/pause_menu_keys.gd")
const HudTab := preload("res://systems/settings/pause_menu_hud.gd")
const GraphicsTab := preload("res://systems/settings/pause_menu_graphics.gd")

var _player: Player
var _key_buttons: Dictionary = {}  ## action -> Button
var _waiting_action: StringName = &""  ## action en attente d'une nouvelle touche
var _status: Label


func setup(player: Player) -> void:
	_player = player
	layer = 12
	visible = false
	_build()


func _input(event: InputEvent) -> void:
	if not visible:
		if event.is_action_pressed("toggle_mouse") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			open()
			get_viewport().set_input_as_handled()
		return
	if _waiting_action != &"":
		_capture(event)
		return
	if event.is_action_pressed("toggle_mouse"):
		close()
		get_viewport().set_input_as_handled()


## Clics hors du panneau : ils ne doivent pas atteindre le jeu (recapture de la souris).
func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_status.text = ""
	refresh_keys()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_waiting_action = &""
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Clic sur une touche : la prochaine touche (ou bouton de souris) la remplace.
func start_capture(action: StringName) -> void:
	refresh_keys()
	_waiting_action = action
	(_key_buttons[action] as Button).text = "Appuyez sur une touche…"
	_status.text = "Échap : annuler"


func reset_keys() -> void:
	Store.reset_keys()
	refresh_keys()
	_status.text = "Touches par défaut rétablies."


func refresh_keys() -> void:
	for action: StringName in _key_buttons:
		(_key_buttons[action] as Button).text = Store.key_text(action)


func _capture(event: InputEvent) -> void:
	var key := event as InputEventKey
	var mouse := event as InputEventMouseButton
	if key and key.pressed and not key.echo:
		get_viewport().set_input_as_handled()
		if key.physical_keycode == KEY_ESCAPE:
			_waiting_action = &""
			_status.text = ""
			refresh_keys()
			return
		var bound := InputEventKey.new()
		bound.physical_keycode = key.physical_keycode
		_apply(bound)
	elif mouse and mouse.pressed:
		get_viewport().set_input_as_handled()
		var bound := InputEventMouseButton.new()
		bound.button_index = mouse.button_index
		_apply(bound)


func _apply(event: InputEvent) -> void:
	var action := _waiting_action
	_waiting_action = &""
	var taken := Store.rebind(action, event)
	refresh_keys()
	_status.text = "« %s » retirée de : %s" % [Store.Codec.event_text(event), taken] if taken != "" else ""


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.theme = UiStyle.theme()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := Label.new()
	title.text = "MENU"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UiStyle.ICE)
	box.add_child(title)

	var tabs := TabContainer.new()
	var height := minf(640.0, get_viewport().get_visible_rect().size.y - 220.0) if get_viewport() else 560.0
	tabs.custom_minimum_size = Vector2(620, height)
	box.add_child(tabs)
	tabs.add_child(KeysTab.build(self, _key_buttons))
	tabs.add_child(HudTab.build())
	tabs.add_child(GraphicsTab.build())

	_status = Label.new()
	_status.add_theme_color_override("font_color", UiStyle.GOLD)
	box.add_child(_status)
	var resume := Button.new()
	resume.text = "Reprendre (Échap)"
	resume.pressed.connect(close)
	box.add_child(resume)
