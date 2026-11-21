class_name QuestDraw
extends RefCounted
## Tirage des quêtes d'une partie (logique pure, serveur seulement).
## Les types obligatoires (Cristal) sont toujours là ; on tire `extra_types` autres types.
## Chaque exemplaire prend un point libre choisi par QuestPlacement (répartition équilibrée) ; s'il n'y en a plus, on s'arrête.

const DRAWS_DIR := "res://data/quest_draws/"
const LUMICEP_OBJECTIVE := &"lumicepes"
const CENTRAL_OBJECTIVE := "station_centrale"  ## objectif de la station centrale (ouverte par des stations de recherche)


static func load_draws() -> Array[QuestDrawData]:
	var draws: Array[QuestDrawData] = []
	for file in ResourceLoader.list_directory(DRAWS_DIR):
		var draw_data: QuestDrawData = load(DRAWS_DIR + file) as QuestDrawData if file.ends_with(".tres") else null
		if draw_data:
			draws.append(draw_data)
	return draws


## Renvoie {"quests": [{kind, data, pos, name, spawn_delay}], "lumicep_spots": Array[Vector3],
## "objectives": PackedStringArray, "summary": String, "list": Array[{name, count, later}],
## "central_spot": Vector3 ou null (station centrale : réservée si des stations de recherche sont tirées)}.
## Les quêtes soumises à l'espacement sont placées d'abord (les plus contraintes), puis les
## cristaux, qui ignorent la règle. Un type tiré garde son objectif même si ses exemplaires
## n'apparaissent que plus tard (spawn_delay, tempête).
static func draw(draws: Array[QuestDrawData], quest_points: Array[Vector3],
		lumicep_points: Array[Vector3], extra_types: int, lumicep_per_collector: int,
		rules: MatchRules) -> Dictionary:
	var chosen: Array[QuestDrawData] = []
	var optional: Array[QuestDrawData] = []
	for d in draws:
		if d.mandatory:
			chosen.append(d)
		else:
			optional.append(d)
	optional.shuffle()
	chosen.append_array(optional.slice(0, extra_types))
	var ordered: Array[QuestDrawData] = []
	ordered.append_array(chosen.filter(func(d: QuestDrawData) -> bool: return not d.ignores_spacing))
	ordered.append_array(chosen.filter(func(d: QuestDrawData) -> bool: return d.ignores_spacing))
	var free := quest_points.duplicate()
	free.shuffle()
	var spaced: Array[Vector3] = []  # positions des quêtes soumises à l'espacement
	var quadrant_load := PackedInt32Array([0, 0, 0, 0])  # quêtes déjà posées par quart de carte
	var quests: Array[Dictionary] = []
	var objectives := PackedStringArray()
	var parts: PackedStringArray = []
	var list: Array[Dictionary] = []  # écran de largage : nom, nombre, « plus tard »
	var lumicep_count := 0
	for d in ordered:
		var wanted := randi_range(d.min_count, d.max_count)
		var placed := 0
		var same_type: Array[Vector3] = []
		for i in wanted:
			var index := QuestPlacement.pick_spot(free, spaced, 0.0 if d.ignores_spacing else rules.quest_min_spacing,
					same_type, quadrant_load, rules)
			if index < 0 or d.variants.is_empty():
				push_warning("[Quête] plus de point libre : %s ×%d sur %d" % [d.display_name, placed, wanted])
				break
			var pos: Vector3 = free.pop_at(index)
			same_type.append(pos)
			quadrant_load[QuestPlacement.quadrant(pos)] += 1
			if not d.ignores_spacing:
				spaced.append(pos)
			for p in _cluster(d, pos):  # un filon (Ambrine) ou une seule quête
				quests.append({"kind": d.kind, "data": _pick_variant(d).resource_path, "pos": p,
						"name": d.display_name, "spawn_delay": d.spawn_delay})
				placed += 1
		if placed == 0:
			continue
		parts.append("%s ×%d" % [d.display_name, placed])
		list.append({"name": d.display_name, "count": placed, "later": d.spawn_delay > 0.0,
				"icon": d.resource_path.get_file().get_basename(), "color": d.variants[0].get("color"),
				"objective": String(d.objective_id)})
		if d.objective_id != &"" and not objectives.has(String(d.objective_id)):
			objectives.append(String(d.objective_id))
		if d.objective_id == LUMICEP_OBJECTIVE:
			lumicep_count += placed
	var central_spot: Variant = null
	var no_same_type: Array[Vector3] = []
	if chosen.any(func(d: QuestDrawData) -> bool: return d.kind == &"facility"):
		var index := QuestPlacement.pick_spot(free, spaced, rules.quest_min_spacing, no_same_type, quadrant_load, rules)
		if index >= 0:
			central_spot = free.pop_at(index)
			objectives.append(CENTRAL_OBJECTIVE)
	for id in rules.always_objectives:  # objectifs sans quête tirée (biomasse : comptée au ramassage)
		if not objectives.has(id):
			objectives.append(id)
	var lumicep_free := lumicep_points.duplicate()
	lumicep_free.shuffle()
	var lumicep_spots: Array[Vector3] = []
	lumicep_spots.assign(lumicep_free.slice(0, lumicep_count * lumicep_per_collector))
	return {"quests": quests, "lumicep_spots": lumicep_spots, "objectives": objectives,
			"summary": ", ".join(parts), "list": list, "central_spot": central_spot}


## Positions d'un filon autour de `center` : la 1re au centre, les autres dans cluster_radius,
## à cluster_gap les unes des autres, posées sur le relief. Sans filon : [center].
static func _cluster(d: QuestDrawData, center: Vector3) -> Array[Vector3]:
	var spots: Array[Vector3] = [center]
	var wanted := randi_range(d.cluster_min, maxi(d.cluster_min, d.cluster_max))
	for attempt in wanted * 20:
		if spots.size() >= wanted:
			break
		var angle := randf() * TAU
		var dist := lerpf(d.cluster_gap, d.cluster_radius, sqrt(randf()))
		var p := center + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		if spots.any(func(s: Vector3) -> bool: return Vector2(s.x - p.x, s.z - p.z).length() < d.cluster_gap):
			continue
		p.y = MapTerrain.height_at(p.x, p.z)
		spots.append(p)
	return spots


## Variante au hasard, pondérée par variant_weights (vide ou de taille différente = uniforme).
static func _pick_variant(d: QuestDrawData) -> Resource:
	var total := 0.0
	if d.variant_weights.size() == d.variants.size():
		for w in d.variant_weights:
			total += w
	if total <= 0.0:
		return d.variants.pick_random()
	var roll := randf() * total
	for i in d.variants.size():
		roll -= d.variant_weights[i]
		if roll < 0.0:
			return d.variants[i]
	return d.variants.back()


## Positions globales des Marker3D enfants de `root` (liste vide si root est nul).
static func marker_positions(root: Node3D) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	if root:
		for node in root.get_children():
			if node is Marker3D:
				positions.append((node as Marker3D).global_position)
	return positions
