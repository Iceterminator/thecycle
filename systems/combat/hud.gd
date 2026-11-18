class_name CombatHud
extends CanvasLayer
## Interface de partie du joueur local, construite en code. Disposition :
## - en haut à gauche : minimap ronde, rang + Fame, objectifs (progression vers le palier) ;
## - en haut au centre : temps avant l'évac / le décollage, tempête, annonces ;
## - en haut à droite : état de la partie, joueurs en tête du classement ;
## - en bas à gauche : kit (niveau, XP), escouade / partenaire (PV, bouclier), objets, crédits ;
## - en bas au centre : Q et F de part et d'autre des barres bouclier / PV en segments ;
## - en bas à droite : arme en main, munitions, emplacements (icônes dessinées par type).
## Plus : viseur, hitmarker, flash de dégâts, message d'interaction, écran de mort, à terre,
## embarquement, écran de fin. Aucun contrôle ne capte la souris (MOUSE_FILTER_IGNORE).

# --- Palette (notre style : graphite, vert menthe, ambre) ---
const PANEL := Color(UiStyle.PANEL, 0.7)
const ACCENT := UiStyle.ICE
const GOLD := UiStyle.GOLD
const SHIELD := Color(0.4, 0.78, 1.0)
const HEALTH := Color(0.62, 0.92, 0.5)
const DIM := UiStyle.DIM
const MAP_SIZE := 200.0

var _player: Player

# Centre
var _crosshair: Label
var _hitmarker: Label
var _damage_flash: ColorRect
var _prompt_label: Label
var _use_bar: ProgressBar
var _hit_tween: Tween
var _flash_tween: Tween

# Haut
var _minimap: MapView
var _rank_label: Label
var _fame_label: Label
var _objectives_box: VBoxContainer
var _clock_label: Label
var _clock_sub: Label
var _storm_label: Label
var _banner: Label
var _banner_tween: Tween
var _status_label: Label
var _leaders_box: VBoxContainer

# Bas
var _kit_label: Label
var _xp_bar: ProgressBar
var _squad_box: VBoxContainer
var _items_label: Label
var _credits_label: Label
var _shield_bar: SegmentBar
var _health_bar: SegmentBar
var _bars_label: Label
var _move_label: Label
var _effects_label: Label
var _pending_label: Label
var _ability_boxes: Array[Dictionary] = []  # { panel, key, name, info, cooldown }
var _weapon_name: Label
var _ammo_label: Label
var _slot_rows: Array[Dictionary] = []  # { row, icon, key }

# Écrans
var _death_panel: ColorRect
var _death_label: Label
var _board_box: VBoxContainer
var _board_bar: ProgressBar
var _aboard_label: Label
var _results_panel: ColorRect
var _results_label: Label
var _downed_label: Label

var _clock_elapsed: float = 0.0
var _clock_phase: int = MatchManager.Phase.PLAYING
var _lobby_ready: Dictionary = {}  ## lobby : peer -> prêt
var _restart_left: float = 0.0
var _results_text: String = ""
var _hold_ratio: float = 0.0  ## maintien de E en cours (cristal…)
var _charge_ratio: float = 0.0  ## charge ou montée en régime de l'arme
var _last_total: float = -1.0
var _respawn_left: float = 0.0
var _tags_left: float = 0.0  ## prochaine mise à jour des textes flottants des quêtes
var _slow_left: float = 0.0  ## classement, escouade : mis à jour 4 fois par seconde
var _squad_key: String = ""


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
	_on_ammo_changed(player.weapon.ammo, player.magazine_for(player.weapon.data), false)
	_on_dead_changed(player.health.is_dead)
	Events.match_clock_synced.connect(_on_clock_synced)
	Events.lobby_synced.connect(func(ready: Dictionary) -> void: _lobby_ready = ready)
	Events.evac_board_progress.connect(_on_board_progress)
	Events.match_results_received.connect(_on_results)
	player.evacuated_changed.connect(func(aboard: bool) -> void: _aboard_label.visible = aboard)
	Events.match_clock_requested.emit()


