extends RefCounted
## Côté serveur des capacités de mouvement : dégâts de la plongée, coup de poing,
## garde de l'esquive. Appelé par les RPC de KitMovement (qui restent sur ce nœud).

var _dive_ready_ms: int = 0
var _punch_ready_ms: int = 0
var _m: KitMovement


func _init(movement: KitMovement) -> void:
	_m = movement


func sender_ok() -> bool:
	var player := _m.player
	return _m.multiplayer.is_server() and _m.multiplayer.get_remote_sender_id() == player.get_peer_id() \
			and not player.health.is_dead and not player.health.is_downed and not player.is_evacuated and not player.is_dropping()


## Atterrissage d'une plongée : dégâts de zone autour du point (pas sur soi).
func dive_impact(pos: Vector3) -> void:
	var kit := _m.kit
	var player := _m.player
	if not sender_ok() or _m.mobility() != KitData.MobilityType.JETPACK:
		return
	var now := Time.get_ticks_msec()
	if now < _dive_ready_ms or not pos.is_finite() or pos.distance_to(player.global_position) > 6.0:
		return
	# 10 % de marge sur la recharge (latence).
	_dive_ready_ms = now + int(kit.move_param("dive_attack", "cooldown_s") * 900.0)
	var radius := kit.move_param("dive_attack", "radius_m")
	var damage := kit.move_param("dive_attack", "damage") + kit.get_effect("dive_damage_add")
	for node in _m.get_tree().get_nodes_in_group("damageable"):
		var target := node as Node3D
		if target == null or target == player or not target.can_be_hit():
			continue
		if target.global_position.distance_to(pos) <= radius:
			target.server_receive_hit(vs_creature(target, damage), player.get_peer_id())
	player.weapon._show_explosion.rpc(pos, radius)


## Coup de poing chargé : frappe la cible la plus proche devant soi, après la ruée.
func punch(dir: Vector3) -> void:
	var kit := _m.kit
	var player := _m.player
	if not sender_ok() or _m.mobility() != KitData.MobilityType.SUPER_JUMP or not dir.is_finite():
		return
	var now := Time.get_ticks_msec()
	if now < _punch_ready_ms:
		return
	_punch_ready_ms = now + int(maxf(kit.move_param("charge_punch", "cooldown_s") + kit.get_effect("punch_cooldown_add"), 1.0) * 900.0)
	await _m.get_tree().create_timer(KitMovement.PUNCH_HIT_DELAY).timeout
	if not _m.is_inside_tree() or player.health.is_dead:
		return
	dir = Vector3(dir.x, 0, dir.z).normalized()
	var best: Node3D = null
	var best_dist := Config.combat.melee_range
	for node in _m.get_tree().get_nodes_in_group("damageable"):
		var target := node as Node3D
		if target == null or target == player or not target.can_be_hit():
			continue
		var to := target.global_position - player.global_position
		to.y = 0.0
		if to.length() <= best_dist and to.normalized().dot(dir) > 0.3:
			best = target
			best_dist = to.length()
	if best == null:
		return
	var mult := 1.0 + kit.get_effect("punch_damage_mult")
	var knock := dir * kit.move_param("charge_punch", "knockback_mps")
	if best is Player:
		best.server_receive_hit(kit.move_param("charge_punch", "damage_vs_players") * mult, player.get_peer_id())
		(best as Player).apply_knockback.rpc_id((best as Player).get_peer_id(), knock)
	else:
		best.server_receive_hit(vs_creature(best, kit.move_param("charge_punch", "damage_vs_monsters") * mult), player.get_peer_id())
		if best is CharacterBody3D:
			best.global_position += knock * 0.15  # petit recul du monstre


## Mod « esquive blindée » : dégâts subis réduits pendant l'esquive.
func dodge_guard(duration: float) -> void:
	if not sender_ok() or _m.mobility() != KitData.MobilityType.DASH:
		return
	var reduction := clampf(_m.kit.get_effect("dodge_damage_reduction"), 0.0, 0.9)
	if reduction <= 0.0:
		return
	_m.player.buffs.server_add("dodge_guard", "Esquive", {"damage_taken_mult": 1.0 - reduction}, clampf(duration, 0.1, 0.5) + 0.1)


## Bonus de dégâts du kit contre les créatures.
func vs_creature(target: Node, damage: float) -> float:
	return damage * (1.0 + _m.kit.get_effect("creature_damage")) if target is Monster else damage
