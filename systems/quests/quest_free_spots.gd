class_name QuestFreeSpots
extends RefCounted
## Emplacements de quête libres en cours de partie (serveur) : pour la surtension et l'Alpha.
## Libre = aucune quête tirée à moins de TAKEN_RADIUS m. Les emplacements loin des joueurs passent d'abord.

const TAKEN_RADIUS := 4.0


## Jusqu'à `count` positions libres au hasard ; celles à au moins `min_player_distance` m de tout joueur en premier.
static func pick(spots_root: Node3D, quest_root: Node, players_root: Node, count: int, min_player_distance: float) -> Array[Vector3]:
	var far: Array[Vector3] = []
	var near: Array[Vector3] = []
	for pos in QuestDraw.marker_positions(spots_root):
		if _taken(pos, quest_root):
			continue
		if _player_distance(pos, players_root) >= min_player_distance:
			far.append(pos)
		else:
			near.append(pos)
	far.shuffle()
	near.shuffle()
	var result: Array[Vector3] = []
	result.assign((far + near).slice(0, count))
	return result


static func _taken(pos: Vector3, quest_root: Node) -> bool:
	for node in quest_root.get_children():
		var quest := node as Node3D
		if quest and Vector2(quest.global_position.x - pos.x, quest.global_position.z - pos.z).length() < TAKEN_RADIUS:
			return true
	return false


static func _player_distance(pos: Vector3, players_root: Node) -> float:
	var best := INF
	for node in players_root.get_children():
		var player := node as Player
		if player and not player.health.is_dead:
			best = minf(best, player.global_position.distance_to(pos))
	return best
