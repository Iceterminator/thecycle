extends RefCounted
## Onglet « HUD » du menu Échap : une case à cocher par bloc du HUD (enregistrée aussitôt).

const Store := preload("res://systems/settings/settings_store.gd")


static func build() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "HUD"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for id: String in Store.HUD_BLOCKS:
		var check := CheckBox.new()
		check.text = Store.HUD_BLOCKS[id]
		check.button_pressed = Store.hud_shown(id)
		check.toggled.connect(func(on: bool) -> void: Store.set_hud_shown(id, on))
		list.add_child(check)
	return scroll
