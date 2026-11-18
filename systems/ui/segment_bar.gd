class_name SegmentBar
extends Control
## Barre découpée en segments (un segment = `segment_value` points), dessinée en code :
## PV et bouclier du HUD. Le segment entamé est rempli en partie ; un segment « perdu
## récemment » reste un moment plus clair (`trail`), pour bien voir les dégâts.

var max_value: float = 100.0:
	set(v):
		max_value = maxf(v, 1.0)
		queue_redraw()
var value: float = 100.0:
	set(v):
		if v < value:
			_trail = maxf(_trail, value)
			_trail_hold = 0.4
		value = clampf(v, 0.0, max_value)
		queue_redraw()
var segment_value: float = 100.0
var color: Color = Color.WHITE
var back_color: Color = Color(0, 0, 0, 0.45)
var gap: float = 3.0

var _trail: float = 0.0
var _trail_hold: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _trail <= value:
		return
	if _trail_hold > 0.0:
		_trail_hold -= delta
		return
	_trail = maxf(_trail - max_value * delta * 1.5, value)
	queue_redraw()


func _draw() -> void:
	var count := maxi(ceili(max_value / maxf(segment_value, 1.0)), 1)
	var width := (size.x - gap * (count - 1)) / count
	for i in count:
		var x := i * (width + gap)
		var rect := Rect2(x, 0, width, size.y)
		draw_rect(rect, back_color)
		var from := i * segment_value
		var seg_max := minf(segment_value, max_value - from)
		var trail_fill := clampf((_trail - from) / seg_max, 0.0, 1.0)
		if trail_fill > 0.0:
			draw_rect(Rect2(x, 0, width * trail_fill, size.y), Color(1, 1, 1, 0.55))
		var fill := clampf((value - from) / seg_max, 0.0, 1.0)
		if fill > 0.0:
			draw_rect(Rect2(x, 0, width * fill, size.y), color)
