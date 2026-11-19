extends RefCounted
## Construction du HUD, partie basse : kit, escouade, barres PV / bouclier, capacités Q / F, armes.

const HudWidgets := preload("res://systems/combat/hud_widgets.gd")


static func build_bottom_left(hud: CombatHud) -> void:
	var box := HudWidgets.vbox(6)
	hud.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.grow_horizontal = Control.GROW_DIRECTION_END
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_left = 24
	box.offset_right = 24
	box.offset_bottom = -24
	box.offset_top = -24
	hud._squad_box = HudWidgets.vbox(8)
	box.add_child(hud._squad_box)
	hud._kit_label = HudWidgets.make_label("", 15)
	hud._kit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud._kit_label.add_theme_color_override("font_color", CombatHud.ACCENT)
	box.add_child(hud._kit_label)
	hud._xp_bar = HudWidgets.make_bar(CombatHud.ACCENT, 1.0)
	hud._xp_bar.custom_minimum_size = Vector2(190, 3)
	box.add_child(hud._xp_bar)
	hud._items_label = HudWidgets.make_label("", 15)
	hud._items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(hud._items_label)
	hud._credits_label = HudWidgets.make_label("", 22)
	hud._credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hud._credits_label.add_theme_color_override("font_color", CombatHud.GOLD)
	box.add_child(hud._credits_label)



## Q à gauche, F à droite, et au milieu bouclier (haut) et PV (bas) en segments de 100.
static func build_bottom_center(hud: CombatHud) -> void:
	var box := HudWidgets.vbox(4)
	hud.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -22
	box.offset_top = -22
	hud._pending_label = HudWidgets.make_label("", 16)
	hud._pending_label.add_theme_color_override("font_color", CombatHud.ACCENT)
	box.add_child(hud._pending_label)
	hud._effects_label = HudWidgets.make_label("", 14)
	hud._effects_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	box.add_child(hud._effects_label)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	row.add_child(ability_box(hud, "Q"))
	var bars := HudWidgets.vbox(3)
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bars)
	hud._move_label = HudWidgets.make_label("", 13)
	hud._move_label.add_theme_color_override("font_color", CombatHud.DIM)
	bars.add_child(hud._move_label)
	hud._shield_bar = SegmentBar.new()
	hud._shield_bar.custom_minimum_size = Vector2(380, 9)
	hud._shield_bar.color = CombatHud.SHIELD
	bars.add_child(hud._shield_bar)
	hud._health_bar = SegmentBar.new()
	hud._health_bar.custom_minimum_size = Vector2(380, 13)
	hud._health_bar.color = CombatHud.HEALTH
	bars.add_child(hud._health_bar)
	hud._bars_label = HudWidgets.make_label("", 13)
	hud._bars_label.add_theme_color_override("font_color", CombatHud.DIM)
	bars.add_child(hud._bars_label)
	row.add_child(ability_box(hud, "F"))



static func ability_box(hud: CombatHud, key: String) -> Control:
	var col := HudWidgets.vbox(2)
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(170, 62)
	panel.clip_contents = true
	var style := UiStyle.chamfer_box(CombatHud.PANEL, Color(CombatHud.ACCENT, 0.5), 1, 8)
	style.border_width_bottom = 3
	panel.add_theme_stylebox_override("panel", style)
	col.add_child(panel)
	var cooldown := ColorRect.new()
	cooldown.color = Color(0, 0, 0, 0.55)
	cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(cooldown)
	cooldown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cooldown.visible = false
	# Visuel (capacité ou gadget) à gauche, nom et recharge / charges à droite.
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -4
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2(62, 0)
	row.add_child(slot)
	var inner := HudWidgets.vbox(0)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(inner)
	var name_label := HudWidgets.make_label("—", 13)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(100, 0)
	inner.add_child(name_label)
	var info := HudWidgets.make_label("", 18)
	info.add_theme_color_override("font_color", CombatHud.GOLD)
	inner.add_child(info)
	var key_chip := HudWidgets.chip(key)
	key_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(key_chip)
	hud._ability_boxes.append({"panel": panel, "name": name_label, "info": info, "cooldown": cooldown, "slot": slot, "id": ""})
	return col



static func build_bottom_right(hud: CombatHud) -> void:
	var box := HudWidgets.vbox(4)
	hud.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -28
	box.offset_left = -28
	box.offset_bottom = -22
	box.offset_top = -22
	for i in Inventory.WEAPON_SLOTS + 2:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override("separation", 10)
		var icon := WeaponIcon.new()
		icon.custom_minimum_size = Vector2(150, 48)
		row.add_child(icon)
		var key := HudWidgets.make_label(str(i + 1) if i < Inventory.WEAPON_SLOTS else ["Q", "F"][i - Inventory.WEAPON_SLOTS], 18)
		key.custom_minimum_size = Vector2(22, 0)
		row.add_child(key)
		box.add_child(row)
		hud._slot_rows.append({"row": row, "icon": icon, "key": key})
	# Les gadgets (Q / F) apparaissent sous les armes, seulement s'ils existent.
	hud._weapon_name = HudWidgets.make_label("", 18)
	hud._weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hud._weapon_name)
	hud._ammo_label = HudWidgets.make_label("", 40)
	hud._ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hud._ammo_label)
