extends RefCounted
## Touches : texte affiché et encodage pour le fichier de réglages.
## Encodage : "k:<touche physique>", "kc:<touche logique>", "m:<bouton souris>".


static func event_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.keycode
		if key.physical_keycode != KEY_NONE:
			code = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "Clic gauche"
			MOUSE_BUTTON_RIGHT: return "Clic droit"
			MOUSE_BUTTON_MIDDLE: return "Clic milieu"
			MOUSE_BUTTON_WHEEL_UP: return "Molette haut"
			MOUSE_BUTTON_WHEEL_DOWN: return "Molette bas"
			var other: return "Souris %d" % other
	return "?"


static func encode(event: InputEvent) -> String:
	if event is InputEventKey:
		var key := event as InputEventKey
		return "k:%d" % key.physical_keycode if key.physical_keycode != KEY_NONE else "kc:%d" % key.keycode
	if event is InputEventMouseButton:
		return "m:%d" % (event as InputEventMouseButton).button_index
	return ""


static func encode_all(events: Array) -> Array:
	var out: Array = []
	for event: InputEvent in events:
		var text := encode(event)
		if text != "":
			out.append(text)
	return out


static func decode_all(codes: Array) -> Array:
	var out: Array = []
	for code: Variant in codes:
		var parts := str(code).split(":")
		if parts.size() != 2:
			continue
		var value := int(parts[1])
		if parts[0] == "m":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = value as MouseButton
			out.append(mouse)
		else:
			var key := InputEventKey.new()
			if parts[0] == "k":
				key.physical_keycode = value as Key
			else:
				key.keycode = value as Key
			out.append(key)
	return out
