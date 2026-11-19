extends RefCounted
## Dessin des pistolets, lanceurs et gadgets de WeaponIcon.
## Repère 100 × 40 ; `p` fournit palette et primitives.

const Canvas := preload("res://systems/ui/weapon_icon_canvas.gd")


static func draw_pistol(p: Canvas, w: WeaponData) -> void:
	var shotgun := w.pellets > 1
	var energy := w.fire_mode in [WeaponData.FireMode.BURST, WeaponData.FireMode.CHARGE, WeaponData.FireMode.BEAM]
	var length := 40.0 if not shotgun else 44.0
	var x := 28.0
	# Poignée (inclinée) avec chargeur, pontet.
	p.poly([Vector2(x + 4, 20), Vector2(x + 15, 20), Vector2(x + 11, 36), Vector2(x, 36)], p.metal)
	p.rect(x + 3, 33, 9, 3, p.dark)
	p.c.draw_arc(p.pt(Vector2(x + 19, 21)), 4.0 * p.scale, 0.0, PI, 10, p.dark, p.stroke(1.2))
	# Carcasse, culasse, reflet.
	p.rect(x, 17, length - 6, 5, p.dark)
	p.rect(x, 10, length, 8, p.metal)
	p.rect(x + 1, 10.6, length - 2, 1.4, p.light, false)
	for i in 4:
		p.rect(x + 3 + i * 2.2, 12.5, 1, 4, p.dark, false)  # stries
	if shotgun:
		p.rect(x + length, 9, 6, 10, p.dark)
		p.circle(x + length + 6, 12, 1.6, p.metal)
		p.circle(x + length + 6, 16, 1.6, p.metal)
	else:
		p.rect(x + length, 12, 4, 4, p.dark)
	if energy:
		var coil := p.accent if p.accent.a > 0.0 else p.light
		p.rect(x + length * 0.55, 9, 2, 10, coil)
		p.rect(x + length * 0.7, 9, 2, 10, coil)
	elif p.accent.a > 0.0:
		p.rect(x + 2, 16, length * 0.4, 1.4, p.accent, false)
	p.rect(x + 2, 8.5, 3, 1.5, p.dark)
	p.rect(x + length - 4, 8.5, 2, 1.5, p.dark)


static func draw_launcher(p: Canvas, w: WeaponData) -> void:
	var heavy := w.type == WeaponData.WeaponType.HEAVY
	p.rect(6, 10, 84, 12, p.metal)
	p.rect(7, 10.6, 82, 1.6, p.light, false)
	for i in 3:
		p.rect(22 + i * 22, 9, 3, 14, p.dark)  # bagues
	p.rect(88, 8, 8, 16, p.dark)   # bouche
	p.rect(2, 11, 5, 10, p.dark)    # évent arrière
	p.poly([Vector2(36, 22), Vector2(45, 22), Vector2(42, 34), Vector2(33, 34)], p.metal)
	p.poly([Vector2(58, 22), Vector2(65, 22), Vector2(64, 31), Vector2(57, 31)], p.metal)
	p.rect(44, 3, 12, 7, p.dark)
	p.rect(52, 4, 2, 5, p.accent if p.accent.a > 0.0 else p.light, false)
	if heavy:
		p.circle(30, 28, 6.0, p.dark)  # barillet
		p.circle(30, 28, 2.0, p.metal)
	if p.accent.a > 0.0:
		p.rect(10, 19, 30, 1.6, p.accent, false)


static func draw_gadget(p: Canvas, w: WeaponData) -> void:
	match w.gadget:
		WeaponData.GadgetKind.FRAG_GRENADE:
			p.circle(50, 24, 12.0, p.metal)
			for i in 3:
				p.rect(40, 18 + i * 5, 20, 1.2, p.dark, false)
			p.rect(45, 6, 10, 7, p.dark)
			p.poly([Vector2(55, 7), Vector2(66, 9), Vector2(66, 12), Vector2(55, 10)], p.metal)
			p.c.draw_arc(p.pt(Vector2(42, 8)), 3.0 * p.scale, 0.0, TAU, 12, p.light, p.stroke(1.2))
			if p.accent.a > 0.0:
				p.rect(41, 28, 18, 2, p.accent, false)
		WeaponData.GadgetKind.HEAL_BEAM:
			p.poly([Vector2(34, 22), Vector2(44, 22), Vector2(41, 34), Vector2(31, 34)], p.metal)
			p.rect(24, 12, 46, 10, p.metal)
			p.rect(25, 12.6, 44, 1.4, p.light, false)
			p.circle(36, 17, 3.5, p.dark)
			p.rect(70, 14, 12, 6, p.dark)
			p.rect(82, 12.5, 4, 9, p.metal)
			var cross := p.accent if p.accent.a > 0.0 else Color(0.5, 1.0, 0.6, p.tint.a)
			p.rect(88, 15.5, 9, 3, cross, false)
			p.rect(91, 12.5, 3, 9, cross, false)
		WeaponData.GadgetKind.RECALL:
			p.rect(36, 32, 28, 4, p.dark)
			p.poly([Vector2(50, 6), Vector2(60, 32), Vector2(40, 32)], p.metal)
			p.poly([Vector2(50, 6), Vector2(54, 32), Vector2(46, 32)], p.light)
			p.circle(50, 6, 2.5, p.accent if p.accent.a > 0.0 else p.light)
			for r in [10.0, 16.0]:
				p.c.draw_arc(p.pt(Vector2(50, 6)), r * p.scale, 0.3, PI - 0.3, 16, Color(p.light, p.light.a * 0.6), p.stroke(1.2))
