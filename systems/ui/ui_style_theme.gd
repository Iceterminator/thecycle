extends RefCounted
## Construction du thème commun de UiStyle : boutons, listes déroulantes, menus,
## barres de défilement, info-bulles. Appelé une fois par UiStyle.theme() (mis en cache).


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = UiStyle.font("Medium")
	t.default_font_size = 18
	# Boutons secondaires (les boutons principaux sont colorés à la main).
	var normal := UiStyle.chamfer_box(Color(0.12, 0.2, 0.3, 0.9), UiStyle.PANEL_BORDER, 1, 6)
	var hover := UiStyle.chamfer_box(Color(0.16, 0.27, 0.39, 0.95), UiStyle.ICE.darkened(0.2), 1, 6)
	var pressed := UiStyle.chamfer_box(Color(0.24, 0.19, 0.12, 0.95), UiStyle.ACCENT, 2, 6)
	var disabled := UiStyle.chamfer_box(Color(0.08, 0.11, 0.15, 0.8), Color(1, 1, 1, 0.08), 1, 6)
	for box: StyleBoxFlat in [normal, hover, pressed, disabled]:
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 4
		box.content_margin_bottom = 4
	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_color("font_color", type, UiStyle.TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, UiStyle.ACCENT)
		t.set_color("font_disabled_color", type, Color(1, 1, 1, 0.3))
	# Menus déroulants.
	var popup := UiStyle.chamfer_box(Color(0.07, 0.12, 0.19, 0.98), UiStyle.PANEL_BORDER, 1, 6)
	popup.set_content_margin_all(6)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", UiStyle.chamfer_box(Color(UiStyle.ACCENT, 0.25), Color(0, 0, 0, 0), 0, 4))
	t.set_color("font_color", "PopupMenu", UiStyle.TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", Color(1, 1, 1, 0.3))
	# Barres de défilement fines.
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(UiStyle.ICE, 0.35)
	grabber.set_corner_radius_all(3)
	var grabber_hot := grabber.duplicate() as StyleBoxFlat
	grabber_hot.bg_color = Color(UiStyle.ACCENT, 0.8)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.05)
	track.set_corner_radius_all(3)
	track.content_margin_left = 3
	track.content_margin_right = 3
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("grabber", type, grabber)
		t.set_stylebox("grabber_highlight", type, grabber_hot)
		t.set_stylebox("grabber_pressed", type, grabber_hot)
		t.set_stylebox("scroll", type, track)
	# Info-bulles.
	var tip := UiStyle.chamfer_box(Color(0.05, 0.09, 0.14, 0.97), UiStyle.PANEL_BORDER, 1, 4)
	tip.set_content_margin_all(8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", UiStyle.TEXT)
	t.set_color("font_color", "Label", UiStyle.TEXT)
	t.set_constant("separation", "HSeparator", 12)
	var sep := StyleBoxLine.new()
	sep.color = Color(UiStyle.ICE, 0.18)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	return t
