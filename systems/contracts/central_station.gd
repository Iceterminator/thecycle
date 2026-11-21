class_name CentralStation
extends ContractSite
## Station centrale (Central Power d'origine). Ouverte par CentralPower après `central_unlock_count`
## stations réactivées, elle reste active `active_time` s. Chaque joueur vivant dans la zone
## (`zone_radius`) gagne `points_per_second` points de l'objectif « station centrale ».
## Des Gardiens (`guards`) apparaissent toutes les `guard_interval` s (au plus `guard_max`) et
## attaquent les joueurs de la zone. Elle s'éteint (annonce) puis disparaît.
## Champs utilisés : zone_radius, active_time, points_per_second, guard_*, guards, color, track.

var time_left: float = 0.0  ## synchronisé

var _inside: Dictionary = {}  # serveur : peer_id des joueurs dans la zone à la frame précédente
var _guard_timer: float = 0.0


func _sync_props() -> Array[String]:
	return ["time_left"]


func _build_visual() -> void:
	time_left = data.active_time
	_guard_timer = data.guard_interval  # le 1er Gardien arrive dès qu'un joueur est dans la zone
	add_cylinder_collision(0.6, 4.0)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.2
	pole.bottom_radius = 0.6
	pole.height = 4.0
	var p := make_mesh(pole, Color(0.6, 0.65, 0.75))
	p.position.y = 2.0
	add_child(p)
	var lamp := make_mesh(SphereMesh.new(), data.color, true)
	lamp.position.y = 4.4
	add_child(lamp)
	var disc := CylinderMesh.new()
	disc.top_radius = data.zone_radius
	disc.bottom_radius = data.zone_radius
	disc.height = 0.3
	var d := make_mesh(disc, Color(data.color, 0.25), true)
	(d.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	d.position.y = 0.2
	add_child(d)


func _label_height() -> float:
	return 5.6


func _refresh() -> void:
	_label.text = "%s — ouverte\n+%d pts/s dans la zone, ferme dans %d:%02d" % [data.display_name,
			int(data.points_per_second), int(time_left) / 60, int(time_left) % 60]


func map_info() -> Dictionary:
	var info := super()
	info["always"] = true
	info["icon"] = QuestIcons.of("facility")
	return info


func _physics_process(delta: float) -> void:
	time_left = maxf(time_left - delta, 0.0)
	var in_zone := _players_in_zone()
	_score_zone(in_zone, delta)
	_spawn_guard(in_zone, delta)
	if time_left <= 0.0:
		_close()


func _players_in_zone() -> Array[Player]:
	var result: Array[Player] = []
	for node in players_root().get_children():
		var player := node as Player
		if player == null or not player.can_be_hit():
			continue
		var offset := player.global_position - global_position
		if Vector2(offset.x, offset.z).length() <= data.zone_radius:
			result.append(player)
	return result


func _score_zone(in_zone: Array[Player], delta: float) -> void:
	var now: Dictionary = {}
	for player in in_zone:
		now[player.get_peer_id()] = true
		give_points_over_time(player, data.points_per_second, delta)
		if not _inside.has(player.get_peer_id()):
			player.score.set_objective_rate(data.track, data.points_per_second)
	for peer: int in _inside:
		var left := find_player(peer)
		if not now.has(peer) and left:
			left.score.set_objective_rate(data.track, 0.0)
	_inside = now


func _spawn_guard(in_zone: Array[Player], delta: float) -> void:
	_guard_timer += delta
	if _guard_timer < data.guard_interval or in_zone.is_empty() or data.guards.is_empty():
		return
	if _guard_count() >= data.guard_max:
		return
	_guard_timer = 0.0
	var angle := randf() * TAU
	var pos := global_position + Vector3(cos(angle), 0.0, sin(angle)) * (data.zone_radius + randf_range(8.0, 14.0))
	pos.y = MapTerrain.height_at(pos.x, pos.z)
	Events.wave_spawn_requested.emit(in_zone.pick_random(), data.guards.pick_random(), pos,
			data.monster_health_mult, data.monster_damage_mult)


## Gardiens vivants autour de la station (les monstres de la partie sont tous dans le groupe « damageable »).
func _guard_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("damageable"):
		var monster := node as Monster
		if monster and monster.health > 0.0 and data.guards.has(monster.data) \
				and monster.global_position.distance_to(global_position) <= data.zone_radius * 4.0:
			count += 1
	return count


## La station s'éteint : plus de gain continu affiché pour les joueurs de la zone.
func _close() -> void:
	for peer: int in _inside:
		var player := find_player(peer)
		if player:
			player.score.set_objective_rate(data.track, 0.0)
	announce("La station centrale s'est éteinte")
	queue_free()
