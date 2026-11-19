extends RefCounted
## Écrans du HUD : embarquement, spectateur, mort, fin de partie, à terre.

const HudWidgets := preload("res://systems/combat/hud_widgets.gd")


static func build_screens(hud: CombatHud) -> void:
	# Embarquement en cours (au-dessus du viseur).
	hud._board_box = HudWidgets.vbox(4)
	hud.add_child(hud._board_box)
	hud._board_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hud._board_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud._board_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud._board_box.offset_top = -110
	hud._board_box.offset_bottom = -50
	hud._board_box.add_child(HudWidgets.make_label("Embarquement… restez dans la soute", 22))
	hud._board_bar = HudWidgets.make_bar(CombatHud.ACCENT, 1.0)
	hud._board_bar.custom_minimum_size = Vector2(320, 10)
	hud._board_bar.step = 0.0
	hud._board_box.add_child(hud._board_bar)
	hud._board_box.visible = false
	# À bord : spectateur.
	hud._aboard_label = HudWidgets.make_label("À BORD DE L'ÉVAC — en sécurité\nSpectateur : déplacement libre, Espace / Ctrl pour monter / descendre", 22)
	hud._aboard_label.add_theme_color_override("font_color", CombatHud.SHIELD)
	hud.add_child(hud._aboard_label)
	hud._aboard_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hud._aboard_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hud._aboard_label.offset_top = 140
	hud._aboard_label.visible = false
	# Écran de mort.
	hud._death_panel = ColorRect.new()
	hud._death_panel.color = Color(0.05, 0.0, 0.0, 0.6)
	HudWidgets.add_full_rect(hud, hud._death_panel)
	var death_center := CenterContainer.new()
	death_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._death_panel.add_child(death_center)
	death_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud._death_label = HudWidgets.make_label("", 36)
	death_center.add_child(hud._death_label)
	hud._death_panel.visible = false
	# Écran de fin.
	hud._results_panel = ColorRect.new()
	hud._results_panel.color = Color(0.0, 0.02, 0.06, 0.8)
	HudWidgets.add_full_rect(hud, hud._results_panel)
	var results_center := CenterContainer.new()
	results_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._results_panel.add_child(results_center)
	results_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud._results_label = HudWidgets.make_label("", 28)
	results_center.add_child(hud._results_label)
	hud._results_panel.visible = false



static func killer_text(hud: CombatHud) -> String:
	var killer := hud._player.health.killer_id
	if killer == 0:
		return "Vous êtes mort"
	if killer == Config.MONSTER_KILLER_ID:
		return "Tué par un monstre"
	if killer == Config.FALL_KILLER_ID:
		return "Tombé hors de la carte"
	if killer == hud._player.get_peer_id():
		return "Vous vous êtes tué"
	return "Tué par %s" % ProfileManager.name_of(killer)



static func on_board_progress(hud: CombatHud, ratio: float) -> void:
	hud._board_box.visible = ratio > 0.0
	hud._board_bar.value = ratio



static func on_results(hud: CombatHud, results: Array, restart_in: float) -> void:
	hud._restart_left = restart_in
	var lines: PackedStringArray = ["FIN DE PARTIE — CLASSEMENT", ""]
	var rank := 1
	for entry: Dictionary in results:
		var peer: int = entry["peer"]
		var who := "Vous" if peer == hud._player.get_peer_id() else ProfileManager.name_of(peer)
		var status := "évacué" if entry["evacuated"] else "resté au sol (-%d)" % Config.economy.evac_missed_penalty
		lines.append("%d. %s — %d Fame — %s" % [rank, who, entry["points"], status])
		rank += 1
	hud._results_text = "\n".join(lines) + "\n"
	hud._results_panel.visible = true



static func update_downed(hud: CombatHud) -> void:
	var h := hud._player.health
	if hud._downed_label == null:
		hud._downed_label = HudWidgets.make_label("", 30)
		hud._downed_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		hud.add_child(hud._downed_label)
		hud._downed_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		hud._downed_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		hud._downed_label.offset_top = 120
	hud._downed_label.visible = h.is_downed
	if h.is_downed:
		var left := maxf(Config.combat.downed_time - (Time.get_ticks_msec() - h.downed_at_ms) / 1000.0, 0.0)
		hud._downed_label.text = "À TERRE — %d s\nUn coéquipier peut vous relever (E maintenu)" % ceili(left)


static func on_dead_changed(hud: CombatHud, dead: bool) -> void:
	hud._death_panel.visible = dead
	if dead:
		hud._respawn_left = Config.match_rules.respawn_delay
