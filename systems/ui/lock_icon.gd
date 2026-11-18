class_name LockIcon
extends Control
## Cadenas dessiné en code (cartes verrouillées des menus).

var color: Color = Color(1, 1, 1, 0.9)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(22, 26)
	resized.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var body := Rect2(0, h * 0.42, w, h * 0.58)
	draw_arc(Vector2(w / 2.0, h * 0.42), w * 0.32, PI, TAU, 16, color, maxf(w * 0.14, 2.0), true)
	draw_rect(body, color)
	draw_circle(Vector2(w / 2.0, h * 0.68), w * 0.1, Color(0, 0, 0, 0.7))
