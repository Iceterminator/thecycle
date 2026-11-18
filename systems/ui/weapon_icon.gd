class_name WeaponIcon
extends Control
## Visuel d'arme du HUD et des menus, dessiné en code et propre à chaque arme : les pièces
## sont choisies d'après ses données (type, lunette selon le zoom, chargeur selon la
## capacité, canon selon la portée, bobines pour les armes à énergie, plombs = canon large…),
## avec quelques variantes tirées de son id (crosse, évents). Ombrage simple : métal, pièces
## sombres, reflet, contour, et un liseré de la couleur `accent` (faction).
## Si l'arme a une vraie image (WeaponData.hud_icon), elle est affichée à la place.
## Repère de dessin : 100 × 40, canon vers la droite.

var weapon: WeaponData:
	set(value):
		weapon = value
		queue_redraw()
## Couleur principale (métal). L'alpha règle la visibilité de tout le dessin.
var tint: Color = Color.WHITE:
	set(value):
		tint = value
		queue_redraw()
## Liseré de faction (alpha 0 = aucun).
var accent: Color = Color(0, 0, 0, 0):
	set(value):
		accent = value
		queue_redraw()

var _scale: float = 1.0
var _origin: Vector2 = Vector2.ZERO
var _metal: Color
var _dark: Color
var _light: Color
var _line: Color


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if weapon == null:
		return
	if weapon.hud_icon:
		var tex_size := weapon.hud_icon.get_size()
		var fit := minf(size.x / tex_size.x, size.y / tex_size.y)
		draw_texture_rect(weapon.hud_icon, Rect2((size - tex_size * fit) / 2.0, tex_size * fit), false, tint)
		return
	_scale = minf(size.x / 100.0, size.y / 40.0)
	_origin = (size - Vector2(100, 40) * _scale) / 2.0
	_metal = tint
	_dark = Color(tint.r * 0.42, tint.g * 0.42, tint.b * 0.45, tint.a)
	_light = Color(minf(tint.r * 1.25 + 0.15, 1.0), minf(tint.g * 1.25 + 0.15, 1.0), minf(tint.b * 1.25 + 0.15, 1.0), tint.a)
	_line = Color(0, 0, 0, 0.6 * tint.a)
	if weapon.gadget != WeaponData.GadgetKind.NONE:
		_draw_gadget()
		return
	match weapon.type:
		WeaponData.WeaponType.PISTOL:
			_draw_pistol()
		WeaponData.WeaponType.MISSILE_LAUNCHER, WeaponData.WeaponType.HEAVY:
			_draw_launcher()
		_:
			_draw_long_gun()


# =========================================================================
# Armes longues (PM, fusils, pompes, mitrailleuses)
# =========================================================================

