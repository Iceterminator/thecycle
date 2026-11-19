extends RefCounted
## Palette et primitives de dessin (rectangle, polygone, cercle avec contour) partagées par
## WeaponIcon et AbilityIcon. Dessine sur le Control `c` dans un repère logique mis à
## l'échelle (`scale`, `origin`). `outline_w` : épaisseur du contour (0.8 armes, 0.6 capacités).

var c: CanvasItem
var scale: float = 1.0
var origin: Vector2 = Vector2.ZERO
var tint: Color = Color.WHITE
var accent: Color = Color(0, 0, 0, 0)
var outline_w: float = 0.8
var metal: Color
var dark: Color
var light: Color
var line: Color
var glow: Color  ## Couleur d'éclat (AbilityIcon)


func _init(canvas: CanvasItem, line_width: float = 0.8) -> void:
	c = canvas
	outline_w = line_width


## Fixe l'échelle, l'origine et dérive la palette depuis la teinte.
func prepare(draw_scale: float, draw_origin: Vector2, tint_color: Color, accent_color: Color) -> void:
	scale = draw_scale
	origin = draw_origin
	tint = tint_color
	accent = accent_color
	metal = tint
	dark = Color(tint.r * 0.42, tint.g * 0.42, tint.b * 0.45, tint.a)
	light = Color(minf(tint.r * 1.25 + 0.15, 1.0), minf(tint.g * 1.25 + 0.15, 1.0), minf(tint.b * 1.25 + 0.15, 1.0), tint.a)
	line = Color(0, 0, 0, 0.6 * tint.a)


func pt(p: Vector2) -> Vector2:
	return origin + p * scale


## Épaisseur de trait mise à l'échelle (au moins 1 px).
func stroke(w: float) -> float:
	return maxf(w * scale, 1.0)


func rect(x: float, y: float, w: float, h: float, color: Color, outline: bool = true) -> void:
	var r := Rect2(pt(Vector2(x, y)), Vector2(w, h) * scale)
	c.draw_rect(r, color)
	if outline:
		c.draw_rect(r, line, false, stroke(outline_w))


func poly(points: Array[Vector2], color: Color) -> void:
	var out := PackedVector2Array()
	for p in points:
		out.append(pt(p))
	c.draw_colored_polygon(out, color)
	out.append(out[0])
	c.draw_polyline(out, line, stroke(outline_w), true)


func circle(x: float, y: float, r: float, color: Color) -> void:
	c.draw_circle(pt(Vector2(x, y)), r * scale, color)
	c.draw_arc(pt(Vector2(x, y)), r * scale, 0.0, TAU, 24, line, stroke(outline_w), true)
