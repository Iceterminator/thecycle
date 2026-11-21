class_name MapView
extends Control
## Carte vue de dessus, dessinée en code (nord = -Z en haut).
## - Écran Tab : toute la carte (follow = false).
## - Minimap du HUD : centrée sur le joueur, ± view_half m (follow = true, sans noms).
## Toujours affichés : obstacles (formes CSG de World/Map), évac,
## zones de tempête, et le joueur local. Seulement à moins de
## Config.MAP_REVEAL_RADIUS : les autres quêtes (cristaux, contrats) et les monstres.

const MapViewEntities := preload("res://systems/map/map_view_entities.gd")

const GRID_STEP := 50.0
const BG_COLOR := Color(0.16, 0.19, 0.15, 1.0)  ## opaque (seul le fond de l'écran Tab est transparent)
const OUTSIDE_COLOR := Color(0.05, 0.05, 0.06, 1.0)  ## hors de la carte (minimap)
const ROCK_COLOR := Color(0.42, 0.4, 0.38)
const GRID_COLOR := Color(1, 1, 1, 0.07)
const SELF_COLOR := Color(1.0, 0.9, 0.2)
const MONSTER_COLOR := Color(0.95, 0.25, 0.2)
const MapViewShards := preload("res://systems/map/map_view_shards.gd")
const MapViewEvenements := preload("res://systems/map/map_view_evenements.gd")
## Repères montrés seulement de près (l'évac et les repères « always » sont toujours montrés).
const NEARBY_KINDS := ["crystal", "contract"]

var player: Player
var world: Node3D
## true : vue centrée sur le joueur (minimap) ; false : toute la carte.
var follow: bool = false
## Demi-côté de la zone montrée (m).
var view_half: float = Config.MAP_HALF_SIZE
## Noms des repères écrits sur la carte (pas sur la minimap, trop petite).
var show_labels: bool = true
## Carte nue (écran de largage) : relief et obstacles seulement, ni quêtes, ni monstres, ni joueurs.
var bare: bool = false

var _origin := Vector2.ZERO
var _scale := 1.0
var _center := Vector2.ZERO  ## centre de la vue (X, Z monde)
## Joueurs repérés par une balise d'écoute : [position, fin (ms)].
var _revealed: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	Events.scan_revealed.connect(func(positions: Array) -> void:
		var until := Time.get_ticks_msec() + int(Config.combat.scan_reveal_time * 1000.0)
		for pos: Vector3 in positions:
			_revealed.append([pos, until]))


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


## Coordonnées monde (X, Z) -> pixels.
func to_map(pos: Vector3) -> Vector2:
	return _origin + (Vector2(pos.x, pos.z) - _center + Vector2(view_half, view_half)) * _scale


## Vrai si `pos` est assez près du joueur local pour que ses quêtes / monstres se voient.
## Sert aussi aux textes flottants des quêtes (voir CombatHud).
static func in_reveal_range(pos: Vector3, from: Vector3) -> bool:
	return Vector2(pos.x - from.x, pos.z - from.z).length() <= reveal_radius()


## Carte complète (menu admin, affichage local) : plus de limite de distance.
static var full_map: bool = false


## Rayon de révélation effectif : unique source pour la carte, la minimap et les textes flottants.
static func reveal_radius() -> float:
	return INF if full_map else Config.MAP_REVEAL_RADIUS


func _draw() -> void:
	if player == null or world == null:
		return
	var side := minf(size.x, size.y)
	_origin = (size - Vector2(side, side)) / 2.0
	_scale = side / (view_half * 2.0)
	_center = Vector2(player.global_position.x, player.global_position.z) if follow else Vector2.ZERO
	# Fond : la carte elle-même, et en minimap ce qui est au-delà de ses bords.
	draw_rect(Rect2(_origin, Vector2(side, side)), OUTSIDE_COLOR)
	var h := Config.MAP_HALF_SIZE
	var map_rect := Rect2(to_map(Vector3(-h, 0, -h)), Vector2(h * 2.0, h * 2.0) * _scale)
	draw_rect(map_rect, BG_COLOR)
	var relief := MapRelief.texture()
	if relief:
		draw_texture_rect(relief, map_rect, false)
	_draw_grid(map_rect)
	_draw_terrain()
	if not bare:
		_draw_reveal_radius()
		MapViewEntities.draw_markers(self)
		MapViewEntities.draw_monsters(self)
		MapViewEntities.draw_revealed(self)
		MapViewEntities.draw_scanner(self)
		MapViewShards.draw(self)
		MapViewEvenements.draw(self)
		_draw_self()
	draw_rect(Rect2(_origin, Vector2(side, side)), Color(1, 1, 1, 0.4), false, 2.0)
	_text(_origin + Vector2(side / 2.0, 16), "N", 16 if show_labels else 12, Color(1, 1, 1, 0.8))


func _draw_grid(map_rect: Rect2) -> void:
	var n := int(Config.MAP_HALF_SIZE * 2.0 / GRID_STEP)
	for i in range(1, n):
		var d := i * GRID_STEP * _scale
		draw_line(map_rect.position + Vector2(d, 0), map_rect.position + Vector2(d, map_rect.size.y), GRID_COLOR)
		draw_line(map_rect.position + Vector2(0, d), map_rect.position + Vector2(map_rect.size.x, d), GRID_COLOR)


## Rochers, rampes, plateforme de l'évac : empreinte au sol des formes CSG de World/Map.
func _draw_terrain() -> void:
	var map := world.get_node_or_null("Map")
	if map == null:
		return
	for node in map.get_children():
		if node.name == "Ground":
			continue
		if node is CSGBox3D:
			var box := node as CSGBox3D
			var half := box.size / 2.0
			var corners := PackedVector2Array()
			for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				corners.append(to_map(box.global_transform * Vector3(c.x * half.x, 0, c.y * half.z)))
			draw_colored_polygon(corners, ROCK_COLOR)
		elif node is CSGCylinder3D:
			var cyl := node as CSGCylinder3D
			draw_circle(to_map(cyl.global_position), cyl.radius * _scale, Color(0.45, 0.6, 0.75, 0.35))


## Cercle discret : ce qui est dedans (quêtes, monstres) apparaît sur la carte.
func _draw_reveal_radius() -> void:
	if full_map:
		return
	var p := to_map(player.global_position)
	var r := Config.MAP_REVEAL_RADIUS * _scale
	draw_circle(p, r, Color(1, 1, 1, 0.05))
	draw_arc(p, r, 0, TAU, 64, Color(1, 1, 1, 0.25), 1.0)


func _draw_self() -> void:
	var p := to_map(player.global_position)
	var forward := -player.global_basis.z
	var dir := Vector2(forward.x, forward.z).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var side := Vector2(-dir.y, dir.x)
	var arrow := PackedVector2Array([p + dir * 11.0, p - dir * 7.0 + side * 7.0, p - dir * 3.0, p - dir * 7.0 - side * 7.0])
	draw_colored_polygon(arrow, SELF_COLOR)
	draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color.BLACK, 1.5)


func _text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := pos - Vector2(width / 2.0, 0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.85))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
