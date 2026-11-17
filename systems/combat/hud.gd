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

var _hold_ratio: float = 0.0  ## maintien de E en cours (cristal…)
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
	player.score.changed.connect(_on_score_changed)
	_on_score_changed()
	Events.announcement.connect(_on_announcement)
	_on_health_changed()
	_on_inventory_changed()
	_on_ammo_changed(player.weapon.ammo, player.weapon.data.magazine_size, false)
	_on_dead_changed(player.health.is_dead)


func _process(delta: float) -> void:
	if _death_panel.visible:
		_respawn_left = maxf(_respawn_left - delta, 0.0)
		_death_label.text = "%s\nRéapparition dans %d s" % [_killer_text(), ceili(_respawn_left)]
	_crosshair.visible = not _player.weapon.is_aiming and not _player.health.is_dead
	var inv := _player.inventory
	_use_bar.visible = inv.using_item != "" or _hold_ratio > 0.0
	if _hold_ratio > 0.0:
		_use_bar.value = _hold_ratio
	elif _use_bar.visible:
		var duration := maxf(inv.get_use_duration(), 0.01)
		_use_bar.value = clampf((Time.get_ticks_msec() - inv.use_started_ms) / 1000.0 / duration, 0.0, 1.0)


func _on_announcement(text: String, color: Color) -> void:
	_banner.text = text
	_banner.modulate = color
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(4.0)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.8)


func _on_score_changed() -> void:
	_quest_label.text = "%d pts de quête" % _player.score.quest_points


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
	_shield_label = _make_label("", 16)
	_shield_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bars.add_child(_shield_label)
	_shield_bar = _make_bar(Color(0.3, 0.7, 1.0), 1.0)
	bars.add_child(_shield_bar)
	_health_label = _make_label("", 16)
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	bars.add_child(_health_label)
	_health_bar = _make_bar(Color(0.35, 0.85, 0.35), Config.MAX_HEALTH)
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
	_banner.offset_top = 90
	_quest_label = _make_label("", 22)
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