func _process(delta: float) -> void:
	_update_clock(delta)
	_update_bottom()
	_tags_left -= delta
	if _tags_left <= 0.0:
		_tags_left = 0.2
		_update_quest_tags()
	_slow_left -= delta
	if _slow_left <= 0.0:
		_slow_left = 0.25
		_update_leaders()
		_update_squad()
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


# =========================================================================
# Haut : horloge, classement, objectifs
# =========================================================================

func _on_clock_synced(elapsed: float, phase: int) -> void:
	_clock_elapsed = elapsed
	_clock_phase = phase
	if phase != MatchManager.Phase.ENDED:
		_results_panel.visible = false


func _update_clock(delta: float) -> void:
	_clock_label.remove_theme_color_override("font_color")
	if _clock_phase == MatchManager.Phase.ENDED:
		_clock_label.text = "FIN"
		_clock_sub.text = "Fin de partie"
		_status_label.text = ""
		_restart_left = maxf(_restart_left - delta, 0.0)
		if _results_panel.visible:
			_results_label.text = _results_text + "\nRetour au lobby dans %d s" % ceili(_restart_left)
		return
	if _clock_phase == MatchManager.Phase.LOBBY:
		var ready := _lobby_ready.values().count(true)
		_clock_label.text = "%d / %d" % [ready, _player.get_parent().get_child_count()]
		_clock_sub.text = "LOBBY — EN ATTENTE QUE TOUT LE MONDE SOIT PRÊT"
		_storm_label.text = ""
		_status_label.text = ""
		return
	_clock_elapsed = minf(_clock_elapsed + delta, Config.match_rules.match_duration)
	_storm_label.text = StormManager.hud_text(_player.global_position).replace("\n", "  —  ") + _scanner_text()
	_update_downed()
	if _clock_phase == MatchManager.Phase.EVAC:
		_clock_label.text = _fmt(Config.match_rules.match_duration - _clock_elapsed)
		_clock_label.add_theme_color_override("font_color", ACCENT)
		_clock_sub.text = "DÉCOLLAGE DE L'ÉVAC"
		_status_label.text = "ÉVAC AU SOL — EMBARQUEZ !"
	else:
		_clock_label.text = _fmt(maxf(Config.match_rules.evac_landing_time - _clock_elapsed, 0.0))
		_clock_sub.text = "ÉVAC DANS   ·   partie %s / %s" % [_fmt(_clock_elapsed), _fmt(Config.match_rules.match_duration)]
		_status_label.text = ""
		if MatchManager.is_pad_blocked():
			var late := _clock_elapsed >= Config.match_rules.evac_landing_time
			_clock_sub.text = ("NAVETTE BLOQUÉE   ·   partie %s / %s" if late else "ÉVAC DANS   ·   partie %s / %s") % [_fmt(_clock_elapsed), _fmt(Config.match_rules.match_duration)]
			_status_label.text = "CONTRAT : tuez les monstres pour nettoyer la plateforme d'évac"


func _fmt(seconds: float) -> String:
	var s := maxi(ceili(seconds), 0)
	return "%02d:%02d" % [floori(s / 60.0), s % 60]


