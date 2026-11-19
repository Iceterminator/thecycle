class_name MapOverlay
extends CanvasLayer
## Écran Tab (joueur local), affiché tant qu'on maintient Tab (action "show_map") :
##   à gauche le classement (Fame de tous les joueurs), au centre la carte (MapView),
##   à droite vos objectifs avec leur progression.
## Fond semi-transparent ; le HUD est caché pendant ce temps (il se verrait au travers).
## Lecture seule : tout vient de données déjà synchronisées (Score, repères "map_marker").
## Pas affiché par-dessus un menu (boutique, admin) : il faut que la souris soit capturée.

const OBJECTIVES_DIR := "res://data/objectives/"
const REFRESH_INTERVAL := 0.25
const FORAGE_ID := &"forage"  ## objectif du Cristal : toujours visible
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
		_refresh_ranking()
		_refresh_quests()


# =========================================================================
# Classement (gauche)
# =========================================================================

func _refresh_ranking() -> void:
	_clear(_ranking_box)
	_ranking_box.add_child(_title("CLASSEMENT"))
	var players: Array[Player] = []
	var root := _world.get_node_or_null("Players") if _world else null
	if root:
		for node in root.get_children():
			if node is Player:
				players.append(node)
	players.sort_custom(func(a: Player, b: Player) -> bool: return a.score.rank_points > b.score.rank_points)
	var rank := 1
	for p in players:
		var me := p == _player
		var who := "Vous (%s)" % ProfileManager.name_of(p.get_peer_id()) if me else ProfileManager.name_of(p.get_peer_id())
		var tags: PackedStringArray = []
		if p.is_evacuated:
			tags.append("à bord")
		elif p.health.is_dead:
			tags.append("mort")
		if p.score.beacon != "":
			tags.append(p.score.beacon)
		var line := "%d. %s — %d Fame" % [rank, who, p.score.rank_points]
		if not tags.is_empty():
			line += "\n    " + ", ".join(tags)
		var label := _label(line, 18 if me else 17)
		label.add_theme_color_override("font_color", Color(1, 0.9, 0.3) if me else Color(1, 1, 1, 0.85))
		_ranking_box.add_child(label)
		rank += 1


# =========================================================================
# Quêtes (droite)
# =========================================================================

func _refresh_quests() -> void:
	_clear(_quests_box)
	_quests_box.add_child(_title("VOS OBJECTIFS (→ Fame au prochain palier)"))
	var points: Dictionary = _player.score.objective_points
	var rates: Dictionary = _player.score.objective_rates
	var quests := _world.get_node_or_null("QuestManager") as QuestManager
	var active := quests.active_objectives if quests else PackedStringArray()
	for track in _tracks:
		# Seuls les objectifs des quêtes tirées (le Forage, lui, reste toujours affiché).
		if not active.is_empty() and track.id != FORAGE_ID and not active.has(String(track.id)):
			continue
		var pts: int = points.get(track.resource_path, 0)
		var tier := track.tiers_reached(pts)
		var previous := track.threshold(tier - 1) if tier > 0 else 0
		var next := track.threshold(tier)
		var text := "%s  %d / %d  → +%d" % [track.display_name, pts, next, track.reward(tier)]
		var rate: float = rates.get(track.resource_path, 0.0)
		if rate > 0.0:
			text += "  (+%.1f/s)" % rate
		# Couleur de l'objectif, éclaircie pour rester lisible sur le fond.
		var label := _label(text, 16)
		label.add_theme_color_override("font_color", track.color.lightened(0.35))
		_quests_box.add_child(label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.max_value = 1.0
		bar.step = 0.0
		bar.value = clampf(float(pts - previous) / maxf(next - previous, 1), 0.0, 1.0)
		var fill := StyleBoxFlat.new()
		fill.bg_color = track.color
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.2)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", bg)
		_quests_box.add_child(bar)



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
