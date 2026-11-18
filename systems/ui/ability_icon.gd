class_name AbilityIcon
extends Control
## Visuel de capacité (HUD Q / F, menus), dessiné en code selon sa catégorie, avec des
## variantes selon la capacité (ex. frappe : une cible, plusieurs, ou une grosse zone).
## Même style que WeaponIcon : métal `tint`, pièces sombres, contour, liseré `accent`.
## Si la capacité a une vraie image (AbilityData.hud_icon), elle est affichée à la place.
## Repère de dessin : 40 × 40.

var ability: AbilityData:
	set(value):
		ability = value
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
	if ability == null:
		return
	if ability.hud_icon:
		var tex_size := ability.hud_icon.get_size()
		var fit := minf(size.x / tex_size.x, size.y / tex_size.y)
		draw_texture_rect(ability.hud_icon, Rect2((size - tex_size * fit) / 2.0, tex_size * fit), false, tint)
		return
	_scale = minf(size.x, size.y) / 40.0
	_origin = (size - Vector2(40, 40) * _scale) / 2.0
	_metal = tint
	_dark = Color(tint.r * 0.42, tint.g * 0.42, tint.b * 0.45, tint.a)
	_light = Color(minf(tint.r * 1.25 + 0.15, 1.0), minf(tint.g * 1.25 + 0.15, 1.0), minf(tint.b * 1.25 + 0.15, 1.0), tint.a)
	_line = Color(0, 0, 0, 0.6 * tint.a)
	_glow = accent if accent.a > 0.0 else Color(0.45, 0.95, 0.75, tint.a)
	var id := String(ability.id)
	match ability.category:
		AbilityData.Category.GRENADE:
			_grenade()
		AbilityData.Category.STIM:
			if id == "stand_your_ground":
				_stand()
			else:
				_syringe(id == "adrenaline_shot")
		AbilityData.Category.DEPLOYABLE:
			_turret()
		AbilityData.Category.BARRIER:
			if id == "safeguard":
				_dome(false)
			else:
				_wall()
		AbilityData.Category.CLOAK:
			_cloak(id)
		AbilityData.Category.STRIKE:
			_strike(id)
		AbilityData.Category.FIELD:
			_sphere(id == "triage_sphere")
		AbilityData.Category.MOBILITY:
			_portal()
		AbilityData.Category.SHIELD:
			_dome(true)
		AbilityData.Category.SCANNER:
			_ward()
		AbilityData.Category.TRAP:
			if id == "warp_bomb":
				_warp_bomb()
			else:
				_snare()
		AbilityData.Category.HEAL:
			_aura()


# =========================================================================
# Dessins par catégorie
# =========================================================================

func _grenade() -> void:
	_circle(20, 24, 11, _metal)
	_rect(9, 22, 22, 2, _dark, false)
	_rect(16, 9, 8, 5, _dark)
	_bolt(20, 17, _glow)


func _syringe(adrenaline: bool) -> void:
	draw_set_transform(_pt(Vector2(20, 20)), -PI / 4.0, Vector2(_scale, _scale))
	_local_rect(-13, -4, 20, 8, _metal)
	_local_rect(-10, -2.5, 12, 5, _glow)
	_local_rect(7, -1, 9, 2, _dark)
	_local_rect(-17, -2, 4, 4, _dark)
	_local_rect(-19, -5, 2, 10, _metal)
	draw_set_transform(Vector2.ZERO)
	if adrenaline:
		_bolt(31, 9, _glow)
	else:
		_plus(31, 9, 4, _glow)


func _stand() -> void:
	# Prospecteur ancré au sol : silhouette + chevrons vers le bas.
	_person(20, 6, _metal)
	_rect(6, 34, 28, 3, _dark)
	for i in 2:
		_poly([Vector2(5, 20 + i * 6), Vector2(9, 24 + i * 6), Vector2(5, 28 + i * 6)], _glow)
		_poly([Vector2(35, 20 + i * 6), Vector2(31, 24 + i * 6), Vector2(35, 28 + i * 6)], _glow)


