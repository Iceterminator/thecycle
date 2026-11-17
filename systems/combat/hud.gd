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
	_on_health_changed()
	_on_ammo_changed(player.weapon.ammo, player.weapon.data.magazine_size, false)
	_on_dead_changed(player.health.is_dead)


func _process(delta: float) -> void:
	if _death_panel.visible:
		_respawn_left = maxf(_respawn_left - delta, 0.0)
		_death_label.text = "%s\nRéapparition dans %d s" % [_killer_text(), ceili(_respawn_left)]
	_crosshair.visible = not _player.weapon.is_aiming and not _player.health.is_dead


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
	bars.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bars.position = Vector2(24, -110)
	bars.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_shield_label = _make_label("", 16)
	bars.add_child(_shield_label)
	_shield_bar = _make_bar(Color(0.3, 0.7, 1.0), 1.0)
	bars.add_child(_shield_bar)
	_health_label = _make_label("", 16)
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
