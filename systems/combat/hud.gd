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

## Le détail est découpé : hud_build_top / hud_build_bottom / hud_screens (construction et écrans),
## hud_clock, hud_scores, hud_bottom (mises à jour), hud_widgets (petits outils).

const HudWidgets := preload("res://systems/combat/hud_widgets.gd")
const HudBuildTop := preload("res://systems/combat/hud_build_top.gd")
const HudBuildBottom := preload("res://systems/combat/hud_build_bottom.gd")
const HudScreens := preload("res://systems/combat/hud_screens.gd")
const HudClock := preload("res://systems/combat/hud_clock.gd")
const HudScores := preload("res://systems/combat/hud_scores.gd")
const HudBottom := preload("res://systems/combat/hud_bottom.gd")

# --- Palette sobre : blanc, une couleur d'accent (cuivre), rouge pour le danger ---
const PANEL := Color(0.0, 0.0, 0.0, 0.32)       ## fonds semi-transparents, sans bordure
const ACCENT := UiStyle.ACCENT
const GOLD := Color(1.0, 1.0, 1.0, 0.95)        ## chiffres importants : blanc (plus d'or)
const SHIELD := Color(0.82, 0.9, 1.0, 0.95)     ## bouclier : blanc bleuté
const HEALTH := Color(0.96, 0.96, 0.93, 0.95)   ## vie : blanc
const DIM := Color(1.0, 1.0, 1.0, 0.55)
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
	player.health.changed.connect(func() -> void: HudBottom.on_health_changed(self))
	player.health.dead_changed.connect(func(dead: bool) -> void: HudScreens.on_dead_changed(self, dead))
	player.weapon.ammo_changed.connect(func(ammo: int, size: int, reloading: bool) -> void: HudBottom.on_ammo_changed(self, ammo, size, reloading))
	player.weapon.hit_confirmed.connect(func(headshot: bool, killed: bool) -> void: HudBottom.on_hit_confirmed(self, headshot, killed))
	player.inventory.changed.connect(func() -> void: HudBottom.on_inventory_changed(self))
	player.interactor.prompt_changed.connect(func(text: String) -> void: _prompt_label.text = text)
	player.interactor.hold_progress.connect(func(ratio: float) -> void: _hold_ratio = ratio)
	player.weapon_pickup.hold_progress.connect(func(ratio: float) -> void: _hold_ratio = ratio)
	player.weapon.charge_changed.connect(func(ratio: float) -> void: _charge_ratio = ratio)
	player.score.changed.connect(func() -> void: HudScores.on_score_changed(self))
	Events.objectives_synced.connect(func() -> void: HudScores.on_score_changed(self))
	Events.contracts_changed.connect(func() -> void: HudScores.on_score_changed(self))
	HudScores.on_score_changed(self)
	Events.announcement.connect(_on_announcement)
	HudBottom.on_health_changed(self)
	HudBottom.on_inventory_changed(self)
	HudBottom.on_ammo_changed(self, player.weapon.ammo, player.magazine_for(player.weapon.data), false)
	HudScreens.on_dead_changed(self, player.health.is_dead)
	Events.match_clock_synced.connect(_on_clock_synced)
	Events.lobby_synced.connect(func(ready: Dictionary) -> void: _lobby_ready = ready)
	Events.evac_board_progress.connect(_on_board_progress)
	Events.match_results_received.connect(_on_results)
	player.evacuated_changed.connect(func(aboard: bool) -> void: _aboard_label.visible = aboard)
	Events.hud_settings_changed.connect(_on_hud_settings)
	Events.match_clock_requested.emit()


func _process(delta: float) -> void:
	HudClock.update_clock(self, delta)
	HudBottom.update_bottom(self)
	_tags_left -= delta
	if _tags_left <= 0.0:
		_tags_left = 0.2
		HudScores.update_quest_tags(self)
	_slow_left -= delta
	if _slow_left <= 0.0:
		_slow_left = 0.25
		HudScores.update_leaders(self)
		HudScores.update_squad(self)
	if _death_panel.visible:
		_respawn_left = maxf(_respawn_left - delta, 0.0)
		_death_label.text = "%s\nRéapparition dans %d s" % [HudScreens.killer_text(self), ceili(_respawn_left)]
	_crosshair.visible = not _player.weapon.is_aiming and not _player.health.is_dead
	var bar_ratio := maxf(_hold_ratio, _charge_ratio)
	_use_bar.visible = bar_ratio > 0.0
	_use_bar.value = bar_ratio


# Connexions au bus Events : méthodes du nœud (déconnexion automatique à sa libération).
func _on_clock_synced(elapsed: float, phase: int) -> void:
	HudClock.on_clock_synced(self, elapsed, phase)


func _on_announcement(text: String, color: Color) -> void:
	HudBottom.on_announcement(self, text, color)


func _on_board_progress(ratio: float) -> void:
	HudScreens.on_board_progress(self, ratio)


func _on_hud_settings() -> void:
	HudWidgets.apply_blocks(self)


func _on_results(results: Array, restart_in: float) -> void:
	HudScreens.on_results(self, results, restart_in)


func _build() -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(0.8, 0.0, 0.0, 0.0)
	HudWidgets.add_full_rect(self, _damage_flash)
	HudBuildTop.build_center(self)
	HudBuildTop.build_top_left(self)
	HudBuildTop.build_top_center(self)
	HudBuildTop.build_top_right(self)
	HudBuildBottom.build_bottom_left(self)
	HudBuildBottom.build_bottom_center(self)
	HudBuildBottom.build_bottom_right(self)
	HudScreens.build_screens(self)
	HudWidgets.apply_blocks(self)
