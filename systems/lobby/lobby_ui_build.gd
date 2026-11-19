extends RefCounted
## Construction de l'écran du lobby (LobbyUi) : fond, barre du haut, cadre et pile d'onglets.
## Remplit ui._pages et ui._loadout_page.


static func build(ui: LobbyUi) -> void:
	var bg := UiStyle.make_lobby_background()
	ui.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	root.theme = UiStyle.theme()
	ui.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(ui._top.build(ui))
	var line := ColorRect.new()
	line.color = UiStyle.ACCENT.darkened(0.4)
	line.custom_minimum_size = Vector2(0, 2)
	root.add_child(line)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	root.add_child(margin)
	var stack := Control.new()
	margin.add_child(stack)
	ui._loadout_page = LoadoutPage.new()
	ui._loadout_page.setup(ui)
	var builders: Array[Callable] = [ui._launch.build.bind(ui), func() -> Control: return ui._loadout_page,
			ui._arsenal.build.bind(ui), ui._factions.build.bind(ui), ui._squad.build]
	for builder in builders:
		var page: Control = builder.call()
		stack.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ui._pages.append(page)
