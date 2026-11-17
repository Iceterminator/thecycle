extends Node
## Bus de signaux global : les systèmes communiquent sans se connaître.
## Exemple : Events.player_died.emit(victim_id, killer_id)
##           Events.player_died.connect(_on_player_died)

@warning_ignore_start("unused_signal")

# Réseau / joueurs
signal player_joined(peer_id: int)
signal player_left(peer_id: int)

# Combat (étape 2)
signal player_damaged(peer_id: int, amount: float, attacker_id: int)
signal player_died(victim_id: int, killer_id: int)

# Loot et inventaire (étape 3) — émis côté serveur
## Demande au LootManager de poser un objet au sol (caisse ouverte, arme remplacée, mort).
## ammo = -1 : chargeur plein. scatter = éparpiller autour de la position.
signal loot_drop_requested(item_id: StringName, amount: int, ammo: int, position: Vector3, scatter: bool)
signal drop_pod_requested(item_id: StringName, position: Vector3)
signal item_purchased(peer_id: int, item_id: StringName, price: int)
signal item_picked_up(peer_id: int, item_id: StringName, amount: int)
signal credits_changed(peer_id: int, credits: int)

# Monstres (étape 4) — émis côté serveur. Serviront aux contrats de chasse / points de quête.
signal monster_killed(monster_id: StringName, killer_id: int)
signal camp_cleared(camp_name: StringName, killer_id: int)

# Partie (étapes 5-7)
signal fame_changed(peer_id: int, new_fame: int)
signal contract_completed(peer_id: int, contract_id: StringName)
signal storm_warning(seconds_left: float)
signal evac_landed()
signal evac_departed()
signal match_ended()

@warning_ignore_restore("unused_signal")