## Rang du joueur et les 3 premiers du classement (Fame).
func _update_leaders() -> void:
	var players: Array[Player] = []
	for node in _player.get_parent().get_children():
		if node is Player:
			players.append(node as Player)
	players.sort_custom(func(a: Player, b: Player) -> bool: return a.score.rank_points > b.score.rank_points)
	var rank := players.find(_player) + 1
	_rank_label.text = "%d%s" % [rank, "er" if rank == 1 else "e"]
	for child in _leaders_box.get_children():
		child.queue_free()
	for i in mini(players.size(), 3):
		var p := players[i]
		var label := _make_label("%d  %s   %d ★" % [i + 1, ProfileManager.name_of(p.get_peer_id()), p.score.rank_points], 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if p == _player:
			label.add_theme_color_override("font_color", GOLD)
		_leaders_box.add_child(label)


func _on_score_changed() -> void:
	_fame_label.text = "★ %d" % _player.score.rank_points
	# Une ligne par objectif commencé : progression vers le prochain palier.
	for child in _objectives_box.get_children():
		child.queue_free()
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
		var goal := track.threshold(tier)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		var dot := ColorRect.new()
		dot.color = track.color
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 1)
		row.add_child(col)
		var rate: float = rates.get(path, 0.0)
		var line := _make_label("%s   %d / %d   ★ +%d%s" % [track.display_name, pts, goal, track.reward(tier),
				"   (+%.1f/s)" % rate if rate > 0.0 else ""], 14)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(line)
		var bar := _make_bar(track.color, maxf(goal, 1.0))
		bar.custom_minimum_size = Vector2(190, 4)
		bar.value = pts
		col.add_child(bar)
		_objectives_box.add_child(row)


func _on_announcement(text: String, color: Color) -> void:
	_banner.text = text
	_banner.modulate = color
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(4.0)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.8)


# =========================================================================
# Bas : kit, escouade, objets, barres, Q / F, armes
# =========================================================================

func _update_bottom() -> void:
	var kit := _player.kit
	if kit:
		var next := kit.xp_for_next_level()
		_kit_label.text = "%s — niv. %d%s" % [kit.get_display_name(), kit.level, "   [K] changer de kit" if kit.can_change_kit_now() else ""]
		_xp_bar.max_value = maxf(next, 1.0) if next > 0 else 1.0
		_xp_bar.value = kit.xp if next > 0 else 1.0
	_move_label.text = _player.movement.status_text() if _player.movement else ""
	_effects_label.text = ("Effets : " + _player.buffs.status_text()) if _player.buffs and _player.buffs.status_text() != "" else ""
	var abilities := _player.abilities
	if abilities == null:
		return
	_pending_label.text = ">> %s acheté : appuyez sur Q ou F pour l'équiper" % Shop.entry_name(abilities.pending) if abilities.pending != "" else ""
	for slot in _ability_boxes.size():
		var box: Dictionary = _ability_boxes[slot]
		var id := abilities.loadout[slot]
		var name_label: Label = box["name"]
		var info: Label = box["info"]
		var cooldown: ColorRect = box["cooldown"]
		cooldown.visible = false
		if box["id"] != id:
			box["id"] = id
			var slot_node: Control = box["slot"]
			for child in slot_node.get_children():
				child.queue_free()
			var visual := ItemVisual.make(id)
			if visual:
				slot_node.add_child(visual)
				visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if id == "":
			name_label.text = "—"
			info.text = ""
		elif AbilityController.is_gadget(id):
			var inv_slot := Inventory.WEAPON_SLOTS + slot
			name_label.text = Shop.entry_name(id)
			info.text = "×%d" % _player.inventory.slot_ammo[inv_slot]
			(box["panel"] as Panel).modulate = Color(1, 1, 1) if _player.inventory.active_slot != inv_slot else Color(1.2, 1.2, 0.9)
		else:
			var a := abilities.get_slot(slot)
			name_label.text = a.get_display_name() if a else id
			var left: float = abilities.cooldown_left[slot]
			if left > 0.0 and a:
				var total := maxf(a.get_cooldown(abilities.upgrades[slot], _player.kit.get_effect("ability_cooldown_mult")), 0.1)
				cooldown.visible = true
				cooldown.anchor_top = 1.0 - clampf(left / total, 0.0, 1.0)
				info.text = "%d s" % ceili(left)
			else:
				info.text = "+%d" % abilities.upgrades[slot] if abilities.upgrades[slot] > 0 else ""


