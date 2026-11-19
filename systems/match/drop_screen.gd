class_name DropScreen
extends CanvasLayer
## Écran plein écran de la phase de largage (joueur local) : compte à rebours, carte nue
## (relief et obstacles, sans quêtes ni monstres ni adversaires) avec le point de largage du
## joueur et ceux de son escouade, et la liste des quêtes tirées pour cette partie.
## Reçoit Events.drop_phase_started du MatchManager ; se ferme à la fin du compte à rebours.

const LIST_REFRESH := 0.25
const LATER_COLOR := Color(0.6, 0.65, 0.7)

var _player: Player
var _left: float = 0.0
var _map: MapView
var _markers: DropMapMarkers
var _count_label: Label
var _quests_box: VBoxContainer
var _list_refresh: float = 0.0


func setup(player: Player) -> void:
	_player = player
	layer = 12  # au-dessus du lobby et du HUD
	visible = false
	var back := ColorRect.new()
	back.color = Color(0.03, 0.04, 0.06)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 40)
	add_child(row)
	_map = MapView.new()
	_map.player = player
	_map.world = player.get_parent().get_parent() as Node3D
	_map.bare = true
	_map.show_labels = false
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_stretch_ratio = 1.5
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_map)
	_markers = DropMapMarkers.new()
	_markers.map = _map
	_markers.local_peer = player.get_peer_id()
	_map.add_child(_markers)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 1.0
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	side.add_child(_label("LARGAGE DANS", 28, Color(0.7, 0.85, 1.0)))
	_count_label = _label("15", 140, Color(1.0, 0.9, 0.2))
	side.add_child(_count_label)
	side.add_child(_label("Quêtes de cette partie", 26, Color.WHITE))
	_quests_box = VBoxContainer.new()
	side.add_child(_quests_box)
	Events.drop_phase_started.connect(_on_drop_started)
	Events.match_clock_synced.connect(func(_elapsed: float, phase: int) -> void:
		if phase != MatchManager.Phase.DROP:
			visible = false)


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left <= 0.0:
		visible = false
		return
	_count_label.text = str(ceili(_left))
	_list_refresh -= delta
	if _list_refresh <= 0.0:
		_list_refresh = LIST_REFRESH
		_refresh_list()


func _on_drop_started(points: Array, seconds: float) -> void:
	_markers.points = points
	_left = seconds
	_list_refresh = 0.0
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## La liste vient du QuestManager (tirée juste après le début de la phase : on relit).
func _refresh_list() -> void:
	var manager := _map.world.get_node_or_null("QuestManager") as QuestManager
	if manager == null:
		return
	for child in _quests_box.get_children():
		child.queue_free()
	for entry: Dictionary in manager.drawn_list:
		var later: bool = entry["later"]
		var text := "%s ×%d" % [entry["name"], entry["count"]] + (" (plus tard)" if later else "")
		_quests_box.add_child(_label(text, 22, LATER_COLOR if later else Color.WHITE))


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label
