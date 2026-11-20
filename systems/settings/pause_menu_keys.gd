extends RefCounted
## Onglet « Touches » du menu Échap : une ligne par action (nom, bouton de la touche).

const Store := preload("res://systems/settings/settings_store.gd")


## Remplit buttons (action -> Button) ; un clic sur un bouton lance la capture dans menu.
static func build(menu: PauseMenu, buttons: Dictionary) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Touches"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for action: StringName in Store.ACTIONS:
		if not InputMap.has_action(action):
			continue
		var row := HBoxContainer.new()
		list.add_child(row)
		var label := Label.new()
		label.text = Store.ACTIONS[action]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 0)
		button.pressed.connect(menu.start_capture.bind(action))
		row.add_child(button)
		buttons[action] = button
	var reset := Button.new()
	reset.text = "Touches par défaut"
	reset.pressed.connect(menu.reset_keys)
	list.add_child(HSeparator.new())
	list.add_child(reset)
	return scroll
