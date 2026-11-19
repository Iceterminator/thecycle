class_name LumicepTicks
extends Node
## Serveur : les points « lumicep » font repousser des Lumicèpes (objets au sol) ;
## porter des Lumicèpes attire des Tiques (de plus en plus souvent).
## Créé par le QuestManager, qui fournit les points avec set_spots().

const LUMICEP := &"lumicep"
const TIQUE := preload("res://data/monsters/tique.tres")

var players_root: Node3D
var loot_root: Node
var _spots: Array[Vector3] = []
var _lumicep_timer: float = 0.0
var _tick_timers: Dictionary = {}  # peer_id -> secondes avant la prochaine Tique


func set_spots(spots: Array[Vector3]) -> void:
	_spots = spots
	_tick_timers.clear()
	_lumicep_timer = 0.0


func _physics_process(delta: float) -> void:
	_lumicep_timer -= delta
	if _lumicep_timer <= 0.0:
		_lumicep_timer = Config.match_rules.lumicep_respawn_time
		_regrow_lumiceps()
	for node in players_root.get_children():
		var player := node as Player
		if player == null or not player.can_be_hit():
			continue
		var carried := player.inventory.get_resource(LUMICEP)
		var peer := player.get_peer_id()
		if carried <= 0:
			_tick_timers.erase(peer)
			continue
		# Plus on porte de Lumicèpes, plus les Tiques arrivent vite.
		var interval := maxf(Config.match_rules.tick_interval / carried, Config.match_rules.tick_min_interval)
		var left: float = _tick_timers.get(peer, interval) - delta
		if left <= 0.0:
			left = interval
			var angle := randf() * TAU
			var pos := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(12.0, 16.0)
			pos.y = MapTerrain.height_at(pos.x, pos.z)
			Events.wave_spawn_requested.emit(player, TIQUE, pos, 1.0, 1.0)
		_tick_timers[peer] = left


func _regrow_lumiceps() -> void:
	for spot in _spots:
		var present := false
		for p in loot_root.get_children():
			var pickup := p as Pickup
			if pickup and pickup.item.id == LUMICEP and pickup.global_position.distance_to(spot) < 1.5:
				present = true
				break
		if not present:
			Events.loot_drop_requested.emit(LUMICEP, 1, -1, spot, false)
