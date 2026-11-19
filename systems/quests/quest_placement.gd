class_name QuestPlacement
extends RefCounted
## Choix d'un point pour un exemplaire de quête : répartition équilibrée sur la carte.
## Le score favorise l'éloignement des exemplaires du même type, les quarts de carte qui
## n'ont pas encore ce type et le quart opposé au 1er exemplaire ; il pénalise les quarts chargés.

const TOP_CHOICES := 3  ## on tire au hasard parmi les meilleurs scores (variété)
const NO_SAME_TYPE_DISTANCE := 150.0  ## distance « par défaut » si aucun exemplaire du type n'est placé


## Quart de carte (0 à 3) d'une position, centre de la carte à l'origine.
static func quadrant(pos: Vector3) -> int:
	return (1 if pos.x >= 0.0 else 0) + (2 if pos.z >= 0.0 else 0)


## Indice du point choisi dans `free`, -1 s'il n'y en a aucun à `min_spacing` des `spaced`.
## `same_type` : positions déjà placées du type ; `quadrant_load` : quêtes déjà par quart.
static func pick_spot(free: Array, spaced: Array[Vector3], min_spacing: float,
		same_type: Array[Vector3], quadrant_load: PackedInt32Array, rules: MatchRules) -> int:
	var scored: Array[Dictionary] = []
	for i in free.size():
		var point: Vector3 = free[i]
		if _too_close(point, spaced, min_spacing):
			continue
		scored.append({"index": i, "score": _score(point, same_type, quadrant_load, rules)})
	if scored.is_empty():
		return -1
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	return scored[randi() % mini(TOP_CHOICES, scored.size())]["index"]


static func _too_close(point: Vector3, others: Array[Vector3], min_spacing: float) -> bool:
	for other in others:
		if Vector2(point.x - other.x, point.z - other.z).length() < min_spacing:
			return true
	return false


static func _score(point: Vector3, same_type: Array[Vector3], quadrant_load: PackedInt32Array,
		rules: MatchRules) -> float:
	var quad := quadrant(point)
	var nearest := NO_SAME_TYPE_DISTANCE
	var quad_has_type := false
	for other in same_type:
		nearest = minf(nearest, Vector2(point.x - other.x, point.z - other.z).length())
		quad_has_type = quad_has_type or quadrant(other) == quad
	var score := nearest * rules.quest_spread_distance_weight
	if not quad_has_type:
		score += rules.quest_spread_new_quadrant_bonus
	if not same_type.is_empty() and quad == 3 - quadrant(same_type[0]):
		score += rules.quest_spread_opposite_bonus
	return score - rules.quest_spread_load_penalty * quadrant_load[quad]
