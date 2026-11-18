class_name MapView
extends Control
## Carte vue de dessus, dessinée en code (nord = -Z en haut).
## - Écran Tab : toute la carte (follow = false).
## - Minimap du HUD : centrée sur le joueur, ± view_half m (follow = true, sans noms).
## Toujours affichés : obstacles (formes CSG de World/Map), évac, Cœur stellaire (où qu'il
## soit), zones de tempête, et le joueur local. Seulement à moins de
## Config.MAP_REVEAL_RADIUS : les autres quêtes (cristaux, contrats) et les monstres.

const GRID_STEP := 50.0
const BG_COLOR := Color(0.16, 0.19, 0.15, 1.0)  ## opaque (seul le fond de l'écran Tab est transparent)
const OUTSIDE_COLOR := Color(0.05, 0.05, 0.06, 1.0)  ## hors de la carte (minimap)
const ROCK_COLOR := Color(0.42, 0.4, 0.38)
const GRID_COLOR := Color(1, 1, 1, 0.07)
const SELF_COLOR := Color(1.0, 0.9, 0.2)
const MONSTER_COLOR := Color(0.95, 0.25, 0.2)
## Repères montrés seulement de près (l'évac et le Cœur stellaire sont toujours montrés).
const NEARBY_KINDS := ["crystal", "contract"]

var player: Player
var world: Node3D
## true : vue centrée sur le joueur (minimap) ; false : toute la carte.
var follow: bool = false
## Demi-côté de la zone montrée (m).
var view_half: float = Config.MAP_HALF_SIZE
## Noms des repères écrits sur la carte (pas sur la minimap, trop petite).
var show_labels: bool = true

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
	return Vector2(pos.x - from.x, pos.z - from.z).length() <= Config.MAP_REVEAL_RADIUS


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
	_draw_grid(map_rect)
	_draw_terrain()
	_draw_reveal_radius()
	_draw_markers()
	_draw_monsters()
	_draw_revealed()
	_draw_scanner()
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
	var p := to_map(player.global_position)
	var r := Config.MAP_REVEAL_RADIUS * _scale
	draw_circle(p, r, Color(1, 1, 1, 0.05))
	draw_arc(p, r, 0, TAU, 64, Color(1, 1, 1, 0.25), 1.0)


func _draw_markers() -> void:
	for node in get_tree().get_nodes_in_group("map_marker"):
		var marker := node as Node3D
		if marker == null or not marker.is_inside_tree() or not marker.has_method("map_info"):
			continue
		var info: Dictionary = marker.map_info()
		var kind: String = info.get("kind", "")
		var pos: Vector3 = info.get("position", marker.global_position)
		var always := kind == "evac" or kind == "relic"
		if not always and not (kind in NEARBY_KINDS and in_reveal_range(pos, player.global_position)):
			continue
		var p := to_map(pos)
		var color: Color = info.get("color", Color.WHITE)
		var title: String = String(info.get("text", "")).get_slice("\n", 0)
		match kind:
			"evac":
				draw_arc(p, 12.0 * _scale, 0, TAU, 32, color, 2.5)
				if show_labels:
					_text(p + Vector2(0, -12.0 * _scale - 4), title, 15, color)
				continue
			"crystal":
				var diamond := PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, 0), p + Vector2(0, 7), p + Vector2(-6, 0)])
				draw_colored_polygon(diamond, color)
			"relic":
				_text(p + Vector2(0, 7), "★", 22, color)
			_:
				draw_circle(p, 5.0, color)
				draw_arc(p, 5.0, 0, TAU, 12, Color.BLACK, 1.0)
		if show_labels:
			_text(p + Vector2(0, -12), title, 13, color)


## Monstres vivants proches (position répliquée chez tous les clients).
func _draw_monsters() -> void:
	var monsters := world.get_node_or_null("Monsters")
	if monsters == null:
		return
	for node in monsters.get_children():
		var monster := node as Monster
		if monster == null or monster.health <= 0.0 or not in_reveal_range(monster.global_position, player.global_position):
			continue
		var p := to_map(monster.global_position)
		var radius := clampf(monster.data.radius * 4.0, 3.0, 6.0) if monster.data else 4.0
		draw_circle(p, radius, MONSTER_COLOR)
		draw_arc(p, radius, 0, TAU, 12, Color.BLACK, 1.0)


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


## Joueurs repérés par vos balises d'écoute (quelle que soit la distance), quelques secondes.
func _draw_revealed() -> void:
	var now := Time.get_ticks_msec()
	_revealed = _revealed.filter(func(r: Array) -> bool: return r[1] > now)
	for r: Array in _revealed:
		var p := to_map(r[0])
		var diamond := PackedVector2Array([p + Vector2(0, -7), p + Vector2(7, 0), p + Vector2(0, 7), p + Vector2(-7, 0)])
		draw_colored_polygon(diamond, Color(1.0, 0.2, 0.6))
		draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color.BLACK, 1.0)


## Partenaire de pacte (toujours) ; Scanner directionnel : joueurs non alliés à moins de
## Config.combat.scanner_range ; crédits et ressources au sol à moins de Config.MAP_REVEAL_RADIUS.
func _draw_scanner() -> void:
	var players := world.get_node_or_null("Players")
	if players:
		for node in players.get_children():
			var other := node as Player
			if other == null or other == player or other.health.is_dead or other.is_evacuated:
				continue
			var p := to_map(other.global_position)
			if Allies.allied(player.get_peer_id(), other.get_peer_id()):
				draw_circle(p, 6.0, Color(0.4, 1.0, 0.6))
				draw_arc(p, 6.0, 0, TAU, 16, Color.BLACK, 1.5)
			elif other.global_position.distance_to(player.global_position) <= Config.combat.scanner_range:
				var tri := PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, 5), p + Vector2(-6, 5)])
				draw_colored_polygon(tri, Color(1.0, 0.3, 0.25))
	var loot := world.get_node_or_null("Loot")
	if loot == null:
		return
	for node in loot.get_children():
		var pickup := node as Pickup
		if pickup == null or pickup.item == null:
			continue
		if pickup.item.kind != ItemData.Kind.CREDITS and pickup.item.kind != ItemData.Kind.RESOURCE:
			continue
		if not in_reveal_range(pickup.global_position, player.global_position):
			continue
		draw_circle(to_map(pickup.global_position), 3.0, pickup.item.color)
