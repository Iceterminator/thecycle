class_name MapOverlay
extends CanvasLayer
## Écran Tab (joueur local), affiché tant qu'on maintient Tab (action "show_map") :
##   à gauche le classement (Fame de tous les joueurs), au centre la carte (MapView),
##   à droite vos objectifs avec leur progression.
## Fond semi-transparent ; le HUD est caché pendant ce temps (il se verrait au travers).
## Lecture seule : tout vient de données déjà synchronisées (Score, repères "map_marker").
## Pas affiché par-dessus un menu (boutique, admin) : il faut que la souris soit capturée.

const MapOverlayPanels := preload("res://systems/map/map_overlay_panels.gd")
const OBJECTIVES_DIR := "res://data/objectives/"
const REFRESH_INTERVAL := 0.25
const PANEL_WIDTH := 330.0

var _player: Player
var _hud: CanvasLayer
var _world: Node3D
var _map: MapView
var _ranking_box: VBoxContainer
var _quests_box: VBoxContainer
var _tracks: Array[ObjectiveTrack] = []
var _refresh_left: float = 0.0


func setup(player: Player) -> void:
	_player = player
	_world = player.get_parent().get_parent() as Node3D
	for child in player.get_children():
		if child is CombatHud:
			_hud = child
	layer = 8
	visible = false
	for file in ResourceLoader.list_directory(OBJECTIVES_DIR):
		var track: ObjectiveTrack = load(OBJECTIVES_DIR + file) as ObjectiveTrack if file.ends_with(".tres") else null
		if track:
			_tracks.append(track)
	_build()


func _process(delta: float) -> void:
	var want := Input.is_action_pressed("show_map") \
			and (visible or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if want != visible:
		visible = want
		_refresh_left = 0.0
		if _hud:
			_hud.visible = not want
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_INTERVAL
		MapOverlayPanels.refresh_ranking(self)
		MapOverlayPanels.refresh_quests(self)


# =========================================================================
# Construction
# =========================================================================

func _build() -> void:
	var dim := ColorRect.new()
	# Fond semi-transparent : on devine le jeu derrière (le HUD, lui, est caché).
	dim.color = Color(0.03, 0.04, 0.05, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 20)
	margin.add_child(row)

	_ranking_box = _side_panel(row)
	# La carte reste carrée, et ce qui dépasse (cercles de tempête) est coupé au bord.
	var square := AspectRatioContainer.new()
	square.ratio = 1.0
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	square.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	square.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(square)
	_map = MapView.new()
	_map.player = _player
	_map.world = _world
	_map.clip_contents = true
	square.add_child(_map)
	_quests_box = _side_panel(row)


## Colonne de côté (texte seul, sans cadre) qui défile si elle déborde.
func _side_panel(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxEmpty.new()
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	return box


func _title(text: String) -> Label:
	var label := _label(text, 20)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	return label


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_WIDTH - 40, 0)
	label.add_theme_font_size_override("font_size", font_size)
	# Contour noir : lisible sans cadre derrière, sur le jeu à demi visible.
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
