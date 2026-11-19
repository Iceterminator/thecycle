extends RefCounted
## Mort d'un monstre (serveur) : crédits au tueur, biomasse, événements, notification du camp.


## Applique la mort de `monster` (tué par `killer_id`, 0 = chute hors carte) puis le retire.
static func die(monster: Monster, killer_id: int) -> void:
	monster.state = Monster.State.RETURN
	monster.set_physics_process(false)
	var data := monster.data
	var players_root := monster.players_root
	# Pour l'instant : seulement des crédits, versés directement au tueur (rien au sol).
	# Plus tard, vider un camp donnera aussi des points de quête.
	var killer := players_root.get_node_or_null(str(killer_id)) as Player if players_root else null
	if killer and data.credits > 0:
		killer.inventory.add_credits(roundi(data.credits * monster.credits_mult))
	if data.biomass_drop > 0:
		Events.loot_drop_requested.emit(&"biomass", data.biomass_drop, -1, monster.global_position + Vector3.UP * 0.4, true)
	Events.monster_killed.emit(data.id, killer_id)
	if monster.camp:
		monster.camp.on_monster_died(monster, killer_id)
	if is_instance_valid(monster.objective) and monster.objective.has_method("on_wave_monster_died"):
		monster.objective.on_wave_monster_died(monster)
	monster.queue_free()
