extends RefCounted
## Dessin des armes longues (PM, fusils, pompes, mitrailleuses) de WeaponIcon.
## Repère 100 × 40, canon vers la droite ; `p` fournit palette et primitives.

const Canvas := preload("res://systems/ui/weapon_icon_canvas.gd")


static func draw(p: Canvas, w: WeaponData) -> void:
	var seed := absi(hash(String(w.id)))
	var range_m := w.falloff_end_m if w.falloff_end_m > 0.0 else (w.max_range_m if w.max_range_m > 0.0 else 60.0)
	var reach := clampf(range_m / 150.0, 0.0, 1.0)
	var shotgun := w.pellets > 1
	var explosive := w.projectile_type == WeaponData.ProjectileType.EXPLOSIVE_PROJECTILE
	var energy := w.fire_mode in [WeaponData.FireMode.CHARGE, WeaponData.FireMode.CHARGE_BURST, WeaponData.FireMode.BEAM]
	var long_scope := w.type == WeaponData.WeaponType.SNIPER_RIFLE or w.scope_zoom >= 3.0
	var dot := not long_scope and w.scope_zoom > 1.0

	# Proportions selon le type.
	var rx := 20.0      # début du boîtier
	var rl := 38.0      # longueur du boîtier
	var rh := 10.0      # hauteur du boîtier
	var barrel := 20.0 + reach * 12.0
	var mag := "curved"
	var stock: String = ["solid", "skeleton", "solid"][seed % 3]
	var bipod := false
	var handle := false
	match w.type:
		WeaponData.WeaponType.SMG:
			rx = 24.0
			rl = 32.0
			barrel = 10.0 + reach * 10.0
			mag = "straight"
			stock = ["fold", "skeleton"][seed % 2]
		WeaponData.WeaponType.BATTLE_RIFLE:
			rl = 40.0
			mag = "box"
		WeaponData.WeaponType.SNIPER_RIFLE:
			rx = 18.0
			rl = 34.0
			rh = 9.0
			barrel = 36.0 + reach * 8.0
			mag = "box"
			stock = ["thumbhole", "solid"][seed % 2]
			bipod = true
		WeaponData.WeaponType.SHOTGUN:
			rl = 30.0
			rh = 12.0
			barrel = 32.0
			mag = "tube"
		WeaponData.WeaponType.LMG:
			rx = 18.0
			rl = 42.0
			rh = 13.0
			barrel = 26.0
			mag = "drum" if w.magazine >= 60 else "box"
			handle = true
			bipod = seed % 2 == 0
	if w.magazine >= 60 and mag != "drum":
		mag = "drum"
	if shotgun:
		mag = "tube"
	barrel = minf(barrel, 97.0 - (rx + rl))
	var ry := 12.0
	var end := rx + rl
	var muzzle := end + barrel
	var bore := 4.5 if (shotgun or explosive) else 3.0
	var by := ry + 2.5  # haut du canon

	# Crosse.
	match stock:
		"solid":
			p.poly([Vector2(2, ry + 1), Vector2(rx, ry), Vector2(rx, ry + rh - 1), Vector2(10, ry + rh + 2), Vector2(3, ry + rh + 6)], p.metal)
			p.rect(2, ry + 1, 2.5, rh + 4, p.dark)
		"thumbhole":
			p.poly([Vector2(2, ry), Vector2(rx, ry), Vector2(rx, ry + rh), Vector2(4, ry + rh + 7)], p.metal)
			p.poly([Vector2(9, ry + 3), Vector2(rx - 3, ry + 3), Vector2(rx - 3, ry + rh - 2), Vector2(11, ry + rh)], p.dark)
		"skeleton":
			p.rect(4, ry + 1, rx - 4, 2.5, p.metal)
			p.rect(4, ry + rh - 1, rx - 4, 2.5, p.metal)
			p.rect(2, ry, 3, rh + 3, p.dark)
		"fold":
			p.rect(8, ry + 2, rx - 8, 2.5, p.dark)
			p.rect(6, ry, 3, rh - 1, p.metal)

	# Chargeur (derrière la poignée avant).
	var mx := rx + rl * 0.55
	match mag:
		"straight":
			p.rect(mx, ry + rh - 1, 6, 8.0 + minf(w.magazine / 4.0, 10.0), p.dark)
		"curved":
			p.poly([Vector2(mx, ry + rh - 1), Vector2(mx + 7, ry + rh - 1), Vector2(mx + 11, ry + rh + 12), Vector2(mx + 4, ry + rh + 14)], p.dark)
		"box":
			p.rect(mx - 1, ry + rh - 1, 9, 8, p.dark)
		"drum":
			p.circle(mx + 4, ry + rh + 6, 7.0, p.dark)
			p.circle(mx + 4, ry + rh + 6, 2.5, p.metal)
		"tube":
			p.rect(end, by + bore + 0.5, barrel * 0.7, 3, p.dark)

	# Poignée et pontet.
	var gx := rx + 7.0
	p.poly([Vector2(gx, ry + rh - 1), Vector2(gx + 8, ry + rh - 1), Vector2(gx + 5, ry + rh + 12), Vector2(gx - 3, ry + rh + 12)], p.metal)
	p.c.draw_arc(p.pt(Vector2(gx + 12, ry + rh)), 4.0 * p.scale, 0.0, PI, 10, p.dark, p.stroke(1.2))

	# Boîtier, reflet, fenêtre d'éjection, liseré de faction.
	p.rect(rx, ry, rl, rh, p.metal)
	p.rect(rx + 1, ry + 0.6, rl - 2, 1.4, p.light, false)
	p.rect(rx + rl * 0.25, ry + 2.5, rl * 0.2, 2.5, p.dark, false)
	if p.accent.a > 0.0:
		p.rect(rx + 2, ry + rh - 3, rl * 0.45, 1.6, p.accent, false)

	# Garde-main avec évents, canon, bouche.
	var hg := minf(barrel * 0.6, 18.0)
	p.rect(end, ry + 1, hg, rh - 3, p.metal)
	var vents := 2 + seed % 3
	for i in vents:
		p.rect(end + 3 + i * (hg - 4) / vents, ry + 3, 1.6, rh - 7, p.dark, false)
	# Poignée avant sur certaines armes (variante tirée de l'id).
	if (seed / 3) % 2 == 1 and w.type in [WeaponData.WeaponType.SMG, WeaponData.WeaponType.ASSAULT_RIFLE]:
		p.poly([Vector2(end + hg - 7, ry + rh - 2), Vector2(end + hg - 2, ry + rh - 2), Vector2(end + hg - 3, ry + rh + 7), Vector2(end + hg - 7, ry + rh + 7)], p.dark)
	p.rect(end + hg, by, barrel - hg, bore, p.metal)
	p.rect(end + hg, by, barrel - hg, 0.8, p.light, false)
	if shotgun:
		p.rect(end + barrel * 0.3, by + bore + 0.2, 10, 4, p.metal)  # pompe
		p.rect(muzzle - 3, by - 0.8, 3, bore + 1.6, p.dark)
	elif explosive:
		p.rect(muzzle - 4, by - 1.5, 4, bore + 3, p.dark)
	else:
		p.rect(muzzle - 4, by - 0.8, 4, bore + 1.6, p.dark)  # frein de bouche
	# Énergie : bobines le long du canon.
	if energy:
		var coil := p.accent if p.accent.a > 0.0 else p.light
		for i in 3:
			p.rect(end + hg + 2 + i * (barrel - hg - 8) / 3.0, by - 1.2, 2, bore + 2.4, coil)

	# Visée.
	if long_scope:
		p.rect(rx + 4, ry - 7, 28, 5, p.dark)
		p.rect(rx + 2, ry - 8, 4, 7, p.metal)
		p.rect(rx + 30, ry - 8.5, 5, 8, p.metal)
		p.rect(rx + 10, ry - 2, 3, 2, p.dark, false)
		p.rect(rx + 24, ry - 2, 3, 2, p.dark, false)
		p.rect(rx + 31, ry - 7.5, 1.5, 6, p.light, false)
	elif dot:
		p.rect(rx + rl * 0.35, ry - 6, 11, 6, p.dark)
		p.rect(rx + rl * 0.35 + 8, ry - 5, 2, 4, p.accent if p.accent.a > 0.0 else p.light, false)
	else:
		p.rect(rx + 2, ry - 2.5, 3, 2.5, p.dark)
		p.rect(muzzle - 7, by - 3, 2, 3, p.dark)
	if handle:
		p.rect(rx + 10, ry - 6, 16, 2.5, p.metal)
		p.rect(rx + 10, ry - 4, 2.5, 4, p.metal)
		p.rect(rx + 23.5, ry - 4, 2.5, 4, p.metal)
	if bipod:
		var bx := muzzle - barrel * 0.45
		p.c.draw_line(p.pt(Vector2(bx, by + bore)), p.pt(Vector2(bx - 5, by + bore + 13)), p.dark, p.stroke(1.6))
		p.c.draw_line(p.pt(Vector2(bx, by + bore)), p.pt(Vector2(bx + 4, by + bore + 13)), p.dark, p.stroke(1.6))
