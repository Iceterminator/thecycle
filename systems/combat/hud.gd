class_name CombatHud
extends CanvasLayer
## Interface de combat du joueur local, construite en code :
## viseur, hitmarker, barres PV / bouclier, munitions, flash de dégâts, écran de mort.
## Aucun contrôle ne capte la souris (MOUSE_FILTER_IGNORE) pour ne pas gêner le jeu.

var _player: Player
var _health_bar: ProgressBar
var _shield_bar: ProgressBar
var _health_label: Label
var _shield_label: Label
var _ammo_label: Label
var _crosshair: Label
var _hitmarker: Label
var _damage_flash: ColorRect
var _death_panel: ColorRect
var _death_label: Label
var _slot_labels: Array[Label] = []
var _items_label: Label
var _credits_label: Label
var _prompt_label: Label
var _use_bar: ProgressBar
var _quest_label: Label
var _banner: Label
var _banner_tween: Tween

# Partie (étape 6)
var _clock_label: Label
var _minimap: MapView
var _tags_left: float = 0.0  ## prochaine mise à jour des textes flottants des quêtes
var _storm_label: Label
var _kit_label: Label
var _board_box: VBoxContainer
var _board_bar: ProgressBar
var _aboard_label: Label
var _results_panel: ColorRect
var _results_label: Label
var _clock_elapsed: float = 0.0
var _clock_phase: int = MatchManager.Phase.PLAYING
var _restart_left: float = 0.0

var _hold_ratio: float = 0.0  ## maintien de E en cours (cristal…)
var _charge_ratio: float = 0.0  ## charge ou montée en régime de l'arme
var _last_total: float = -1.0
var _respawn_left: float = 0.0
var _hit_tween: Tween
var _flash_tween: Tween


func setup(player: Player) -> void:
	_player = player
	_build()
	player.health.changed.connect(_on_health_changed)
	player.health.dead_changed.connect(_on_dead_changed)
	player.weapon.ammo_changed.connect(_on_ammo_changed)
	player.weapon.hit_confirmed.connect(_on_hit_confirmed)
	player.inventory.changed.connect(_on_inventory_changed)
	player.interactor.prompt_changed.connect(func(text: String) -> void: _prompt_label.text = text)
	player.interactor.hold_progress.connect(func(ratio: float) -> void: _hold_ratio = ratio)
	player.weapon.charge_changed.connect(func(ratio: float) -> void: _charge_ratio = ratio)
	player.score.changed.connect(_on_score_changed)
	_on_score_changed()
	Events.announcement.connect(_on_announcement)
	_on_health_changed()
	_on_inventory_changed()
	_on_ammo_changed(player.weapon.ammo, player.weapon.data.magazine, false)
	_on_dead_changed(player.health.is_dead)
	Events.match_clock_synced.connect(_on_clock_synced)
	Events.evac_board_progress.connect(_on_board_progress)
	Events.match_results_received.connect(_on_results)
	player.evacuated_changed.connect(func(aboard: bool) -> void: _aboard_label.visible = aboard)
	Events.match_clock_requested.emit()
	_build_minimap()


func _process(delta: float) -> void:
	_update_clock(delta)
	_kit_label.text = _kit_text()
	_tags_left -= delta
	if _tags_left <= 0.0:
		_tags_left = 0.2
		_update_quest_tags()
	if _death_panel.visible:
		_respawn_left = maxf(_respawn_left - delta, 0.0)
		_death_label.text = "%s\nRéapparition dans %d s" % [_killer_text(), ceili(_respawn_left)]
	_crosshair.visible = not _player.weapon.is_aiming and not _player.health.is_dead
	var inv := _player.inventory
	var bar_ratio := maxf(_hold_ratio, _charge_ratio)
	_use_bar.visible = inv.using_item != "" or bar_ratio > 0.0
	if bar_ratio > 0.0:
		_use_bar.value = bar_ratio
	elif _use_bar.visible:
		var duration := maxf(inv.get_use_duration(), 0.01)
		_use_bar.value = clampf((Time.get_ticks_msec() - inv.use_started_ms) / 1000.0 / duration, 0.0, 1.0)


# --- Partie : minuteur, embarquement, écran de fin ---

func _on_clock_synced(elapsed: float, phase: int) -> void:
	_clock_elapsed = elapsed
	_clock_phase = phase
	if phase != MatchManager.Phase.ENDED:
		_results_panel.visible = false


