class_name KitIcon
extends Control
## Visuel de kit (menus) : silhouette de combinaison dessinée en code, plus ou moins massive
## selon ses PV, avec sa capacité de mouvement (jetpack, propulseurs, esquive, super saut).
## Même style que WeaponIcon. Si le kit a une vraie image (KitData.hud_icon), elle est
## affichée à la place. Repère de dessin : 40 × 48.

var kit: KitData:
	set(value):
		kit = value
		queue_redraw()
var tint: Color = Color.WHITE:
	set(value):
		tint = value
		queue_redraw()
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
var _glow: Color


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if kit == null:
		return
	if kit.hud_icon:
		var tex_size := kit.hud_icon.get_size()
		var fit := minf(size.x / tex_size.x, size.y / tex_size.y)
		draw_texture_rect(kit.hud_icon, Rect2((size - tex_size * fit) / 2.0, tex_size * fit), false, tint)
		return
	_scale = minf(size.x / 40.0, size.y / 48.0)
	_origin = (size - Vector2(40, 48) * _scale) / 2.0
	_metal = tint
	_dark = Color(tint.r * 0.42, tint.g * 0.42, tint.b * 0.45, tint.a)
	_light = Color(minf(tint.r * 1.25 + 0.15, 1.0), minf(tint.g * 1.25 + 0.15, 1.0), minf(tint.b * 1.25 + 0.15, 1.0), tint.a)
	_line = Color(0, 0, 0, 0.6 * tint.a)
	_glow = accent if accent.a > 0.0 else Color(0.45, 0.95, 0.75, tint.a)
	var health := kit.health if kit.health > 0.0 else Config.KIT_DEFAULT_HEALTH
	var bulk := clampf(health / 500.0, 0.8, 1.3)  # 400 PV = fin, 600 PV = massif
	var mobility := kit.mobility_type

	# Derrière le corps : jetpack ou propulseurs dorsaux.
	if mobility == KitData.MobilityType.JETPACK:
		# Réservoirs qui dépassent au-dessus des épaules, flammes sous le dos.
		_rect(20 - 7.5 * bulk - 1, 2, 5, 22, _dark)
		_rect(20 + 7.5 * bulk - 4, 2, 5, 22, _dark)
		_rect(20 - 7.5 * bulk, 3, 3, 2, _glow, false)
		_rect(20 + 7.5 * bulk - 3, 3, 3, 2, _glow, false)
		_flame(20 - 7.5 * bulk + 1.5, 24, 7)
		_flame(20 + 7.5 * bulk - 1.5, 24, 7)
	elif mobility == KitData.MobilityType.DASH:
		for i in 3:
			_rect(1, 16 + i * 5, 8 - i * 2, 1.5, _glow, false)

	var hw := 7.0 * bulk  # demi-largeur des épaules
	# Jambes.
	_poly([Vector2(20 - hw * 0.8, 29), Vector2(19, 29), Vector2(18, 45), Vector2(20 - hw * 0.8 - 1, 45)], _metal)
	_poly([Vector2(21, 29), Vector2(20 + hw * 0.8, 29), Vector2(20 + hw * 0.8 + 1, 45), Vector2(22, 45)], _metal)
	_rect(20 - hw * 0.8 - 2, 44, hw * 0.8 + 1, 3, _dark)
	_rect(21, 44, hw * 0.8 + 1, 3, _dark)
	# Bras (plus gros poings pour le super saut / coup de poing).
	var fist := 4.5 if mobility == KitData.MobilityType.SUPER_JUMP else 2.5
	_poly([Vector2(20 - hw - 4, 13), Vector2(20 - hw, 13), Vector2(20 - hw + 1, 26), Vector2(20 - hw - 3, 26)], _metal)
	_poly([Vector2(20 + hw, 13), Vector2(20 + hw + 4, 13), Vector2(20 + hw + 3, 26), Vector2(20 + hw - 1, 26)], _metal)
	_circle(20 - hw - 1, 27, fist, _dark)
	_circle(20 + hw + 1, 27, fist, _dark)
	# Torse, plastron, ceinture.
	_poly([Vector2(20 - hw, 12), Vector2(20 + hw, 12), Vector2(20 + hw * 0.8, 30), Vector2(20 - hw * 0.8, 30)], _metal)
	_poly([Vector2(20 - hw * 0.6, 14), Vector2(20 + hw * 0.6, 14), Vector2(20 + hw * 0.45, 23), Vector2(20 - hw * 0.45, 23)], _dark)
	_rect(20 - hw * 0.8, 27, hw * 1.6, 2.5, _dark, false)
	if accent.a > 0.0:
		_rect(20 - hw * 0.5, 17.5, hw, 1.6, accent, false)
	# Casque et visière.
	_circle(20, 7, 5.5, _metal)
	_rect(16.5, 5.5, 7, 2.5, _glow, false)
	_rect(15.5, 3, 9, 1.2, _light, false)

	match mobility:
		KitData.MobilityType.JETBOOSTERS:
			_rect(20 - hw * 0.8 - 2, 38, 3, 4, _dark)
			_rect(20 + hw * 0.8 - 1, 38, 3, 4, _dark)
			_flame(20 - hw * 0.8 - 0.5, 47, 3)
			_flame(20 + hw * 0.8 + 0.5, 47, 3)
		KitData.MobilityType.SUPER_JUMP:
			_poly([Vector2(36, 2), Vector2(40, 8), Vector2(37.5, 8), Vector2(37.5, 14), Vector2(34.5, 14), Vector2(34.5, 8), Vector2(32, 8)], _glow)
		KitData.MobilityType.NONE:
			# Kit à implants : lignes lumineuses sur la combinaison.
			_rect(20 - hw + 1, 20, 1.2, 8, _glow, false)
			_rect(20 + hw - 2.2, 20, 1.2, 8, _glow, false)


func _flame(x: float, y: float, length: float) -> void:
	_poly([Vector2(x - 2, y), Vector2(x + 2, y), Vector2(x, y + length)], Color(1.0, 0.65, 0.25, tint.a))
	_poly([Vector2(x - 1, y), Vector2(x + 1, y), Vector2(x, y + length * 0.6)], Color(1.0, 0.95, 0.7, tint.a))


func _pt(p: Vector2) -> Vector2:
	return _origin + p * _scale


func _rect(x: float, y: float, w: float, h: float, color: Color, outline: bool = true) -> void:
	var rect := Rect2(_pt(Vector2(x, y)), Vector2(w, h) * _scale)
	draw_rect(rect, color)
	if outline:
		draw_rect(rect, _line, false, maxf(0.6 * _scale, 1.0))


func _poly(points: Array[Vector2], color: Color) -> void:
	var out := PackedVector2Array()
	for p in points:
		out.append(_pt(p))
	draw_colored_polygon(out, color)
	out.append(out[0])
	draw_polyline(out, _line, maxf(0.6 * _scale, 1.0), true)


func _circle(x: float, y: float, r: float, color: Color) -> void:
	draw_circle(_pt(Vector2(x, y)), r * _scale, color)
	draw_arc(_pt(Vector2(x, y)), r * _scale, 0.0, TAU, 24, _line, maxf(0.6 * _scale, 1.0), true)
