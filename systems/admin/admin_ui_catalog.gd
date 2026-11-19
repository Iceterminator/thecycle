extends RefCounted
## Sections « catalogue » du menu admin : armes, kits, capacités.

const Widgets := preload("res://systems/admin/admin_ui_widgets.gd")


static func add_weapons(box: Control, admin: Admin) -> void:
	box.add_child(Widgets.section("Armes"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for item in Items.get_items_of_kind(ItemData.Kind.WEAPON):
		var button := Widgets.button(item.display_name, func() -> void:
			admin.request_spawn_item.rpc_id(1, String(item.id), 1))
		button.tooltip_text = Widgets.weapon_tooltip(item.weapon)
		button.add_theme_color_override("font_color", item.color)
		grid.add_child(button)


static func add_kits(box: Control, admin: Admin) -> void:
	box.add_child(Widgets.section("Kits"))
	var kits_row := Widgets.row()
	box.add_child(kits_row)
	for kit_data in KitController.list_kits():
		var kit_button := Widgets.button(KitController.kit_name(kit_data), func() -> void:
			admin.request_set_kit.rpc_id(1, String(kit_data.id)))
		kit_button.custom_minimum_size = Vector2(150, 34)
		kits_row.add_child(kit_button)
	var ready_button := Widgets.button("Recharges à zéro", func() -> void: admin.request_abilities_ready.rpc_id(1))
	ready_button.tooltip_text = "Capacités prêtes tout de suite"
	kits_row.add_child(ready_button)


static func add_abilities(box: Control, admin: Admin) -> void:
	box.add_child(Widgets.section("Capacités (équipées tout de suite sur Q ou F)"))
	var ability_grid := GridContainer.new()
	ability_grid.columns = 3
	ability_grid.add_theme_constant_override("h_separation", 14)
	box.add_child(ability_grid)
	for ability_data in AbilityController.list_abilities():
		var cell := HBoxContainer.new()
		var ability_label := Label.new()
		ability_label.text = ability_data.get_display_name()
		ability_label.custom_minimum_size = Vector2(170, 0)
		ability_label.tooltip_text = ability_data.behavior
		ability_label.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.add_child(ability_label)
		for ability_slot in 2:
			var slot_button := Button.new()
			slot_button.text = "Q" if ability_slot == 0 else "F"
			slot_button.custom_minimum_size = Vector2(34, 28)
			slot_button.pressed.connect(func() -> void: admin.request_set_ability.rpc_id(1, ability_slot, String(ability_data.id)))
			cell.add_child(slot_button)
		ability_grid.add_child(cell)