func _update_clock(delta: float) -> void:
	if _clock_phase == MatchManager.Phase.ENDED:
		_clock_label.text = "Fin de partie"
		_restart_left = maxf(_restart_left - delta, 0.0)
		if _results_panel.visible:
			_results_label.text = _results_text + "\nNouvelle partie dans %d s" % ceili(_restart_left)
		return
	_clock_elapsed = minf(_clock_elapsed + delta, Config.MATCH_DURATION)
	_storm_label.text = StormManager.hud_text(_player.global_position).replace("\n", "  —  ")
	var total := "%s / %s" % [_fmt(_clock_elapsed), _fmt(Config.MATCH_DURATION)]
	if _clock_phase == MatchManager.Phase.EVAC:
		_clock_label.text = "%s — ÉVAC AU SOL : décollage dans %s" % [total, _fmt(Config.MATCH_DURATION - _clock_elapsed)]
		_clock_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	else:
		_clock_label.text = "%s — évac dans %s" % [total, _fmt(Config.EVAC_LANDING_TIME - _clock_elapsed)]
		_clock_label.remove_theme_color_override("font_color")


func _fmt(seconds: float) -> String:
	var s := maxi(ceili(seconds), 0)
	return "%d:%02d" % [floori(s / 60.0), s % 60]


func _on_board_progress(ratio: float) -> void:
	_board_box.visible = ratio > 0.0
	_board_bar.value = ratio


var _results_text: String = ""


func _on_results(results: Array, restart_in: float) -> void:
	_restart_left = restart_in
	var lines: PackedStringArray = ["FIN DE PARTIE — CLASSEMENT", ""]
	var rank := 1
	for entry: Dictionary in results:
		var peer: int = entry["peer"]
		var who := "Vous" if peer == _player.get_peer_id() else "Joueur %d" % peer
		var status := "évacué" if entry["evacuated"] else "resté au sol (-%d)" % Config.EVAC_MISSED_PENALTY
		lines.append("%d. %s — %d Fame — %s" % [rank, who, entry["points"], status])
		rank += 1
	_results_text = "\n".join(lines) + "\n"
	_results_panel.visible = true


func _on_announcement(text: String, color: Color) -> void:
	_banner.text = text
	_banner.modulate = color
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(4.0)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.8)


func _on_score_changed() -> void:
	# Classement, puis la progression de chaque objectif commencé (vers le prochain palier).
	var text := "%d Fame" % _player.score.rank_points
	var objectives: Dictionary = _player.score.objective_points
	var rates: Dictionary = _player.score.objective_rates
	var paths: Array = objectives.keys()
	for path: String in rates:
		if not paths.has(path):
			paths.append(path)
	for path: String in paths:
		var track := load(path) as ObjectiveTrack
		if track == null:
			continue
		var pts: int = objectives.get(path, 0)
		var tier := track.tiers_reached(pts)
		var line := "\n%s : %d / %d  → +%d Fame" % [track.display_name, pts, track.threshold(tier), track.reward(tier)]
		var rate: float = rates.get(path, 0.0)
		if rate > 0.0:
			line += "  (+%.1f/s)" % rate
		text += line
	_quest_label.text = text


func _on_inventory_changed() -> void:
	var inv := _player.inventory
	for i in _slot_labels.size():
		var item := Items.get_item(StringName(inv.slot_ids[i]))
		var label := _slot_labels[i]
		label.text = "[%d] %s" % [i + 1, item.display_name if item else "—"]
		label.modulate = Color(1, 0.85, 0.3) if i == inv.active_slot else Color(1, 1, 1, 0.55)
	var text := "[3] Soins ×%d    [4] Recharges ×%d" % [inv.medkits, inv.shield_cells]
	for res_id: String in inv.carried:
		var res := Items.get_item(StringName(res_id))
		text += "    %s ×%d" % [res.display_name if res else res_id, inv.carried[res_id]]
	_items_label.text = text
	_credits_label.text = "%d crédits   [T] Boutique" % inv.credits


# --- Réactions aux signaux ---

func _on_health_changed() -> void:
	var h := _player.health
	_health_bar.max_value = maxf(h.get_max_health(), 1.0)
	_health_bar.value = h.health
	_shield_bar.max_value = maxf(h.max_shield, 1.0)
	_shield_bar.value = h.shield
	_health_label.text = "PV %d" % ceili(h.health)
	_shield_label.text = "Bouclier %d" % ceili(h.shield)
	var total := h.health + h.shield
	if _last_total >= 0.0 and total < _last_total - 0.01:
		_flash_damage()
	_last_total = total


