class_name QuestBadge
extends Control
## Pastille ronde d'une quête (HUD) : disque gris clair, logo à la couleur de la quête,
## jauge jaune autour pour la progression vers le prochain palier (0 à 1).

const FILL := Color(0.62, 0.64, 0.66)
const TRACK := Color(0, 0, 0, 0)  ## fond de jauge : transparent
const GAUGE := Color(1.0, 0.82, 0.2)
const RING := 4.5  ## épaisseur de la jauge (px)

var icon: Texture2D
var color: Color = Color.WHITE
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


static func make(icon_tex: Texture2D, quest_color: Color, size_px: float, ratio: float) -> QuestBadge:
	var b := QuestBadge.new()
	b.icon = icon_tex
	b.color = quest_color
	b.progress = ratio
	b.custom_minimum_size = Vector2(size_px, size_px)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0
	draw_circle(center + Vector2(0, 1.5), radius - RING - 1.0, Color(0, 0, 0, 0.3))  # ombre du disque
	if TRACK.a > 0.0:
		draw_arc(center, radius - RING / 2.0, 0, TAU, 48, TRACK, RING, true)
	if progress > 0.0:
		draw_arc(center, radius - RING / 2.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 48, GAUGE, RING, true)
	draw_circle(center, radius - RING - 1.0, FILL)
	if icon:
		var half := Vector2.ONE * (radius - RING - 1.0) * 1.05
		draw_texture_rect(icon, Rect2(center - half, half * 2.0), false, color.darkened(0.1))
