class_name FpsCounter
extends Label
## Compteur d'images par seconde, discret (HUD, à côté de la minimap).
## Mis à jour deux fois par seconde ; vert >= 55, jaune >= 30, rouge en dessous.

const REFRESH := 0.5
const GOOD_FPS := 55
const OK_FPS := 30

var _left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 16)
	add_theme_constant_override("outline_size", 4)
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_refresh()


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_left = REFRESH
		_refresh()


func _refresh() -> void:
	var fps := Engine.get_frames_per_second()
	text = "%d FPS" % fps
	var color := Color(0.5, 0.9, 0.5) if fps >= GOOD_FPS else (Color(0.95, 0.85, 0.35) if fps >= OK_FPS else Color(0.95, 0.4, 0.35))
	add_theme_color_override("font_color", color)
