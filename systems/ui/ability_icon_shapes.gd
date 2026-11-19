extends RefCounted
## Dessins de capacités de AbilityIcon (1/2) : grenade, seringue, tourelle, murs, dômes, camouflage, frappes.
## Repère 40 × 40 ; `p` fournit palette et primitives (WeaponIconCanvas).

const Canvas := preload("res://systems/ui/weapon_icon_canvas.gd")
const Parts := preload("res://systems/ui/ability_icon_parts.gd")


static func grenade(p: Canvas) -> void:
	p.circle(20, 24, 11, p.metal)
	p.rect(9, 22, 22, 2, p.dark, false)
	p.rect(16, 9, 8, 5, p.dark)
	Parts.bolt(p, 20, 17, p.glow)


static func syringe(p: Canvas, adrenaline: bool) -> void:
	p.c.draw_set_transform(p.pt(Vector2(20, 20)), -PI / 4.0, Vector2(p.scale, p.scale))
	Parts.local_rect(p, -13, -4, 20, 8, p.metal)
	Parts.local_rect(p, -10, -2.5, 12, 5, p.glow)
	Parts.local_rect(p, 7, -1, 9, 2, p.dark)
	Parts.local_rect(p, -17, -2, 4, 4, p.dark)
	Parts.local_rect(p, -19, -5, 2, 10, p.metal)
	p.c.draw_set_transform(Vector2.ZERO)
	if adrenaline:
		Parts.bolt(p, 31, 9, p.glow)
	else:
		Parts.plus(p, 31, 9, 4, p.glow)


static func stand(p: Canvas) -> void:
	# Prospecteur ancré au sol : silhouette + chevrons vers le bas.
	Parts.person(p, 20, 6, p.metal)
	p.rect(6, 34, 28, 3, p.dark)
	for i in 2:
		p.poly([Vector2(5, 20 + i * 6), Vector2(9, 24 + i * 6), Vector2(5, 28 + i * 6)], p.glow)
		p.poly([Vector2(35, 20 + i * 6), Vector2(31, 24 + i * 6), Vector2(35, 28 + i * 6)], p.glow)


static func turret(p: Canvas) -> void:
	p.c.draw_line(p.pt(Vector2(20, 26)), p.pt(Vector2(10, 37)), p.dark, p.stroke(2.0))
	p.c.draw_line(p.pt(Vector2(20, 26)), p.pt(Vector2(30, 37)), p.dark, p.stroke(2.0))
	p.c.draw_line(p.pt(Vector2(20, 26)), p.pt(Vector2(20, 37)), p.dark, p.stroke(2.0))
	p.rect(11, 15, 16, 11, p.metal)
	p.rect(27, 18, 11, 3, p.metal)
	p.rect(27, 22, 9, 2, p.dark)
	p.rect(13, 17, 5, 3, p.glow, false)
	p.rect(15, 11, 8, 4, p.dark)


static func wall(p: Canvas) -> void:
	for i in 3:
		var x := 5.0 + i * 10.5
		p.poly([Vector2(x, 12), Vector2(x + 9, 9), Vector2(x + 9, 33), Vector2(x, 35)], p.metal)
		p.rect(x + 2, 15, 5, 1.5, p.glow, false)
	p.rect(3, 35, 34, 2.5, p.dark)


static func dome(p: Canvas, with_person: bool) -> void:
	if with_person:
		Parts.person(p, 20, 13, p.dark)
	p.c.draw_arc(p.pt(Vector2(20, 32)), 16 * p.scale, PI, TAU, 24, p.glow, p.stroke(2.5), true)
	p.c.draw_arc(p.pt(Vector2(20, 32)), 12 * p.scale, PI + 0.3, TAU - 0.3, 20, Color(p.glow, p.glow.a * 0.5), p.stroke(1.5), true)
	p.rect(3, 32, 34, 3, p.metal)
	if not with_person:
		p.rect(18, 18, 4, 14, p.metal)
		p.circle(20, 17, 3, p.glow)


static func cloak(p: Canvas, id: String) -> void:
	# Silhouette effacée : contour en pointillés, corps à demi transparent.
	var ghost := Color(p.metal, p.metal.a * 0.35)
	Parts.person(p, 20, 6, ghost)
	for i in 8:
		var a := -PI / 2.0 + i * TAU / 8.0
		var pos := Vector2(20, 21) + Vector2(cos(a), sin(a)) * 15.0
		p.circle(pos.x, pos.y, 1.3, p.glow)
	if id == "evasion_cloak":
		for i in 3:
			p.rect(2, 16 + i * 5, 6 - i, 1.5, p.glow, false)  # traits de vitesse
	elif id == "concealment_cloak":
		p.rect(15, 9, 10, 2.5, p.glow, false)  # visière


static func strike(p: Canvas, id: String) -> void:
	var targets: Array[Vector2] = [Vector2(20, 28)]
	var radius := 8.0
	if id == "orbital_barrage":
		targets = [Vector2(11, 30), Vector2(29, 30), Vector2(20, 24)]
		radius = 5.0
	elif id == "orbital_bombardment":
		radius = 11.0
	for t in targets:
		p.c.draw_arc(p.pt(t), radius * p.scale, 0.0, TAU, 24, p.glow, p.stroke(1.5), true)
		p.rect(t.x - 0.75, t.y - radius - 2, 1.5, 4, p.glow, false)
		p.rect(t.x - 0.75, t.y + radius - 2, 1.5, 4, p.glow, false)
	# Projectile(s) qui tombent.
	for t in targets:
		p.poly([Vector2(t.x - 2.5, 3), Vector2(t.x + 2.5, 3), Vector2(t.x + 2.5, t.y - radius - 6), Vector2(t.x, t.y - radius - 2), Vector2(t.x - 2.5, t.y - radius - 6)], p.metal)

