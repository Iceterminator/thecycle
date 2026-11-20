extends RefCounted
## Petits outils de construction d'interface du HUD (étiquettes, barres, puces, styles).
## Style sobre : textes blancs à ombre légère, fonds semi-transparents, lignes fines, angles droits.

const LINE := Color(1.0, 1.0, 1.0, 0.35)  ## lignes fines (contours, séparateurs)


## Ajoute `control` au HUD, plein cadre et sans capter la souris.
static func add_full_rect(hud: CombatHud, control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func vbox(separation: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	return box


static func make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiStyle.font("SemiBold" if size >= 30 else "Medium"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


## Petite étiquette de touche : [TAB], [Q]…
static func chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.25)
	style.border_color = LINE
	style.set_border_width_all(1)
	style.content_margin_left = 6
	style.content_margin_right = 6
	chip_margins(style)
	chip.add_theme_stylebox_override("panel", style)
	var label := make_label(text, 13)
	chip.add_child(label)
	return chip


static func chip_margins(style: StyleBoxFlat) -> void:
	style.content_margin_top = 1
	style.content_margin_bottom = 1


static func round_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(int(CombatHud.MAP_SIZE / 2.0))
	style.corner_detail = 24
	style.anti_aliasing = true
	return style


static func make_bar(color: Color, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(280, 14)
	bar.max_value = max_value
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	return bar


## Marque un enfant direct du HUD comme bloc réglable (menu Échap → HUD, ids de SettingsStore).
static func tag_block(node: Control, id: String) -> void:
	node.set_meta(&"hud_block", id)


## Affiche / cache chaque bloc marqué selon les réglages du joueur.
static func apply_blocks(hud: CombatHud) -> void:
	for child: Node in hud.get_children():
		if child.has_meta(&"hud_block"):
			(child as CanvasItem).visible = Config.SettingsStore.hud_shown(str(child.get_meta(&"hud_block")))
