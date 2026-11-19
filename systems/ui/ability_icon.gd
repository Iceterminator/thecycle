class_name AbilityIcon
extends Control
## Visuel de capacité (HUD Q / F, menus), dessiné en code selon sa catégorie, avec des
## variantes selon la capacité (ex. frappe : une cible, plusieurs, ou une grosse zone).
## Même style que WeaponIcon : métal `tint`, pièces sombres, contour, liseré `accent`.
## Si la capacité a une vraie image (AbilityData.hud_icon), elle est affichée à la place.
## Repère de dessin : 40 × 40.
const Canvas := preload("res://systems/ui/weapon_icon_canvas.gd")
const Shapes := preload("res://systems/ui/ability_icon_shapes.gd")
const ShapesMore := preload("res://systems/ui/ability_icon_shapes_more.gd")

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

var _canvas: Canvas


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_canvas = Canvas.new(self, 0.6)


func _draw() -> void:
	if ability == null:
		return
	if ability.hud_icon:
		var tex_size := ability.hud_icon.get_size()
		var fit := minf(size.x / tex_size.x, size.y / tex_size.y)
		draw_texture_rect(ability.hud_icon, Rect2((size - tex_size * fit) / 2.0, tex_size * fit), false, tint)
		return
	var draw_scale := minf(size.x, size.y) / 40.0
	_canvas.prepare(draw_scale, (size - Vector2(40, 40) * draw_scale) / 2.0, tint, accent)
	_canvas.glow = accent if accent.a > 0.0 else Color(0.45, 0.95, 0.75, tint.a)
	var p := _canvas
	var id := String(ability.id)
	match ability.category:
		AbilityData.Category.GRENADE:
			Shapes.grenade(p)
		AbilityData.Category.STIM:
			if id == "stand_your_ground":
				Shapes.stand(p)
			else:
				Shapes.syringe(p, id == "adrenaline_shot")
		AbilityData.Category.DEPLOYABLE:
			Shapes.turret(p)
		AbilityData.Category.BARRIER:
			if id == "safeguard":
				Shapes.dome(p, false)
			else:
				Shapes.wall(p)
		AbilityData.Category.CLOAK:
			Shapes.cloak(p, id)
		AbilityData.Category.STRIKE:
			Shapes.strike(p, id)
		AbilityData.Category.FIELD:
			ShapesMore.sphere(p, id == "triage_sphere")
		AbilityData.Category.MOBILITY:
			ShapesMore.portal(p)
		AbilityData.Category.SHIELD:
			Shapes.dome(p, true)
		AbilityData.Category.SCANNER:
			ShapesMore.ward(p)
		AbilityData.Category.TRAP:
			if id == "warp_bomb":
				ShapesMore.warp_bomb(p)
			else:
				ShapesMore.snare(p)
		AbilityData.Category.HEAL:
			ShapesMore.aura(p)
