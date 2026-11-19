class_name WeaponIcon
extends Control
## Visuel d'arme du HUD et des menus, dessiné en code et propre à chaque arme : les pièces
## sont choisies d'après ses données (type, lunette selon le zoom, chargeur selon la
## capacité, canon selon la portée, bobines pour les armes à énergie, plombs = canon large…),
## avec quelques variantes tirées de son id (crosse, évents). Ombrage simple : métal, pièces
## sombres, reflet, contour, et un liseré de la couleur `accent` (faction).
## Si l'arme a une vraie image (WeaponData.hud_icon), elle est affichée à la place.
## Repère de dessin : 100 × 40, canon vers la droite.

const Canvas := preload("res://systems/ui/weapon_icon_canvas.gd")
const LongGun := preload("res://systems/ui/weapon_icon_long_gun.gd")
const SmallArms := preload("res://systems/ui/weapon_icon_small.gd")

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

var _canvas: Canvas


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_canvas = Canvas.new(self)


func _draw() -> void:
	if weapon == null:
		return
	if weapon.hud_icon:
		var tex_size := weapon.hud_icon.get_size()
		var fit := minf(size.x / tex_size.x, size.y / tex_size.y)
		draw_texture_rect(weapon.hud_icon, Rect2((size - tex_size * fit) / 2.0, tex_size * fit), false, tint)
		return
	var draw_scale := minf(size.x / 100.0, size.y / 40.0)
	_canvas.prepare(draw_scale, (size - Vector2(100, 40) * draw_scale) / 2.0, tint, accent)
	if weapon.gadget != WeaponData.GadgetKind.NONE:
		SmallArms.draw_gadget(_canvas, weapon)
		return
	match weapon.type:
		WeaponData.WeaponType.PISTOL:
			SmallArms.draw_pistol(_canvas, weapon)
		WeaponData.WeaponType.MISSILE_LAUNCHER, WeaponData.WeaponType.HEAVY:
			SmallArms.draw_launcher(_canvas, weapon)
		_:
			LongGun.draw(_canvas, weapon)
