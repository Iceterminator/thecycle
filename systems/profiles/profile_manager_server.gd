extends RefCounted
## Logique serveur de ProfileManager : réputation, statistiques, équipement appliqué au joueur.
## Fonctions statiques : l'état (_profiles, _dirty, public) reste sur le ProfileManager `m`.

const LoadoutRules := preload("res://systems/profiles/profile_loadout_rules.gd")


## Joueur (nœud) d'un peer, ou null.
static func player_of(m: ProfileManager, peer: int) -> Player:
	var players := m.get_parent().get_node_or_null("Players")
	return players.get_node_or_null(str(peer)) as Player if players else null


## Pseudo final : nettoyé, jamais vide, unique parmi les joueurs connectés.
static func unique_name(m: ProfileManager, peer: int, clean: String) -> String:
	var name := clean
	if name == "":
		name = "Joueur%d" % (peer % 10000)
	for other: int in m.public:
		if other != peer and String(m.public[other].get("name", "")).to_lower() == name.to_lower():
			name = (name + "_%d" % (peer % 100)).left(16)
	return name


## Réputation gagnée avec un contrat de `faction` (+ bonus de faction de prédilection).
static func add_rep(m: ProfileManager, peer: int, faction: int, amount: int) -> void:
	if not m._profiles.has(peer) or faction <= 0 or amount <= 0:
		return
	var profile: Dictionary = m._profiles[peer]
	if int(profile["preferred"]) == faction:
		amount = roundi(amount * (1.0 + Config.economy.preferred_faction_bonus))
	var key := str(faction)
	var before := int(profile["rep"].get(key, 0))
	profile["rep"][key] = before + amount
	m._publish(peer)
	m._dirty[peer] = true
	var level_after := ProfileManager.rep_level_of_points(before + amount)
	if level_after > ProfileManager.rep_level_of_points(before):
		var p := player_of(m, peer)
		if p:
			p.score.notify.rpc_id(peer, "Réputation %s : niveau %d ! Nouveaux objets débloqués" % [FactionData.name_of(faction), level_after], FactionData.color_of(faction))


static func add_stat(m: ProfileManager, peer: int, key: String, amount: int) -> void:
	if not m._profiles.has(peer):
		return
	var stats: Dictionary = m._profiles[peer]["stats"]
	stats[key] = int(stats.get(key, 0)) + amount
	m._dirty[peer] = true


## Fin de partie : compte la partie, retient le meilleur score de Fame, sauvegarde.
static func on_match_ended(m: ProfileManager) -> void:
	for peer: int in m._profiles:
		add_stat(m, peer, "matches", 1)
		var p := player_of(m, peer)
		if p:
			var stats: Dictionary = m._profiles[peer]["stats"]
			stats["best_fame"] = maxi(int(stats.get("best_fame", 0)), p.score.rank_points)
		m._save(peer)


## Applique au joueur l'équipement de son profil (ce qui est débloqué).
## Les capacités ne viennent plus du profil : elles s'achètent en partie (boutique -> Q / F).
static func apply_loadout(m: ProfileManager, peer: int) -> void:
	var p := player_of(m, peer)
	if p == null or not m._profiles.has(peer):
		return
	var loadout: Dictionary = m._profiles[peer]["loadout"]
	var kit_id := String(loadout.get("kit", Config.start_loadout.default_kit))
	var kit := LoadoutRules.kit_data(kit_id)
	if kit and ProfileManager.is_unlocked(peer, kit.faction, kit.faction_level):
		if p.kit.kit_id != kit_id:
			p.kit.server_set_kit(kit_id)
	var kit_mods: Dictionary = loadout.get("kit_mods", {})
	p.kit.server_set_mods(LoadoutRules.kit_slots(kit_mods.get(p.kit.kit_id, {})))
	# Dans le lobby, la nouvelle arme de départ est tout de suite en main.
	if MatchManager.is_lobby() and StringName(p.inventory.slot_ids[0]) != ProfileManager.start_weapon(peer):
		p.inventory.reset_loadout()


## Équipement choisi (déjà vérifié par l'appelant) : fusionné au profil, publié, sauvegardé.
static func store_loadout(m: ProfileManager, peer: int, loadout: Dictionary, preferred: int) -> void:
	if not m._profiles.has(peer):
		return
	var profile: Dictionary = m._profiles[peer]
	profile["loadout"].merge(loadout, true)
	profile["preferred"] = preferred
	m._publish(peer)
	m._save(peer)


## Départ d'un joueur : sauvegarde puis retrait du profil et de l'entrée publique.
static func on_player_left(m: ProfileManager, peer: int) -> void:
	m._save(peer)
	m._profiles.erase(peer)
	m._dirty.erase(peer)
	var d := m.public.duplicate(true)
	d.erase(peer)
	m.public = d


## Synchroniseur de `public` (créé en code, présent sur tous les peers).
static func make_public_sync() -> MultiplayerSynchronizer:
	var config := SceneReplicationConfig.new()
	var path := NodePath(".:public")
	config.add_property(path)
	config.property_set_spawn(path, true)
	config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "PublicSync"
	sync.replication_config = config
	return sync


## Un joueur en tue un autre : +1 « kills » pour le tueur (pas pour un suicide).
static func on_player_died(m: ProfileManager, victim: int, killer: int) -> void:
	if killer > 0 and killer != victim:
		add_stat(m, killer, "kills", 1)


## Sauvegarde groupée des profils modifiés, au plus toutes les 10 s (appelé par _physics_process).
static func flush_dirty(m: ProfileManager, delta: float) -> void:
	m._save_left -= delta
	if m._save_left > 0.0 or m._dirty.is_empty():
		return
	m._save_left = 10.0
	for peer: int in m._dirty.keys():
		m._save(peer)


## Vérifie une demande d'équipement (lobby seulement, règles de déblocage).
## Renvoie le résultat de check_request (clé « loadout »), ou {} (avec un message au joueur) si refusé.
static func check_set_loadout(m: ProfileManager, peer: int, loadout: Dictionary) -> Dictionary:
	var p := player_of(m, peer)
	if p == null or not m._profiles.has(peer):
		return {}
	var error := "Équipement : modifiable seulement dans le lobby"
	if MatchManager.is_lobby():
		var result := LoadoutRules.check_request(peer, loadout, m._profiles[peer]["loadout"].get("kit_mods", {}))
		if not result.has("error"):
			return result
		error = String(result["error"])
	p.score.notify.rpc_id(peer, error, ProfileManager.COLOR)
	return {}
