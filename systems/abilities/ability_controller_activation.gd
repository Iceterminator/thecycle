extends RefCounted
## Application serveur d'une capacité (AbilityController.request_use) : effets sur soi,
## demandes d'objets (Events.ability_object_requested), entrave, visée au sol.

var c: AbilityController
var player: Player


func _init(controller: AbilityController) -> void:
	c = controller
	player = controller.player


## Applique la capacité. Renvoie false si elle n'a pas pu partir (pas de cible…).
func activate(a: AbilityData, origin: Vector3, dir: Vector3) -> bool:
	var owner_id := player.get_peer_id()
	var base := {"ability": String(a.id), "owner": owner_id}
	match a.category:
		AbilityData.Category.STIM, AbilityData.Category.CLOAK, AbilityData.Category.SHIELD, AbilityData.Category.HEAL:
			if a.heal_instant > 0.0:
				player.health.heal(a.heal_instant)
			player.buffs.server_add(String(a.id), a.get_display_name(), a.buff, maxf(a.duration_s, 0.1), a.after_buff, a.after_duration_s)
			# Pied ferme : les PV max montent, les PV aussi.
			var bonus := float(a.buff.get("max_health_add", 0.0))
			if bonus > 0.0:
				player.health.heal(bonus)
			return true
		AbilityData.Category.GRENADE, AbilityData.Category.FIELD:
			_request(base.merged({"kind": "grenade", "origin": origin, "dir": dir}))
			return true
		AbilityData.Category.DEPLOYABLE:
			_request(base.merged({"kind": "turret", "pos": _aim_ground(origin, dir, Config.combat.ability_place_range)}))
			return true
		AbilityData.Category.BARRIER:
			var flat := Vector3(dir.x, 0, dir.z).normalized()
			_request(base.merged({"kind": "barrier", "pos": _ground(player.global_position + flat * 2.5), "dir": flat}))
			return true
		AbilityData.Category.STRIKE:
			_request(base.merged({"kind": "strike", "pos": _aim_ground(origin, dir, Config.combat.ability_aim_range)}))
			return true
		AbilityData.Category.TRAP:
			if a.id == &"snare_trap":
				return _snare(a, origin, dir)
			# Bombe de distorsion : la sortie s'ouvre plus loin, même derrière un obstacle.
			var flat := Vector3(dir.x, 0, dir.z).normalized()
			_request(base.merged({"kind": "strike", "pos": _ground(player.global_position + flat * Config.combat.warp_bomb_distance)}))
			return true
		AbilityData.Category.MOBILITY:
			var flat := Vector3(dir.x, 0, dir.z).normalized()
			var entry := _ground(player.global_position + flat * 2.0)
			_request(base.merged({"kind": "portal", "pos": entry, "exit": _ground(entry + flat * maxf(a.distance_m, 5.0))}))
			return true
		AbilityData.Category.SCANNER:
			_request(base.merged({"kind": "ward", "pos": _ground(player.global_position + Vector3(Vector3(dir.x, 0, dir.z).normalized() * 1.0))}))
			return true
	return false


func _request(data: Dictionary) -> void:
	Events.ability_object_requested.emit(data)


## Entrave : la première cible visée (joueur ou monstre, à portée) est ralentie.
func _snare(a: AbilityData, origin: Vector3, dir: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * Config.combat.snare_range)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var target := hit["collider"] as Node
	if target == null or not target.is_in_group("damageable") or not target.can_be_hit():
		return false
	var mult := 1.0 - maxf(a.slow_percent, 0.0) / 100.0
	if target is Player:
		(target as Player).buffs.server_add("snare_trap", a.get_display_name(), {"speed_mult": mult}, a.duration_s)
	elif target is Monster:
		(target as Monster).apply_slow(mult, a.duration_s)
	else:
		return false
	return true


## Point visé au sol (ou au bout de la portée, posé sur le sol).
func _aim_ground(origin: Vector3, dir: Vector3, max_range: float) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * max_range, 1)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var point: Vector3 = hit["position"] if not hit.is_empty() else origin + dir * max_range
	return _ground(point)


func _ground(pos: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 5.0, pos + Vector3.DOWN * 60.0, 1)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector3(pos.x, MapTerrain.height_at(pos.x, pos.z), pos.z)