func _on_dead_changed(dead: bool) -> void:
	_death_panel.visible = dead
	if dead:
		_respawn_left = Config.RESPAWN_DELAY


func _on_ammo_changed(ammo: int, magazine_size: int, reloading: bool) -> void:
	_ammo_label.text = "Rechargement..." if reloading else "%d / %d" % [ammo, magazine_size]


func _on_hit_confirmed(headshot: bool, killed: bool) -> void:
	_hitmarker.text = "✖" if killed else "×"
	_hitmarker.add_theme_font_size_override("font_size", 44 if killed else 32)
	_hitmarker.modulate = Color(1, 0.2, 0.15) if (headshot or killed) else Color.WHITE
	if _hit_tween:
		_hit_tween.kill()
	_hit_tween = create_tween()
	_hit_tween.tween_property(_hitmarker, "modulate:a", 0.0, 0.3 if killed else 0.15)


func _flash_damage() -> void:
	_damage_flash.color.a = 0.25
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_damage_flash, "color:a", 0.0, 0.35)


func _killer_text() -> String:
	var killer := _player.health.killer_id
	if killer == 0:
		return "Vous êtes mort"
	if killer == Config.MONSTER_KILLER_ID:
		return "Tué par un monstre"
	if killer == Config.STORM_KILLER_ID:
		return "Tué par la tempête"
	if killer == Config.FALL_KILLER_ID:
		return "Tombé hors de la carte"
	if killer == _player.get_peer_id():
		return "Vous vous êtes tué"
	return "Tué par le joueur %d" % killer


# --- Construction de l'interface ---

func _build() -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.8, 0.0, 0.0, 0.0)
	_add_full_rect(_damage_flash)

	# Viseur + hitmarker superposés au centre.
	var center := CenterContainer.new()
	_add_full_rect(center)
	_crosshair = _make_label("+", 26)
	center.add_child(_crosshair)
	_hitmarker = _make_label("×", 32)
	_hitmarker.modulate.a = 0.0
	center.add_child(_hitmarker)

	# Barres en bas à gauche.
	var bars := VBoxContainer.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_theme_constant_override("separation", 4)
	add_child(bars)
	# Ancré en bas à gauche, marge de 24 px, grandit vers le haut avec son contenu.
	bars.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bars.grow_horizontal = Control.GROW_DIRECTION_END
	bars.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bars.offset_left = 24
	bars.offset_right = 24
	bars.offset_top = -24
	bars.offset_bottom = -24
	# Kit : nom, niveau, XP et capacité de mouvement (au-dessus des barres).
	_kit_label = _make_label("", 16)
	_kit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_kit_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
	bars.add_child(_kit_label)
	_shield_label = _make_label("", 16)
	_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bars.add_child(_shield_label)
	_shield_bar = _make_bar(Color(0.3, 0.7, 1.0), 1.0)
	bars.add_child(_shield_bar)
	_health_label = _make_label("", 16)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bars.add_child(_health_label)
	_health_bar = _make_bar(Color(0.35, 0.85, 0.35), Config.KIT_DEFAULT_HEALTH)
	bars.add_child(_health_bar)

	# Munitions en bas à droite.
	_ammo_label = _make_label("", 30)
	add_child(_ammo_label)
	_ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ammo_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ammo_label.offset_right = -32
	_ammo_label.offset_bottom = -24

	# Emplacements d'arme, au-dessus des munitions.
	var slots := VBoxContainer.new()
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots.alignment = BoxContainer.ALIGNMENT_END
	add_child(slots)
	slots.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	slots.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	slots.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slots.offset_right = -32
	slots.offset_bottom = -70
	for i in 2:
		var label := _make_label("", 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slots.add_child(label)
		_slot_labels.append(label)

	# Consommables (au-dessus des barres) et crédits (en haut à droite).
	_items_label = _make_label("", 16)
	_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bars.add_child(_items_label)
	bars.move_child(_items_label, 0)
	_credits_label = _make_label("", 22)
	add_child(_credits_label)
	_credits_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_credits_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_credits_label.offset_right = -32
	_credits_label.offset_top = 20
	# Bandeau d'annonces (contrats capturés, prime, cœur stellaire…), en haut au centre.
	_banner = _make_label("", 26)
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 96
	_quest_label = _make_label("", 20)
	_quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quest_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	add_child(_quest_label)
	_quest_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_quest_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_quest_label.offset_right = -32
	_quest_label.offset_top = 52

	# Message d'interaction + barre d'utilisation, sous le viseur.
	var below := VBoxContainer.new()
	below.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(below)
	below.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	below.grow_horizontal = Control.GROW_DIRECTION_BOTH
	below.offset_top = 50
	below.offset_bottom = 50
	_prompt_label = _make_label("", 20)
	below.add_child(_prompt_label)
	_use_bar = _make_bar(Color(1, 1, 1, 0.85), 1.0)
	_use_bar.custom_minimum_size = Vector2(200, 8)
	_use_bar.step = 0.0
	_use_bar.visible = false
	below.add_child(_use_bar)

	# Écran de mort.
	_death_panel = ColorRect.new()
	_death_panel.color = Color(0.05, 0.0, 0.0, 0.6)
	_add_full_rect(_death_panel)
	var death_center := CenterContainer.new()
	death_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_panel.add_child(death_center)
	death_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death_label = _make_label("", 36)
	death_center.add_child(_death_label)
	_death_panel.visible = false

	# Minuteur de partie, en haut au centre (le bandeau d'annonces est en dessous).
	_clock_label = _make_label("", 24)
	add_child(_clock_label)
	_clock_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_clock_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_clock_label.offset_top = 20
	# Tempête (avertissement, dégâts), juste sous le minuteur.
	_storm_label = _make_label("", 20)
	_storm_label.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0))
	add_child(_storm_label)
	_storm_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_storm_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_storm_label.offset_top = 52
	# Embarquement en cours (au-dessus du viseur).
	_board_box = VBoxContainer.new()
	_board_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board_box)
	_board_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_board_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_board_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_board_box.offset_top = -110
	_board_box.offset_bottom = -50
	var board_label := _make_label("Embarquement… restez dans la soute", 22)
	_board_box.add_child(board_label)
	_board_bar = _make_bar(Color(0.6, 0.85, 1.0), 1.0)
	_board_bar.step = 0.0
	_board_box.add_child(_board_bar)
	_board_box.visible = false
	# À bord : spectateur.
	_aboard_label = _make_label("À BORD DE L'ÉVAC — en sécurité\nSpectateur : déplacement libre, Espace / Ctrl pour monter / descendre", 22)
	_aboard_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	add_child(_aboard_label)
	_aboard_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_aboard_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aboard_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_aboard_label.offset_bottom = -120
	_aboard_label.visible = false
	# Écran de fin.
	_results_panel = ColorRect.new()
	_results_panel.color = Color(0.0, 0.02, 0.06, 0.8)
	_add_full_rect(_results_panel)
	var results_center := CenterContainer.new()
	results_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_panel.add_child(results_center)
	results_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_results_label = _make_label("", 28)
	results_center.add_child(_results_label)
	_results_panel.visible = false


