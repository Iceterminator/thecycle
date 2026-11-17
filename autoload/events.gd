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

# Partie (étapes 5-7)
signal fame_changed(peer_id: int, new_fame: int)
signal contract_completed(peer_id: int, contract_id: StringName)
signal storm_warning(seconds_left: float)
signal evac_landed()
signal evac_departed()
signal match_ended()

@warning_ignore_restore("unused_signal")