## Escouade et partenaire de pacte : nom, PV et bouclier.
func _update_squad() -> void:
	var allies: Array[Player] = []
	for node in _player.get_parent().get_children():
		var p := node as Player
		if p and p != _player and Allies.allied(_player.get_peer_id(), p.get_peer_id()):
			allies.append(p)
	var key := ",".join(allies.map(func(p: Player) -> String: return p.name))
	if key != _squad_key:
		_squad_key = key
		for child in _squad_box.get_children():
			child.queue_free()
		for p in allies:
			var row := VBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_theme_constant_override("separation", 1)
			row.set_meta("peer", p.get_peer_id())
			var label := _make_label(ProfileManager.name_of(p.get_peer_id()), 15)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.add_child(label)
			var shield := _make_bar(SHIELD, 1.0)
			shield.custom_minimum_size = Vector2(190, 4)
			row.add_child(shield)
			var health := _make_bar(HEALTH, 1.0)
			health.custom_minimum_size = Vector2(190, 6)
			row.add_child(health)
			_squad_box.add_child(row)
	for row in _squad_box.get_children():
		var p := _player.get_parent().get_node_or_null(str(row.get_meta("peer", 0))) as Player
		if p == null or row.get_child_count() < 3:
			continue
		var h := p.health
		var label := row.get_child(0) as Label
		label.text = ProfileManager.name_of(p.get_peer_id()) + ("  — À TERRE" if h.is_downed else "  — mort" if h.is_dead else "")
		var shield := row.get_child(1) as ProgressBar
		shield.max_value = maxf(h.max_shield, 1.0)
		shield.value = h.shield
		var health := row.get_child(2) as ProgressBar
		health.max_value = maxf(h.get_max_health(), 1.0)
		health.value = h.health


func _on_inventory_changed() -> void:
	var inv := _player.inventory
	for i in _slot_rows.size():
		var item := Items.get_item(StringName(inv.slot_ids[i]))
		var row: Dictionary = _slot_rows[i]
		var icon: WeaponIcon = row["icon"]
		icon.weapon = item.weapon if item else null
		var active := i == inv.active_slot
		icon.tint = Color(0.93, 0.95, 0.97) if active else Color(0.8, 0.82, 0.85, 0.45)
		icon.accent = Color(FactionData.color_of(int(item.weapon.faction)), 1.0 if active else 0.5) if item and item.weapon and int(item.weapon.faction) > 0 else Color(0, 0, 0, 0)
		(row["key"] as Label).add_theme_color_override("font_color", GOLD if active else DIM)
		(row["row"] as Control).visible = item != null
	var active_item := Items.get_item(inv.get_active_id())
	_weapon_name.text = active_item.display_name if active_item else ""
	var text := "[3] Soins ×%d    [4] Recharges ×%d" % [inv.medkits, inv.shield_cells]
	for res_id: String in inv.carried:
		var res := Items.get_item(StringName(res_id))
		text += "\n%s ×%d" % [res.display_name if res else res_id, inv.carried[res_id]]
	_items_label.text = text
	_credits_label.text = "¢ %d   [T] boutique" % inv.credits


func _on_health_changed() -> void:
	var h := _player.health
	_shield_bar.max_value = maxf(h.max_shield, 1.0)
	_shield_bar.value = h.shield
	_health_bar.max_value = maxf(h.get_max_health(), 1.0)
	_health_bar.value = h.health
	_bars_label.text = "%d  |  %d" % [ceili(h.shield), ceili(h.health)]
	var total := h.health + h.shield
	if _last_total >= 0.0 and total < _last_total - 0.01:
		_flash_damage()
	_last_total = total


func _on_dead_changed(dead: bool) -> void:
	_death_panel.visible = dead
	if dead:
		_respawn_left = Config.match_rules.respawn_delay


