extends RefCounted
## Sections « outils » du menu admin : crédits, quêtes, temps de partie, outils de dev.

const Widgets := preload("res://systems/admin/admin_ui_widgets.gd")
const CREDIT_AMOUNTS: Array[int] = [100, 500, 1000, 5000]
const TIME_SKIPS: Array[float] = [60.0, 300.0, 600.0]


static func add_credits(box: Control, admin: Admin) -> void:
	box.add_child(Widgets.section("Crédits (au sol)"))
	var credits_row := Widgets.row()
	box.add_child(credits_row)
	for amount in CREDIT_AMOUNTS:
		credits_row.add_child(Widgets.button("+%d" % amount, func() -> void:
			admin.request_spawn_item.rpc_id(1, "credits", amount)))


static func add_quests(box: Control, admin: Admin) -> void:
	box.add_child(Widgets.section("Quêtes : cristal + foreuse"))
	var quest_row := Widgets.row()
	box.add_child(quest_row)
	for crystal in Admin.get_crystal_datas():
		var button := Widgets.button("Cristal %s" % crystal.difficulty_name, func() -> void:
			admin.request_spawn_crystal.rpc_id(1, crystal.resource_path))
		button.add_theme_color_override("font_color", crystal.color)
		quest_row.add_child(button)


static func add_time(box: Control, admin: Admin) -> void:
	var start_button := Widgets.button("Lancer la partie (lobby)", func() -> void: admin.request_force_start.rpc_id(1))
	box.add_child(start_button)
	box.add_child(Widgets.section("Temps de partie (on ne peut qu'avancer)"))
	var time_row := Widgets.row()
	box.add_child(time_row)
	for seconds in TIME_SKIPS:
		time_row.add_child(Widgets.button("+%d min" % int(seconds / 60.0), func() -> void:
			admin.request_time_skip.rpc_id(1, seconds)))
	# Juste avant chaque moment clé : niveau 2 des monstres (5:00), Grande Marée (annonce 9:00),
	# niveau 3 + cristaux + Grande Marée (10:00), annonce de l'évac (16:00), arrivée de l'évac (17:00), décollage.
	var goto_row := Widgets.row()
	box.add_child(goto_row)
	var rules := Config.match_rules
	var targets: Array[float] = [rules.monster_level_times[0] - 10.0, _storm_warning_time() - 10.0,
		rules.monster_level_times[1] - 10.0, rules.evac_announce_time - 10.0,
		rules.evac_landing_time - 10.0, rules.match_duration - 10.0]
	for target in targets:
		var label := "→ %d:%02d" % [floori(target / 60.0), int(target) % 60]
		var button := Widgets.button(label, func() -> void:
			admin.request_time_set.rpc_id(1, target))
		button.custom_minimum_size = Vector2(100, 34)
		goto_row.add_child(button)


static func add_dev_tools(box: Control, admin: Admin, player: Player, start_grip_tuner: Callable) -> void:
	box.add_child(HSeparator.new())
	box.add_child(Widgets.section("Outils de dev"))
	var dev_row := Widgets.row()
	box.add_child(dev_row)
	var tune_button := Widgets.button("Régler la prise de l'arme", start_grip_tuner)
	tune_button.tooltip_text = "Flèches, Page ↑/↓, +/− : déplacer et redimensionner l'arme en main ; Entrée : enregistrer ; Fin : quitter"
	dev_row.add_child(tune_button)
	var map_button := Widgets.button("Carte complète", func() -> void: pass)
	map_button.toggle_mode = true
	map_button.button_pressed = MapView.full_map
	map_button.toggled.connect(func(on: bool) -> void: MapView.full_map = on)
	map_button.tooltip_text = "Carte et minimap sans limite de 40 m (affichage local)"
	dev_row.add_child(map_button)
	var fly_button := Widgets.button("Vol rapide", func() -> void: pass)
	fly_button.toggle_mode = true
	fly_button.button_pressed = admin.fly.active
	fly_button.toggled.connect(func(on: bool) -> void: admin.fly.set_active(player, on))
	fly_button.tooltip_text = "Sans collision ni gravité. Direction caméra, Espace monte, Ctrl descend, Maj accélère"
	dev_row.add_child(fly_button)


## Annonce de la première Grande Marée (data/storm/), pour le raccourci de temps.
static func _storm_warning_time() -> float:
	var first := INF
	for file in ResourceLoader.list_directory(StormManager.PHASES_DIR):
		var phase := load(StormManager.PHASES_DIR + file) as StormPhaseData
		if phase:
			first = minf(first, phase.start_time - phase.warning_time)
	return first if first < INF else Config.match_rules.monster_level_times[1]
