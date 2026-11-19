class_name DropMapMarkers
extends Control
## Points de largage dessinés sur la carte nue de l'écran de largage (enfant de MapView) :
## le sien (jaune, « VOUS ») et ceux des membres de son escouade (verts, avec leur nom).

const SELF_COLOR := Color(1.0, 0.9, 0.2)
const ALLY_COLOR := Color(0.4, 1.0, 0.6)

var map: MapView
var local_peer: int = 0
var points: Array = []  ## [[peer, Vector3], ...]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for entry: Array in points:
		var mine: bool = entry[0] == local_peer
		var color := SELF_COLOR if mine else ALLY_COLOR
		var p := map.to_map(entry[1])
		draw_circle(p, 7.0, color)
		draw_arc(p, 11.0, 0, TAU, 24, color, 2.0)
		var text := "VOUS" if mine else ProfileManager.name_of(entry[0])
		var font := ThemeDB.fallback_font
		var at := p + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x / 2.0, -16.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.85))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