func _on_ammo_changed(ammo: int, magazine_size: int, reloading: bool) -> void:
	_ammo_label.text = "RECHARGEMENT" if reloading else "%d / %d" % [ammo, magazine_size]


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
	Events.camera_shake_requested.emit(_player.camera.global_position, 0.35, 1.0)
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
	if killer == Config.FALL_KILLER_ID:
		return "Tombé hors de la carte"
	if killer == _player.get_peer_id():
		return "Vous vous êtes tué"
	return "Tué par %s" % ProfileManager.name_of(killer)


func _on_board_progress(ratio: float) -> void:
	_board_box.visible = ratio > 0.0
	_board_bar.value = ratio


func _on_results(results: Array, restart_in: float) -> void:
	_restart_left = restart_in
	var lines: PackedStringArray = ["FIN DE PARTIE — CLASSEMENT", ""]
	var rank := 1
	for entry: Dictionary in results:
		var peer: int = entry["peer"]
		var who := "Vous" if peer == _player.get_peer_id() else ProfileManager.name_of(peer)
		var status := "évacué" if entry["evacuated"] else "resté au sol (-%d)" % Config.economy.evac_missed_penalty
		lines.append("%d. %s — %d Fame — %s" % [rank, who, entry["points"], status])
		rank += 1
	_results_text = "\n".join(lines) + "\n"
	_results_panel.visible = true


# =========================================================================
# Construction
# =========================================================================

func _build() -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.8, 0.0, 0.0, 0.0)
	_add_full_rect(_damage_flash)
	_build_center()
	_build_top_left()
	_build_top_center()
	_build_top_right()
	_build_bottom_left()
	_build_bottom_center()
	_build_bottom_right()
	_build_screens()


func _build_center() -> void:
	var center := CenterContainer.new()
	_add_full_rect(center)
	_crosshair = _make_label("+", 26)
	center.add_child(_crosshair)
	_hitmarker = _make_label("×", 32)
	_hitmarker.modulate.a = 0.0
	center.add_child(_hitmarker)
	# Message d'interaction + barre d'utilisation, sous le viseur.
	var below := _vbox(4)
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


## Minimap ronde (MapView découpé par un disque), rang et Fame, objectifs.
func _build_top_left() -> void:
	var disc := Panel.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	disc.position = Vector2(20, 20)
	disc.size = Vector2(MAP_SIZE, MAP_SIZE)
	disc.add_theme_stylebox_override("panel", _round_style(Color(0.05, 0.08, 0.08, 0.9), Color(0, 0, 0, 0), 0))
	add_child(disc)
	_minimap = MapView.new()
	_minimap.player = _player
	_minimap.world = _player.get_parent().get_parent() as Node3D
	_minimap.follow = true
	_minimap.view_half = Config.MINIMAP_HALF_SIZE
	_minimap.show_labels = false
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(_minimap)
	_minimap.position = Vector2.ZERO
	_minimap.size = Vector2(MAP_SIZE, MAP_SIZE)
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = disc.position
	ring.size = disc.size
	ring.add_theme_stylebox_override("panel", _round_style(Color(0, 0, 0, 0), ACCENT.darkened(0.2), 3))
	add_child(ring)

	var info := HBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 14)
	info.position = Vector2(36 + MAP_SIZE, 30)
	add_child(info)
	info.add_child(_chip("TAB"))
	_rank_label = _make_label("1er", 30)
	info.add_child(_rank_label)
	_fame_label = _make_label("★ 0", 30)
	_fame_label.add_theme_color_override("font_color", GOLD)
	info.add_child(_fame_label)

	_objectives_box = _vbox(6)
	_objectives_box.position = Vector2(24, 36 + MAP_SIZE)
	add_child(_objectives_box)