func _draw_long_gun() -> void:
	var w := weapon
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
			_poly([Vector2(2, ry + 1), Vector2(rx, ry), Vector2(rx, ry + rh - 1), Vector2(10, ry + rh + 2), Vector2(3, ry + rh + 6)], _metal)
			_rect(2, ry + 1, 2.5, rh + 4, _dark)
		"thumbhole":
			_poly([Vector2(2, ry), Vector2(rx, ry), Vector2(rx, ry + rh), Vector2(4, ry + rh + 7)], _metal)
			_poly([Vector2(9, ry + 3), Vector2(rx - 3, ry + 3), Vector2(rx - 3, ry + rh - 2), Vector2(11, ry + rh)], _dark)
		"skeleton":
			_rect(4, ry + 1, rx - 4, 2.5, _metal)
			_rect(4, ry + rh - 1, rx - 4, 2.5, _metal)
			_rect(2, ry, 3, rh + 3, _dark)
		"fold":
			_rect(8, ry + 2, rx - 8, 2.5, _dark)
			_rect(6, ry, 3, rh - 1, _metal)

	# Chargeur (derrière la poignée avant).
	var mx := rx + rl * 0.55
	match mag:
		"straight":
			_rect(mx, ry + rh - 1, 6, 8.0 + minf(w.magazine / 4.0, 10.0), _dark)
		"curved":
			_poly([Vector2(mx, ry + rh - 1), Vector2(mx + 7, ry + rh - 1), Vector2(mx + 11, ry + rh + 12), Vector2(mx + 4, ry + rh + 14)], _dark)
		"box":
			_rect(mx - 1, ry + rh - 1, 9, 8, _dark)
		"drum":
			_circle(mx + 4, ry + rh + 6, 7.0, _dark)
			_circle(mx + 4, ry + rh + 6, 2.5, _metal)
		"tube":
			_rect(end, by + bore + 0.5, barrel * 0.7, 3, _dark)

	# Poignée et pontet.
	var gx := rx + 7.0
	_poly([Vector2(gx, ry + rh - 1), Vector2(gx + 8, ry + rh - 1), Vector2(gx + 5, ry + rh + 12), Vector2(gx - 3, ry + rh + 12)], _metal)
	draw_arc(_pt(Vector2(gx + 12, ry + rh)), 4.0 * _scale, 0.0, PI, 10, _dark, maxf(1.2 * _scale, 1.0))

	# Boîtier, reflet, fenêtre d'éjection, liseré de faction.
	_rect(rx, ry, rl, rh, _metal)
	_rect(rx + 1, ry + 0.6, rl - 2, 1.4, _light, false)
	_rect(rx + rl * 0.25, ry + 2.5, rl * 0.2, 2.5, _dark, false)
	if accent.a > 0.0:
		_rect(rx + 2, ry + rh - 3, rl * 0.45, 1.6, accent, false)

	# Garde-main avec évents, canon, bouche.
	var hg := minf(barrel * 0.6, 18.0)
	_rect(end, ry + 1, hg, rh - 3, _metal)
	var vents := 2 + seed % 3
	for i in vents:
		_rect(end + 3 + i * (hg - 4) / vents, ry + 3, 1.6, rh - 7, _dark, false)
	# Poignée avant sur certaines armes (variante tirée de l'id).
	if (seed / 3) % 2 == 1 and w.type in [WeaponData.WeaponType.SMG, WeaponData.WeaponType.ASSAULT_RIFLE]:
		_poly([Vector2(end + hg - 7, ry + rh - 2), Vector2(end + hg - 2, ry + rh - 2), Vector2(end + hg - 3, ry + rh + 7), Vector2(end + hg - 7, ry + rh + 7)], _dark)
	_rect(end + hg, by, barrel - hg, bore, _metal)
	_rect(end + hg, by, barrel - hg, 0.8, _light, false)
	if shotgun:
		_rect(end + barrel * 0.3, by + bore + 0.2, 10, 4, _metal)  # pompe
		_rect(muzzle - 3, by - 0.8, 3, bore + 1.6, _dark)
	elif explosive:
		_rect(muzzle - 4, by - 1.5, 4, bore + 3, _dark)
	else:
		_rect(muzzle - 4, by - 0.8, 4, bore + 1.6, _dark)  # frein de bouche
	# Énergie : bobines le long du canon.
	if energy:
		var coil := accent if accent.a > 0.0 else _light
		for i in 3:
			_rect(end + hg + 2 + i * (barrel - hg - 8) / 3.0, by - 1.2, 2, bore + 2.4, coil)

	# Visée.
	if long_scope:
		_rect(rx + 4, ry - 7, 28, 5, _dark)
		_rect(rx + 2, ry - 8, 4, 7, _metal)
		_rect(rx + 30, ry - 8.5, 5, 8, _metal)
		_rect(rx + 10, ry - 2, 3, 2, _dark, false)
		_rect(rx + 24, ry - 2, 3, 2, _dark, false)
		_rect(rx + 31, ry - 7.5, 1.5, 6, _light, false)
	elif dot:
		_rect(rx + rl * 0.35, ry - 6, 11, 6, _dark)
		_rect(rx + rl * 0.35 + 8, ry - 5, 2, 4, accent if accent.a > 0.0 else _light, false)
	else:
		_rect(rx + 2, ry - 2.5, 3, 2.5, _dark)
		_rect(muzzle - 7, by - 3, 2, 3, _dark)
	if handle:
		_rect(rx + 10, ry - 6, 16, 2.5, _metal)
		_rect(rx + 10, ry - 4, 2.5, 4, _metal)
		_rect(rx + 23.5, ry - 4, 2.5, 4, _metal)
	if bipod:
		var bx := muzzle - barrel * 0.45
		draw_line(_pt(Vector2(bx, by + bore)), _pt(Vector2(bx - 5, by + bore + 13)), _dark, maxf(1.6 * _scale, 1.0))
		draw_line(_pt(Vector2(bx, by + bore)), _pt(Vector2(bx + 4, by + bore + 13)), _dark, maxf(1.6 * _scale, 1.0))


# =========================================================================
# Pistolets, lanceurs, gadgets
# =========================================================================

func _draw_pistol() -> void:
	var w := weapon
	var shotgun := w.pellets > 1
	var energy := w.fire_mode in [WeaponData.FireMode.BURST, WeaponData.FireMode.CHARGE, WeaponData.FireMode.BEAM]
	var length := 40.0 if not shotgun else 44.0
	var x := 28.0
	# Poignée (inclinée) avec chargeur, pontet.
	_poly([Vector2(x + 4, 20), Vector2(x + 15, 20), Vector2(x + 11, 36), Vector2(x, 36)], _metal)
	_rect(x + 3, 33, 9, 3, _dark)
	draw_arc(_pt(Vector2(x + 19, 21)), 4.0 * _scale, 0.0, PI, 10, _dark, maxf(1.2 * _scale, 1.0))
	# Carcasse, culasse, reflet.
	_rect(x, 17, length - 6, 5, _dark)
	_rect(x, 10, length, 8, _metal)
	_rect(x + 1, 10.6, length - 2, 1.4, _light, false)
	for i in 4:
		_rect(x + 3 + i * 2.2, 12.5, 1, 4, _dark, false)  # stries
	if shotgun:
		_rect(x + length, 9, 6, 10, _dark)
		_circle(x + length + 6, 12, 1.6, _metal)
		_circle(x + length + 6, 16, 1.6, _metal)
	else:
		_rect(x + length, 12, 4, 4, _dark)
	if energy:
		var coil := accent if accent.a > 0.0 else _light
		_rect(x + length * 0.55, 9, 2, 10, coil)
		_rect(x + length * 0.7, 9, 2, 10, coil)
	elif accent.a > 0.0:
		_rect(x + 2, 16, length * 0.4, 1.4, accent, false)
	_rect(x + 2, 8.5, 3, 1.5, _dark)
	_rect(x + length - 4, 8.5, 2, 1.5, _dark)