func _turret() -> void:
	draw_line(_pt(Vector2(20, 26)), _pt(Vector2(10, 37)), _dark, maxf(2.0 * _scale, 1.0))
	draw_line(_pt(Vector2(20, 26)), _pt(Vector2(30, 37)), _dark, maxf(2.0 * _scale, 1.0))
	draw_line(_pt(Vector2(20, 26)), _pt(Vector2(20, 37)), _dark, maxf(2.0 * _scale, 1.0))
	_rect(11, 15, 16, 11, _metal)
	_rect(27, 18, 11, 3, _metal)
	_rect(27, 22, 9, 2, _dark)
	_rect(13, 17, 5, 3, _glow, false)
	_rect(15, 11, 8, 4, _dark)


func _wall() -> void:
	for i in 3:
		var x := 5.0 + i * 10.5
		_poly([Vector2(x, 12), Vector2(x + 9, 9), Vector2(x + 9, 33), Vector2(x, 35)], _metal)
		_rect(x + 2, 15, 5, 1.5, _glow, false)
	_rect(3, 35, 34, 2.5, _dark)


func _dome(with_person: bool) -> void:
	if with_person:
		_person(20, 13, _dark)
	draw_arc(_pt(Vector2(20, 32)), 16 * _scale, PI, TAU, 24, _glow, maxf(2.5 * _scale, 1.0), true)
	draw_arc(_pt(Vector2(20, 32)), 12 * _scale, PI + 0.3, TAU - 0.3, 20, Color(_glow, _glow.a * 0.5), maxf(1.5 * _scale, 1.0), true)
	_rect(3, 32, 34, 3, _metal)
	if not with_person:
		_rect(18, 18, 4, 14, _metal)
		_circle(20, 17, 3, _glow)


func _cloak(id: String) -> void:
	# Silhouette effacée : contour en pointillés, corps à demi transparent.
	var ghost := Color(_metal, _metal.a * 0.35)
	_person(20, 6, ghost)
	for i in 8:
		var a := -PI / 2.0 + i * TAU / 8.0
		var p := Vector2(20, 21) + Vector2(cos(a), sin(a)) * 15.0
		_circle(p.x, p.y, 1.3, _glow)
	if id == "evasion_cloak":
		for i in 3:
			_rect(2, 16 + i * 5, 6 - i, 1.5, _glow, false)  # traits de vitesse
	elif id == "concealment_cloak":
		_rect(15, 9, 10, 2.5, _glow, false)  # visière


func _strike(id: String) -> void:
	var targets: Array[Vector2] = [Vector2(20, 28)]
	var radius := 8.0
	if id == "orbital_barrage":
		targets = [Vector2(11, 30), Vector2(29, 30), Vector2(20, 24)]
		radius = 5.0
	elif id == "orbital_bombardment":
		radius = 11.0
	for t in targets:
		draw_arc(_pt(t), radius * _scale, 0.0, TAU, 24, _glow, maxf(1.5 * _scale, 1.0), true)
		_rect(t.x - 0.75, t.y - radius - 2, 1.5, 4, _glow, false)
		_rect(t.x - 0.75, t.y + radius - 2, 1.5, 4, _glow, false)
	# Projectile(s) qui tombent.
	for t in targets:
		_poly([Vector2(t.x - 2.5, 3), Vector2(t.x + 2.5, 3), Vector2(t.x + 2.5, t.y - radius - 6), Vector2(t.x, t.y - radius - 2), Vector2(t.x - 2.5, t.y - radius - 6)], _metal)


func _sphere(triage: bool) -> void:
	_circle(20, 20, 13, _metal)
	draw_arc(_pt(Vector2(20, 20)), 17 * _scale, 0.0, TAU, 28, Color(_glow, _glow.a * 0.7), maxf(1.5 * _scale, 1.0), true)
	_circle(16, 16, 3, _light)
	if triage:
		_plus(20, 21, 6, _glow)
	else:
		_bolt(20, 20, _glow)