func _add_full_rect(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label


func _make_bar(color: Color, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(280, 14)
	bar.max_value = max_value
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	return bar


# --- Minimap et textes flottants des quêtes ---

## Minimap en haut à gauche : centrée sur le joueur, mêmes règles que la carte de l'écran Tab.
func _build_minimap() -> void:
	_minimap = MapView.new()
	_minimap.player = _player
	_minimap.world = _player.get_parent().get_parent() as Node3D
	_minimap.follow = true
	_minimap.view_half = Config.MINIMAP_HALF_SIZE
	_minimap.show_labels = false
	add_child(_minimap)
	_minimap.position = Vector2(20, 20)
	_minimap.size = Vector2(220, 220)


## Les textes flottants des quêtes (cristaux, contrats, Cœur stellaire) ne se voient
## qu'à moins de Config.MAP_REVEAL_RADIUS, comme sur la carte.
func _update_quest_tags() -> void:
	for node in get_tree().get_nodes_in_group("map_marker"):
		if node.has_method("set_map_tag_visible"):
			node.set_map_tag_visible(MapView.in_reveal_range((node as Node3D).global_position, _player.global_position))


## Ligne du kit : « Furet — niv. 3 (XP 260 / 450)  [K] Équipement », puis sa capacité.
func _kit_text() -> String:
	var kit := _player.kit
	if kit == null:
		return ""
	var next := kit.xp_for_next_level()
	var xp_text := "niveau max" if next < 0 else "XP %d / %d" % [kit.xp, next]
	var text := "%s — niv. %d (%s)" % [kit.get_display_name(), kit.level, xp_text]
	if kit.can_change_kit_now():
		text += "   [K] changer de kit"
	var status := _player.movement.status_text() if _player.movement else ""
	if status != "":
		text += "\n" + status
	return text
