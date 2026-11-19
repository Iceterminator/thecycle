class_name DropPoints
extends RefCounted
## Points de largage de début de partie (serveur seulement) : un point par escouade (ou joueur
## solo), dans une bande près des murs, bien répartis tout autour de la carte (QuestPlacement).
## Les membres d'une escouade se posent côte à côte.

const CLEARANCE_HEIGHT := 3.0  ## hauteur au-dessus du sol du test « décor solide » (m)
const GROUND_LIFT := 0.3  ## le joueur apparaît un peu au-dessus du sol (m)


## Renvoie {peer_id: position} pour tous les joueurs de `players`.
static func assign(world: World, players: Array[Player]) -> Dictionary:
	var rules := Config.match_rules
	var units: Dictionary = {}  # clé (escouade ou -peer) -> [Player]
	for player in players:
		var squad := SquadManager.squad_of(player.get_peer_id())
		var key := squad if squad != 0 else -player.get_peer_id()
		if not units.has(key):
			units[key] = []
		units[key].append(player)
	var free := _candidates(world)
	var placed: Array[Vector3] = []
	var quadrant_load := PackedInt32Array([0, 0, 0, 0])
	var result: Dictionary = {}
	for key: int in units:
		var index := QuestPlacement.pick_spot(free, placed, rules.quest_min_spacing, placed, quadrant_load, rules)
		if index < 0:  # plus de point assez écarté : on relâche l'espacement
			index = QuestPlacement.pick_spot(free, [], 0.0, placed, quadrant_load, rules)
		var point: Vector3 = free.pop_at(index) if index >= 0 else world.pick_spawn_point()
		placed.append(point)
		quadrant_load[QuestPlacement.quadrant(point)] += 1
		_place_squad(units[key], point, result)
	return result


## Membres côte à côte, le long du mur le plus proche.
static func _place_squad(members: Array, point: Vector3, result: Dictionary) -> void:
	var along := Vector3(0, 0, 1) if absf(point.x) > absf(point.z) else Vector3(1, 0, 0)
	for i in members.size():
		var pos := point + along * Config.match_rules.drop_squad_spacing * (i - (members.size() - 1) / 2.0)
		pos.y = MapTerrain.height_at(pos.x, pos.z) + GROUND_LIFT
		result[(members[i] as Player).get_peer_id()] = pos


## Points valides tirés au hasard dans la bande de 15 à 30 m des murs.
static func _candidates(world: World) -> Array:
	var rules := Config.match_rules
	var half := Config.MAP_HALF_SIZE
	var space := world.get_world_3d().direct_space_state
	var camps := QuestDraw.marker_positions(world.get_node_or_null("MonsterCamps") as Node3D)
	var sphere := SphereShape3D.new()
	sphere.radius = rules.drop_clear_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	var points: Array = []
	for attempt in rules.drop_candidates * 4:
		if points.size() >= rules.drop_candidates:
			break
		var edge := randf_range(rules.drop_edge_min, rules.drop_edge_max)
		var along := randf_range(-half + rules.drop_edge_min, half - rules.drop_edge_min)
		var side := randi() % 4
		var x := along
		var z := along
		if side == 0:
			x = half - edge
		elif side == 1:
			x = -half + edge
		elif side == 2:
			z = half - edge
		else:
			z = -half + edge
		var ground := MapTerrain.height_at(x, z)
		if _near_camp(Vector3(x, 0, z), camps, rules.drop_camp_distance):
			continue
		query.transform = Transform3D(Basis.IDENTITY, Vector3(x, ground + CLEARANCE_HEIGHT, z))
		if space.intersect_shape(query, 1).is_empty():
			points.append(Vector3(x, ground + GROUND_LIFT, z))
	return points


static func _near_camp(pos: Vector3, camps: Array[Vector3], min_distance: float) -> bool:
	for camp in camps:
		if Vector2(pos.x - camp.x, pos.z - camp.z).length() < min_distance:
			return true
	return false