func _portal() -> void:
	draw_set_transform(_pt(Vector2(13, 20)), 0.0, Vector2(_scale * 0.45, _scale))
	draw_arc(Vector2.ZERO, 14, 0.0, TAU, 28, _glow, 3.0, true)
	draw_set_transform(_pt(Vector2(31, 20)), 0.0, Vector2(_scale * 0.45, _scale))
	draw_arc(Vector2.ZERO, 14, 0.0, TAU, 28, _metal, 3.0, true)
	draw_set_transform(Vector2.ZERO)
	_rect(16, 18.5, 10, 3, _light, false)
	_poly([Vector2(25, 15), Vector2(30, 20), Vector2(25, 25)], _light)


func _ward() -> void:
	_rect(18, 18, 4, 18, _metal)
	_rect(13, 35, 14, 3, _dark)
	_circle(20, 16, 4, _glow)
	for r in [9.0, 14.0]:
		draw_arc(_pt(Vector2(20, 16)), r * _scale, -PI * 0.85, -PI * 0.15, 16, Color(_glow, _glow.a * 0.8), maxf(1.5 * _scale, 1.0), true)


func _snare() -> void:
	draw_arc(_pt(Vector2(20, 24)), 13 * _scale, 0.0, TAU, 28, _metal, maxf(3.0 * _scale, 1.0), true)
	for i in 10:
		var a := i * TAU / 10.0
		var base := Vector2(20, 24) + Vector2(cos(a), sin(a)) * 11.0
		var tip := Vector2(20, 24) + Vector2(cos(a), sin(a)) * 6.0
		var side := Vector2(-sin(a), cos(a)) * 1.6
		_poly([base + side, tip, base - side], _dark)
	_circle(20, 24, 3, _glow)


func _warp_bomb() -> void:
	_circle(20, 22, 12, _dark)
	for i in 3:
		draw_arc(_pt(Vector2(20, 22)), (4.0 + i * 3.0) * _scale, i * 1.2, i * 1.2 + PI * 1.3, 16, _glow, maxf(1.5 * _scale, 1.0), true)
	_rect(17, 7, 6, 4, _metal)


func _aura() -> void:
	for r in [16.0, 11.0]:
		draw_arc(_pt(Vector2(20, 20)), r * _scale, 0.0, TAU, 28, Color(_glow, _glow.a * (0.5 if r > 12.0 else 0.85)), maxf(2.0 * _scale, 1.0), true)
	_circle(20, 20, 7, _metal)
	_plus(20, 20, 5, _glow)


# =========================================================================
# Petits éléments
# =========================================================================

## Silhouette de prospecteur (tête en (x, y)).
func _person(x: float, y: float, color: Color) -> void:
	_circle(x, y + 3, 3.5, color)
	_poly([Vector2(x - 6, y + 8), Vector2(x + 6, y + 8), Vector2(x + 5, y + 20), Vector2(x - 5, y + 20)], color)
	_poly([Vector2(x - 5, y + 20), Vector2(x - 1, y + 20), Vector2(x - 2, y + 28), Vector2(x - 6, y + 28)], color)
	_poly([Vector2(x + 1, y + 20), Vector2(x + 5, y + 20), Vector2(x + 6, y + 28), Vector2(x + 2, y + 28)], color)


func _bolt(x: float, y: float, color: Color) -> void:
	_poly([Vector2(x + 1, y - 6), Vector2(x - 4, y + 1), Vector2(x, y + 1), Vector2(x - 1, y + 6), Vector2(x + 4, y - 1), Vector2(x, y - 1)], color)


func _plus(x: float, y: float, r: float, color: Color) -> void:
	_rect(x - r, y - r * 0.3, r * 2, r * 0.6, color, false)
	_rect(x - r * 0.3, y - r, r * 0.6, r * 2, color, false)


func _pt(p: Vector2) -> Vector2:
	return _origin + p * _scale


func _rect(x: float, y: float, w: float, h: float, color: Color, outline: bool = true) -> void:
	var rect := Rect2(_pt(Vector2(x, y)), Vector2(w, h) * _scale)
	draw_rect(rect, color)
	if outline:
		draw_rect(rect, _line, false, maxf(0.6 * _scale, 1.0))


## Rectangle dans le repère courant (après draw_set_transform).
func _local_rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)
	draw_rect(Rect2(x, y, w, h), _line, false, 0.6)


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
