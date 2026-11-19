extends RefCounted
## Petits éléments de dessin de AbilityIcon : silhouette, éclair, croix.
## Repère 40 × 40 ; `p` fournit palette et primitives (WeaponIconCanvas).

const Canvas := preload("res://systems/ui/weapon_icon_canvas.gd")

## Silhouette de prospecteur (tête en (x, y)).
static func person(p: Canvas, x: float, y: float, color: Color) -> void:
	p.circle(x, y + 3, 3.5, color)
	p.poly([Vector2(x - 6, y + 8), Vector2(x + 6, y + 8), Vector2(x + 5, y + 20), Vector2(x - 5, y + 20)], color)
	p.poly([Vector2(x - 5, y + 20), Vector2(x - 1, y + 20), Vector2(x - 2, y + 28), Vector2(x - 6, y + 28)], color)
	p.poly([Vector2(x + 1, y + 20), Vector2(x + 5, y + 20), Vector2(x + 6, y + 28), Vector2(x + 2, y + 28)], color)

static func bolt(p: Canvas, x: float, y: float, color: Color) -> void:
	p.poly([Vector2(x + 1, y - 6), Vector2(x - 4, y + 1), Vector2(x, y + 1), Vector2(x - 1, y + 6), Vector2(x + 4, y - 1), Vector2(x, y - 1)], color)

static func plus(p: Canvas, x: float, y: float, r: float, color: Color) -> void:
	p.rect(x - r, y - r * 0.3, r * 2, r * 0.6, color, false)
	p.rect(x - r * 0.3, y - r, r * 0.6, r * 2, color, false)

## Rectangle dans le repère courant (après draw_set_transform).
static func local_rect(p: Canvas, x: float, y: float, w: float, h: float, color: Color) -> void:
	p.c.draw_rect(Rect2(x, y, w, h), color)
	p.c.draw_rect(Rect2(x, y, w, h), p.line, false, 0.6)
