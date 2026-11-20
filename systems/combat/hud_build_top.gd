extends RefCounted
## Construction du HUD, partie haute : viseur, minimap, rang, horloge, annonces, classement.

const HudWidgets := preload("res://systems/combat/hud_widgets.gd")


static func build_center(hud: CombatHud) -> void:
	var center := CenterContainer.new()
	HudWidgets.add_full_rect(hud, center)
	HudWidgets.tag_block(center, "viseur")
	hud._crosshair = HudWidgets.make_label("+", 26)
	center.add_child(hud._crosshair)
	hud._hitmarker = HudWidgets.make_label("×", 32)
	hud._hitmarker.modulate.a = 0.0
	center.add_child(hud._hitmarker)
	# Message d'interaction + barre d'utilisation, sous le viseur.
	var below := HudWidgets.vbox(4)
	hud.add_child(below)
	below.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	below.grow_horizontal = Control.GROW_DIRECTION_BOTH
	below.offset_top = 50
	below.offset_bottom = 50
	hud._prompt_label = HudWidgets.make_label("", 20)
	below.add_child(hud._prompt_label)
	hud._use_bar = HudWidgets.make_bar(Color(1, 1, 1, 0.85), 1.0)
	hud._use_bar.custom_minimum_size = Vector2(200, 8)
	hud._use_bar.step = 0.0
	hud._use_bar.visible = false
	below.add_child(hud._use_bar)



## Minimap ronde (MapView découpé par un disque), rang et Fame, objectifs.
static func build_top_left(hud: CombatHud) -> void:
	var disc := Panel.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	disc.position = Vector2(20, 20)
	disc.size = Vector2(CombatHud.MAP_SIZE, CombatHud.MAP_SIZE)
	disc.add_theme_stylebox_override("panel", HudWidgets.round_style(Color(0.05, 0.08, 0.08, 0.9), Color(0, 0, 0, 0), 0))
	hud.add_child(disc)
	HudWidgets.tag_block(disc, "minimap")
	hud._minimap = MapView.new()
	hud._minimap.player = hud._player
	hud._minimap.world = hud._player.get_parent().get_parent() as Node3D
	hud._minimap.follow = true
	hud._minimap.view_half = Config.MINIMAP_HALF_SIZE
	hud._minimap.show_labels = false
	hud._minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(hud._minimap)
	hud._minimap.position = Vector2.ZERO
	hud._minimap.size = Vector2(CombatHud.MAP_SIZE, CombatHud.MAP_SIZE)
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = disc.position
	ring.size = disc.size
	ring.add_theme_stylebox_override("panel", HudWidgets.round_style(Color(0, 0, 0, 0), CombatHud.ACCENT.darkened(0.2), 3))
	hud.add_child(ring)
	HudWidgets.tag_block(ring, "minimap")

	var info := HBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 14)
	info.position = Vector2(36 + CombatHud.MAP_SIZE, 30)
	hud.add_child(info)
	HudWidgets.tag_block(info, "rang")
	info.add_child(HudWidgets.chip("TAB"))
	hud._rank_label = HudWidgets.make_label("1er", 30)
	info.add_child(hud._rank_label)
	hud._fame_label = HudWidgets.make_label("★ 0", 30)
	hud._fame_label.add_theme_color_override("font_color", CombatHud.GOLD)
	info.add_child(hud._fame_label)
	var fps_counter := FpsCounter.new()
	fps_counter.position = Vector2(36 + CombatHud.MAP_SIZE, 74)
	hud.add_child(fps_counter)
	HudWidgets.tag_block(fps_counter, "fps")

	hud._objectives_box = HudWidgets.vbox(8)
	hud._objectives_box.position = Vector2(24, 36 + CombatHud.MAP_SIZE)
	hud.add_child(hud._objectives_box)
	HudWidgets.tag_block(hud._objectives_box, "objectifs")



static func build_top_center(hud: CombatHud) -> void:
	var box := HudWidgets.vbox(0)
	hud.add_child(box)
	HudWidgets.tag_block(box, "horloge")
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = 12
	hud._clock_label = HudWidgets.make_label("00:00", 38)
	box.add_child(hud._clock_label)
	hud._clock_sub = HudWidgets.make_label("", 14)
	hud._clock_sub.add_theme_color_override("font_color", CombatHud.DIM)
	box.add_child(hud._clock_sub)
	hud._storm_label = HudWidgets.make_label("", 18)
	hud._storm_label.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0))
	box.add_child(hud._storm_label)
	# Bandeau d'annonces (contrats capturés, prime, cœur stellaire…).
	hud._banner = HudWidgets.make_label("", 24)
	hud._banner.modulate.a = 0.0
	hud.add_child(hud._banner)
	hud._banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hud._banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud._banner.offset_top = 120



static func build_top_right(hud: CombatHud) -> void:
	var box := HudWidgets.vbox(6)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	hud.add_child(box)
	HudWidgets.tag_block(box, "classement")
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -28
	box.offset_top = 22
	hud._status_label = HudWidgets.make_label("", 20)
	hud._status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud._status_label.add_theme_color_override("font_color", CombatHud.ACCENT)
	box.add_child(hud._status_label)
	hud._leaders_box = HudWidgets.vbox(2)
	box.add_child(hud._leaders_box)
