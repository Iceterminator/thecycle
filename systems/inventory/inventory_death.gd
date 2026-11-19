extends RefCounted
## Mort d'un joueur côté inventaire : on lâche ce qui dépasse l'équipement de base,
## la moitié des crédits va au tueur (au sol s'il n'y a pas de tueur joueur). Serveur uniquement.

var _inv: Inventory


func _init(inventory: Inventory) -> void:
	_inv = inventory


func on_dead_changed(dead: bool) -> void:
	if not dead:
		return
	var player := _inv.player
	var pos := player.global_position + Vector3(0, 0.5, 0)
	for i in Inventory.WEAPON_SLOTS:  # les gadgets (Q / F) sont perdus
		if _inv.slot_ids[i] != "" and StringName(_inv.slot_ids[i]) != player.start_weapon_id():
			Events.loot_drop_requested.emit(StringName(_inv.slot_ids[i]), 1 + _inv.slot_boosts[i], _inv.slot_ammo[i], pos, true)
	for res_id: String in _inv.carried:
		Events.loot_drop_requested.emit(StringName(res_id), _inv.carried[res_id], -1, pos, true)
	_inv.carried = {}

	var lost := int(_inv.credits * Config.economy.death_credits_loss)
	if lost > 0:
		_inv.credits -= lost
		Events.credits_changed.emit(player.get_peer_id(), _inv.credits)
		var killer := player.get_parent().get_node_or_null(str(_inv.health.killer_id)) as Player
		if killer and killer != player:
			killer.inventory.add_credits(lost)
		else:
			Events.loot_drop_requested.emit(&"credits", lost, -1, pos, true)
	_inv.reset_loadout()
