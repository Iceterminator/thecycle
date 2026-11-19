extends RefCounted
## Dessins de capacités de AbilityIcon (2/2) : sphères, portail, balise, piège, bombe, aura.
## Repère 40 × 40 ; `p` fournit palette et primitives (WeaponIconCanvas).

const Canvas := preload("res://systems/ui/weapon_icon_canvas.gd")
const Parts := preload("res://systems/ui/ability_icon_parts.gd")


static func sphere(p: Canvas, triage: bool) -> void:
	p.circle(20, 20, 13, p.metal)
	p.c.draw_arc(p.pt(Vector2(20, 20)), 17 * p.scale, 0.0, TAU, 28, Color(p.glow, p.glow.a * 0.7), p.stroke(1.5), true)
	p.circle(16, 16, 3, p.light)
	if triage:
		Parts.plus(p, 20, 21, 6, p.glow)
	else:
		Parts.bolt(p, 20, 20, p.glow)


static func portal(p: Canvas) -> void:
	p.c.draw_set_transform(p.pt(Vector2(13, 20)), 0.0, Vector2(p.scale * 0.45, p.scale))
	p.c.draw_arc(Vector2.ZERO, 14, 0.0, TAU, 28, p.glow, 3.0, true)
	p.c.draw_set_transform(p.pt(Vector2(31, 20)), 0.0, Vector2(p.scale * 0.45, p.scale))
	p.c.draw_arc(Vector2.ZERO, 14, 0.0, TAU, 28, p.metal, 3.0, true)
	p.c.draw_set_transform(Vector2.ZERO)
	p.rect(16, 18.5, 10, 3, p.light, false)
	p.poly([Vector2(25, 15), Vector2(30, 20), Vector2(25, 25)], p.light)


static func ward(p: Canvas) -> void:
	p.rect(18, 18, 4, 18, p.metal)
	p.rect(13, 35, 14, 3, p.dark)
	p.circle(20, 16, 4, p.glow)
	for r in [9.0, 14.0]:
		p.c.draw_arc(p.pt(Vector2(20, 16)), r * p.scale, -PI * 0.85, -PI * 0.15, 16, Color(p.glow, p.glow.a * 0.8), p.stroke(1.5), true)


static func snare(p: Canvas) -> void:
	p.c.draw_arc(p.pt(Vector2(20, 24)), 13 * p.scale, 0.0, TAU, 28, p.metal, p.stroke(3.0), true)
	for i in 10:
		var a := i * TAU / 10.0
		var base := Vector2(20, 24) + Vector2(cos(a), sin(a)) * 11.0
		var tip := Vector2(20, 24) + Vector2(cos(a), sin(a)) * 6.0
		var side := Vector2(-sin(a), cos(a)) * 1.6
		p.poly([base + side, tip, base - side], p.dark)
	p.circle(20, 24, 3, p.glow)


static func warp_bomb(p: Canvas) -> void:
	p.circle(20, 22, 12, p.dark)
	for i in 3:
		p.c.draw_arc(p.pt(Vector2(20, 22)), (4.0 + i * 3.0) * p.scale, i * 1.2, i * 1.2 + PI * 1.3, 16, p.glow, p.stroke(1.5), true)
	p.rect(17, 7, 6, 4, p.metal)


static func aura(p: Canvas) -> void:
	for r in [16.0, 11.0]:
		p.c.draw_arc(p.pt(Vector2(20, 20)), r * p.scale, 0.0, TAU, 28, Color(p.glow, p.glow.a * (0.5 if r > 12.0 else 0.85)), p.stroke(2.0), true)
	p.circle(20, 20, 7, p.metal)
	Parts.plus(p, 20, 20, 5, p.glow)

