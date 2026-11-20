class_name BriefingBoard
extends Node3D
## Tableau d'affichage de la salle de briefing : quêtes tirées pour la partie (QuestManager.drawn_list),
## une case par type (logo teinté à la couleur de la quête + nombre), temps avant le départ et votes.
## Panneau lumineux + sprites et textes 3D, rafraîchis 4 fois / s.

const BuildRoom := preload("res://systems/briefing/briefing_room_build.gd")
const PANEL_SIZE := Vector2(6.4, 3.6)
const TITLE := Color(1.0, 0.62, 0.26)
const TEXT := Color(0.9, 0.96, 1.0)
const REFRESH := 0.25
const COLUMNS := 3
const CELL := Vector2(2.0, 0.85)
const ICON_SIZE := 0.8  ## m

var world: World
var _grid: Node3D
var _waiting: Label3D
var _status: Label3D
var _shown: Array = []
var _refresh_left: float = 0.0


func _ready() -> void:
	# Le nœud regarde vers +z (rotation donnée par la salle) : le panneau est dans le plan xy.
	BuildRoom.box(self, Vector3(PANEL_SIZE.x + 0.3, PANEL_SIZE.y + 0.3, 0.08), Vector3(0, 0, -0.06),
			BuildRoom.material(Color(0.35, 0.85, 1.0), 0.0, 0.5, Color(0.35, 0.85, 1.0), 1.5), false)
	BuildRoom.box(self, Vector3(PANEL_SIZE.x, PANEL_SIZE.y, 0.1), Vector3.ZERO,
			BuildRoom.material(Color(0.03, 0.05, 0.08), 0.2, 0.4), false)
	_label("QUÊTES DE LA PARTIE", 72, TITLE, Vector3(0, PANEL_SIZE.y / 2.0 - 0.35, 0.06))
	_grid = Node3D.new()
	_grid.position = Vector3(0, 0, 0.06)
	add_child(_grid)
	_waiting = _label("Tirage des quêtes…", 44, TEXT, Vector3(0, 0.1, 0.06))
	_status = _label("", 48, TITLE, Vector3(0, -PANEL_SIZE.y / 2.0 + 0.35, 0.06))


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left > 0.0 or world == null:
		return
	_refresh_left = REFRESH
	var quests := world.get_node_or_null("QuestManager") as QuestManager
	var list: Array = quests.drawn_list if quests else []
	if list != _shown:
		_shown = list.duplicate(true)
		_rebuild(list)
	var manager := world.match_manager
	if manager == null or manager.phase != MatchManager.Phase.BRIEFING:
		_status.text = "En attente du prochain briefing"
		return
	var needed := floori(manager.briefing_room.size() / 2.0) + 1
	_status.text = "DÉPART DANS %d s   —   VOTES %d / %d   ·   [E] VOTER" % [ceili(manager.briefing_left),
			manager.briefing_votes.size(), needed]


## Une case par type de quête : logo teinté et « ×N » (estompés si la quête arrive plus tard).
func _rebuild(list: Array) -> void:
	for child in _grid.get_children():
		child.queue_free()
	_waiting.visible = list.is_empty()
	var rows := ceili(list.size() / float(COLUMNS))
	for k in list.size():
		var entry: Dictionary = list[k]
		var in_row := mini(COLUMNS, list.size() - (k / COLUMNS) * COLUMNS)
		var x := ((k % COLUMNS) - (in_row - 1) / 2.0) * CELL.x
		var y := ((rows - 1) / 2.0 - k / COLUMNS) * CELL.y + 0.05
		var color: Color = entry.get("color", TEXT)
		if entry.get("later", false):
			color = Color(color, 0.45)
		var icon := QuestIcons.of(str(entry.get("icon", "")))
		if icon:
			var sprite := Sprite3D.new()
			sprite.texture = icon
			sprite.pixel_size = ICON_SIZE / icon.get_width()
			sprite.modulate = color
			sprite.double_sided = false
			sprite.position = Vector3(x - 0.35, y, 0)
			_grid.add_child(sprite)
		var count := _label("×%d" % entry["count"], 80, color, Vector3(x + 0.35, y, 0))
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		count.reparent(_grid, false)


func _label(text: String, size: int, color: Color, pos: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = UiStyle.font("SemiBold")
	label.font_size = size
	label.pixel_size = 0.004
	label.modulate = color
	label.outline_size = 0
	label.position = pos
	label.double_sided = false
	add_child(label)
	return label
