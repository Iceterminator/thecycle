extends RefCounted
## Gadgets de Weapon : grenade à fragmentation, rayon vital, balise de rappel.
## Délai de gâchette, balise du joueur, effet serveur d'un « tir » de gadget.

var _w: Weapon


func _init(weapon: Weapon) -> void:
	_w = weapon


## Temps à maintenir : la balise de rappel se pose vite, la téléportation est longue.
func trigger_delay() -> float:
	if _w.data.gadget == WeaponData.GadgetKind.RECALL and not own_beacon():
		return maxf(_w.data.place_time_s, 0.1)
	# Boost « spin_up » : charge et montée en régime plus courtes (client et serveur : même calcul).
	return _w.data.get_trigger_delay() / _w._boost("spin_up")


## Balise de rappel de ce joueur (créée par le serveur, visible chez tous), ou null.
func own_beacon() -> Node3D:
	for node in _w.get_tree().get_nodes_in_group("recall_beacon"):
		if node.owner_id == _w.player.get_peer_id() and not node.is_queued_for_deletion():
			return node
	return null


## Serveur : un « tir » de gadget (munitions, effet, gadget épuisé).
func server_gadget(origin: Vector3, dir: Vector3) -> void:
	var data := _w.data
	var player := _w.player
	var peer := player.get_peer_id()
	match data.gadget:
		WeaponData.GadgetKind.FRAG_GRENADE:
			use_ammo(1)
			Events.ability_object_requested.emit({
				"kind": "frag", "owner": peer, "origin": origin, "dir": dir,
				"damage": data.damage, "radius": data.aoe_radius_m,
				"falloff_start": data.falloff_start_m, "fuse": data.fuse_s,
			})
		WeaponData.GadgetKind.HEAL_BEAM:
			use_ammo(1)
			var to := origin + dir * data.get_max_range()
			var hit := _w._damage.raycast(origin, to)
			var end: Vector3 = hit["position"] if not hit.is_empty() else to
			var target := hit.get("collider") as Player if not hit.is_empty() else null
			var kind := Weapon.HitKind.NONE
			if target and not target.health.is_dead and Allies.allied(peer, target.get_peer_id()):
				target.health.heal(data.heal_per_tick)
				kind = Weapon.HitKind.TARGET
			_w._show_shot.rpc(origin, end, kind)
		WeaponData.GadgetKind.RECALL:
			var beacon := own_beacon()
			if beacon == null:
				Events.ability_object_requested.emit({"kind": "beacon", "owner": peer,
						"pos": player.global_position, "health": data.beacon_health})
				_w._srv.trigger_ms = 0
				return
			var dest := beacon.global_position + Vector3.UP * 0.3
			beacon.queue_free()
			player.global_position = dest
			player.teleport.rpc_id(peer, dest)
			use_ammo(1)
	_check_consumed()


func use_ammo(count: int) -> void:
	_w.inventory.set_active_ammo(maxi(_w.inventory.get_active_ammo() - count, 0))


## Gadget à usage limité vide : retiré de l'emplacement.
func _check_consumed() -> void:
	if _w.data.consumable and _w.inventory.get_active_ammo() <= 0:
		_w.inventory.server_remove_active()


## Rayon vital, clic droit (après validation dans Weapon.request_gadget_alt) :
## se soigner coûte Config.combat.heal_beam_self_cost charges.
func self_heal() -> void:
	if _w.data.gadget != WeaponData.GadgetKind.HEAL_BEAM or _w.inventory.get_active_ammo() < Config.combat.heal_beam_self_cost:
		return
	var now := Time.get_ticks_msec()
	if now < _w._srv.self_heal_ready_ms:
		return
	_w._srv.self_heal_ready_ms = now + int(Config.combat.heal_beam_self_cooldown * 1000.0)
	use_ammo(Config.combat.heal_beam_self_cost)
	_w.health.heal(_w.data.self_heal)
	_w._sync_ammo.rpc_id(_w.player.get_peer_id(), _w.inventory.get_active_ammo())