func _build_top_center() -> void:
	var box := _vbox(0)
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.offset_top = 12
	_clock_label = _make_label("00:00", 38)
	box.add_child(_clock_label)
	_clock_sub = _make_label("", 14)
	_clock_sub.add_theme_color_override("font_color", DIM)
	box.add_child(_clock_sub)
	_storm_label = _make_label("", 18)
	_storm_label.add_theme_color_override("font_color", Color(0.85, 0.6, 1.0))
	box.add_child(_storm_label)
	# Bandeau d'annonces (contrats capturés, prime, cœur stellaire…).
	_banner = _make_label("", 24)
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 120


func _build_top_right() -> void:
	var box := _vbox(6)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.offset_right = -28
	box.offset_top = 22
	_status_label = _make_label("", 20)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.add_theme_color_override("font_color", ACCENT)
	box.add_child(_status_label)
	_leaders_box = _vbox(2)
	box.add_child(_leaders_box)


func _build_bottom_left() -> void:
	var box := _vbox(6)
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	box.grow_horizontal = Control.GROW_DIRECTION_END
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_left = 24
	box.offset_right = 24
	box.offset_bottom = -24
	box.offset_top = -24
	_squad_box = _vbox(8)
	box.add_child(_squad_box)
	_kit_label = _make_label("", 15)
	_kit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_kit_label.add_theme_color_override("font_color", ACCENT)
	box.add_child(_kit_label)
	_xp_bar = _make_bar(ACCENT, 1.0)
	_xp_bar.custom_minimum_size = Vector2(190, 3)
	box.add_child(_xp_bar)
	_items_label = _make_label("", 15)
	_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_items_label)
	_credits_label = _make_label("", 22)
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_credits_label.add_theme_color_override("font_color", GOLD)
	box.add_child(_credits_label)


## Q à gauche, F à droite, et au milieu bouclier (haut) et PV (bas) en segments de 100.
func _build_bottom_center() -> void:
	var box := _vbox(4)
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -22
	box.offset_top = -22
	_pending_label = _make_label("", 16)
	_pending_label.add_theme_color_override("font_color", ACCENT)
	box.add_child(_pending_label)
	_effects_label = _make_label("", 14)
	_effects_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	box.add_child(_effects_label)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	row.add_child(_ability_box("Q"))
	var bars := _vbox(3)
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bars)
	_move_label = _make_label("", 13)
	_move_label.add_theme_color_override("font_color", DIM)
	bars.add_child(_move_label)
	_shield_bar = SegmentBar.new()
	_shield_bar.custom_minimum_size = Vector2(380, 9)
	_shield_bar.color = SHIELD
	bars.add_child(_shield_bar)
	_health_bar = SegmentBar.new()
	_health_bar.custom_minimum_size = Vector2(380, 13)
	_health_bar.color = HEALTH
	bars.add_child(_health_bar)
	_bars_label = _make_label("", 13)
	_bars_label.add_theme_color_override("font_color", DIM)
	bars.add_child(_bars_label)
	row.add_child(_ability_box("F"))


func _ability_box(key: String) -> Control:
	var col := _vbox(2)
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(170, 62)
	panel.clip_contents = true
	var style := UiStyle.chamfer_box(PANEL, Color(ACCENT, 0.5), 1, 8)
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
	var inner := _vbox(0)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(inner)
	var name_label := _make_label("—", 13)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(100, 0)
	inner.add_child(name_label)
	var info := _make_label("", 18)
	info.add_theme_color_override("font_color", GOLD)
	inner.add_child(info)
	var key_chip := _chip(key)
	key_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(key_chip)
	_ability_boxes.append({"panel": panel, "name": name_label, "info": info, "cooldown": cooldown, "slot": slot, "id": ""})
	return col


