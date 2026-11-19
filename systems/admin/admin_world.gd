extends RefCounted
## Utilitaires du menu admin : cristaux disponibles, points devant le joueur, recalage au sol.

const QUESTS_DIR := "res://data/quests/"


## Les CrystalData disponibles (un par difficulté), triés par niveau.
static func get_crystal_datas() -> Array[CrystalData]:
	var result: Array[CrystalData] = []
	for file in ResourceLoader.list_directory(QUESTS_DIR):
		if file.ends_with(".tres"):
			var crystal := load(QUESTS_DIR + file) as CrystalData
			if crystal:
				result.append(crystal)
	result.sort_custom(func(a: CrystalData, b: CrystalData) -> bool: return a.level < b.level)
	return result


## Point à `distance` m devant le joueur, à hauteur de ses pieds.
static func front(player: Player, distance: float) -> Vector3:
	var forward := -player.global_basis.z
	forward.y = 0.0
	return player.global_position + forward.normalized() * distance


## Pose le point sur le sol (le cristal n'est pas recalé par le QuestManager).
static func ground(player: Player, pos: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 10.0, pos + Vector3.DOWN * 50.0)
	query.collision_mask = 1  # monde seulement
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else pos
