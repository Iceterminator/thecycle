extends RefCounted
## Pose d'un monstre au sol (serveur) : sert au MonsterManager pour toutes les apparitions.


## Point du sol sous `pos` (tir vers le bas sur la couche « monde »), un peu au-dessus.
static func point(world: Node3D, pos: Vector3) -> Vector3:
	# Le tir part au-dessus du relief (qui peut être haut en ce point).
	var top := maxf(pos.y, MapTerrain.height_at(pos.x, pos.z)) + 3.0
	var query := PhysicsRayQueryParameters3D.create(Vector3(pos.x, top, pos.z), Vector3(pos.x, top - 25.0, pos.z), 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return (hit["position"] as Vector3) + Vector3.UP * 0.05
	# Collision du relief pas encore dans l'espace physique (camps peuplés juste après sa
	# construction) : relief calculé + marge, sinon le monstre naît sous le sol et tombe.
	return Vector3(pos.x, MapTerrain.height_at(pos.x, pos.z) + 0.3, pos.z)