func _build_bottom_right() -> void:
	var box := _vbox(4)
	add_child(box)
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
		var key := _make_label(str(i + 1) if i < Inventory.WEAPON_SLOTS else ["Q", "F"][i - Inventory.WEAPON_SLOTS], 18)
		key.custom_minimum_size = Vector2(22, 0)
		row.add_child(key)
		box.add_child(row)
		_slot_rows.append({"row": row, "icon": icon, "key": key})
	# Les gadgets (Q / F) apparaissent sous les armes, seulement s'ils existent.
	_weapon_name = _make_label("", 18)
	_weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_weapon_name)
	_ammo_label = _make_label("", 40)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_ammo_label)


func _build_screens() -> void:
	# Embarquement en cours (au-dessus du viseur).
	_board_box = _vbox(4)
	add_child(_board_box)
	_board_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_board_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_board_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_board_box.offset_top = -110
	_board_box.offset_bottom = -50
	_board_box.add_child(_make_label("Embarquement… restez dans la soute", 22))
	_board_bar = _make_bar(ACCENT, 1.0)
	_board_bar.custom_minimum_size = Vector2(320, 10)
	_board_bar.step = 0.0
	_board_box.add_child(_board_bar)
	_board_box.visible = false
	# À bord : spectateur.
	_aboard_label = _make_label("À BORD DE L'ÉVAC — en sécurité\nSpectateur : déplacement libre, Espace / Ctrl pour monter / descendre", 22)
	_aboard_label.add_theme_color_override("font_color", SHIELD)
	add_child(_aboard_label)
	_aboard_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_aboard_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aboard_label.offset_top = 140
	_aboard_label.visible = false
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


# =========================================================================
# Petits outils
# =========================================================================

func _add_full_rect(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _vbox(separation: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", separation)
	return box


func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	if size >= 22:
		label.add_theme_font_override("font", UiStyle.font("SemiBold"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	return label


## Petite étiquette de touche : [TAB], [Q]…
func _chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.12)
	style.border_color = Color(1, 1, 1, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	_chip_margins(style)
	chip.add_theme_stylebox_override("panel", style)
	var label := _make_label(text, 13)
	chip.add_child(label)
	return chip


func _chip_margins(style: StyleBoxFlat) -> void:
	style.content_margin_top = 1
	style.content_margin_bottom = 1


func _round_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(int(MAP_SIZE / 2.0))
	style.corner_detail = 24
	style.anti_aliasing = true
	return style


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


# =========================================================================
# Textes flottants, scanner, à terre
# =========================================================================

## Les textes flottants des quêtes (cristaux, contrats, Cœur stellaire) ne se voient
## qu'à moins de Config.MAP_REVEAL_RADIUS, comme sur la carte.
func _update_quest_tags() -> void:
	for node in get_tree().get_nodes_in_group("map_marker"):
		if node.has_method("set_map_tag_visible"):
			node.set_map_tag_visible(MapView.in_reveal_range((node as Node3D).global_position, _player.global_position))


## Alarme de proximité : un joueur non allié à moins de Config.combat.scanner_range.
func _scanner_text() -> String:
	var nearest := INF
	for node in _player.get_parent().get_children():
		var other := node as Player
		if other == null or other == _player or other.health.is_dead or other.is_evacuated:
			continue
		if Allies.allied(_player.get_peer_id(), other.get_peer_id()):
			continue
		nearest = minf(nearest, other.global_position.distance_to(_player.global_position))
	if nearest > Config.combat.scanner_range:
		return ""
	return "   ⚠ Prospecteur à %d m" % roundi(nearest)


func _update_downed() -> void:
	var h := _player.health
	if _downed_label == null:
		_downed_label = _make_label("", 30)
		_downed_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
		add_child(_downed_label)
		_downed_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_downed_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_downed_label.offset_top = 120
	_downed_label.visible = h.is_downed
	if h.is_downed:
		var left := maxf(Config.combat.downed_time - (Time.get_ticks_msec() - h.downed_at_ms) / 1000.0, 0.0)
		_downed_label.text = "À TERRE — %d s\nUn coéquipier peut vous relever (E maintenu)" % ceili(left)