func _draw_launcher() -> void:
	var heavy := weapon.type == WeaponData.WeaponType.HEAVY
	_rect(6, 10, 84, 12, _metal)
	_rect(7, 10.6, 82, 1.6, _light, false)
	for i in 3:
		_rect(22 + i * 22, 9, 3, 14, _dark)  # bagues
	_rect(88, 8, 8, 16, _dark)   # bouche
	_rect(2, 11, 5, 10, _dark)    # évent arrière
	_poly([Vector2(36, 22), Vector2(45, 22), Vector2(42, 34), Vector2(33, 34)], _metal)
	_poly([Vector2(58, 22), Vector2(65, 22), Vector2(64, 31), Vector2(57, 31)], _metal)
	_rect(44, 3, 12, 7, _dark)
	_rect(52, 4, 2, 5, accent if accent.a > 0.0 else _light, false)
	if heavy:
		_circle(30, 28, 6.0, _dark)  # barillet
		_circle(30, 28, 2.0, _metal)
	if accent.a > 0.0:
		_rect(10, 19, 30, 1.6, accent, false)


func _draw_gadget() -> void:
	match weapon.gadget:
		WeaponData.GadgetKind.FRAG_GRENADE:
			_circle(50, 24, 12.0, _metal)
			for i in 3:
				_rect(40, 18 + i * 5, 20, 1.2, _dark, false)
			_rect(45, 6, 10, 7, _dark)
			_poly([Vector2(55, 7), Vector2(66, 9), Vector2(66, 12), Vector2(55, 10)], _metal)
			draw_arc(_pt(Vector2(42, 8)), 3.0 * _scale, 0.0, TAU, 12, _light, maxf(1.2 * _scale, 1.0))
			if accent.a > 0.0:
				_rect(41, 28, 18, 2, accent, false)
		WeaponData.GadgetKind.HEAL_BEAM:
			_poly([Vector2(34, 22), Vector2(44, 22), Vector2(41, 34), Vector2(31, 34)], _metal)
			_rect(24, 12, 46, 10, _metal)
			_rect(25, 12.6, 44, 1.4, _light, false)
			_circle(36, 17, 3.5, _dark)
			_rect(70, 14, 12, 6, _dark)
			_rect(82, 12.5, 4, 9, _metal)
			var cross := accent if accent.a > 0.0 else Color(0.5, 1.0, 0.6, tint.a)
			_rect(88, 15.5, 9, 3, cross, false)
			_rect(91, 12.5, 3, 9, cross, false)
		WeaponData.GadgetKind.RECALL:
			_rect(36, 32, 28, 4, _dark)
			_poly([Vector2(50, 6), Vector2(60, 32), Vector2(40, 32)], _metal)
			_poly([Vector2(50, 6), Vector2(54, 32), Vector2(46, 32)], _light)
			_circle(50, 6, 2.5, accent if accent.a > 0.0 else _light)
			for r in [10.0, 16.0]:
				draw_arc(_pt(Vector2(50, 6)), r * _scale, 0.3, PI - 0.3, 16, Color(_light, _light.a * 0.6), maxf(1.2 * _scale, 1.0))


# =========================================================================
# Primitives (repère 100 × 40), avec contour
# =========================================================================

func _pt(p: Vector2) -> Vector2:
	return _origin + p * _scale


func _rect(x: float, y: float, w: float, h: float, color: Color, outline: bool = true) -> void:
	var rect := Rect2(_pt(Vector2(x, y)), Vector2(w, h) * _scale)
	draw_rect(rect, color)
	if outline:
		draw_rect(rect, _line, false, maxf(0.8 * _scale, 1.0))


func _poly(points: Array[Vector2], color: Color) -> void:
	var out := PackedVector2Array()
	for p in points:
		out.append(_pt(p))
	draw_colored_polygon(out, color)
	out.append(out[0])
	draw_polyline(out, _line, maxf(0.8 * _scale, 1.0), true)


func _circle(x: float, y: float, r: float, color: Color) -> void:
	draw_circle(_pt(Vector2(x, y)), r * _scale, color)
	draw_arc(_pt(Vector2(x, y)), r * _scale, 0.0, TAU, 24, _line, maxf(0.8 * _scale, 1.0), true)
