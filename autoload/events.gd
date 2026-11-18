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
## Demande au MonsterManager un monstre de vague qui attaquera `objective`.
signal wave_spawn_requested(objective: Node3D, monster_data: MonsterData, position: Vector3, health_mult: float, damage_mult: float)

# Quêtes (cristaux + foreuse) — émis côté serveur
signal quest_started(quest_name: StringName, peer_id: int)
signal quest_failed(quest_name: StringName)
signal quest_completed(quest_name: StringName, peer_id: int, points: int)
## Fame (le score : variable rank_points dans Score, pour la synchro réseau).
signal rank_points_changed(peer_id: int, total: int)
## Serveur, menu admin : poser un cristal (chemin du CrystalData) à une position.
signal crystal_spawn_requested(crystal_data_path: String, position: Vector3)

# Contrats (relais, extracteur, cœur stellaire, collecteurs, station, drones, prime)
## Serveur : demande d'annonce à tous les joueurs (le QuestManager la diffuse).
signal announce_requested(text: String, color: Color)
## Client : une annonce est arrivée (affichée par le HUD).
signal announcement(text: String, color: Color)

# Partie (étapes 5-7)
signal fame_changed(peer_id: int, new_fame: int)
signal contract_completed(peer_id: int, contract_id: StringName)
signal evac_landed()
signal evac_departed()
signal match_ended()
## Serveur, menu admin : avancer le temps de partie de `seconds` (MatchManager).
signal time_skip_requested(seconds: float)
## Serveur, menu admin : aller directement à ce temps de partie (s depuis le début).
signal match_time_set_requested(seconds: float)
## Serveur : un joueur vient d'embarquer dans l'évac (EvacShip -> MatchManager).
signal player_evacuated(peer_id: int)
## Serveur : nouvelle partie, chaque système de carte se remet à zéro (loot, monstres,
## cristaux, contrats, prime, évac). Les joueurs sont remis à zéro par le MatchManager.
signal match_reset_requested()
## Client (local) : le HUD demande l'horloge ; le MatchManager répond par match_clock_synced.
signal match_clock_requested()
## Client : horloge de partie reçue du serveur (phase = MatchManager.Phase).
signal match_clock_synced(elapsed: float, phase: int)
## Client : progression de l'embarquement du joueur local (0 = hors de la soute).
signal evac_board_progress(ratio: float)
## Client : classement de fin de partie (liste de { peer, points, evacuated }).
signal match_results_received(results: Array, restart_in: float)
## Serveur : le niveau des monstres change (1 à 3) ; MonsterManager l'applique aux nouveaux.
signal monster_level_changed(level: int)
## Serveur : les cristaux pas encore commencés montent d'un niveau (QuestManager).
signal crystal_upgrade_requested()
## Serveur : une capacité veut poser un objet (grenade, tourelle, mur, frappe, portail, balise).
signal ability_object_requested(data: Dictionary)
## Client : une balise d'écoute a repéré ces joueurs (positions) pour la carte du propriétaire.
signal scan_revealed(positions: Array)
## Serveur : un joueur tombe à terre / est relevé (étape 8e).
signal player_downed(peer_id: int, attacker_id: int)
signal player_revived(peer_id: int, by_id: int)
## Serveur : le profil d'un joueur est chargé (étape 9).
signal profile_loaded(peer_id: int)
## Client : équipement sauvegardé reçu (pré-remplit le lobby).
signal local_loadout_received(loadout: Dictionary)
## Client : état du lobby (joueurs prêts, secondes avant le départ).
signal lobby_synced(ready: Dictionary)

@warning_ignore_restore("unused_signal")
