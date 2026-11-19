class_name ProfileManager
extends Node
## Profils des joueurs (étape 9). Créé en code par World sur tous les peers.
## - Le client envoie son pseudo à l'arrivée (request_register) ; le serveur charge (ou
##   crée) le profil user://profiles/<pseudo>.json : réputation par faction, faction de
##   prédilection, équipement (kit, capacités, mods), statistiques. Sauvegardé à chaque
##   changement important, en fin de partie et au départ du joueur.
## - « public » (envoyé à tous, PublicSync) : pseudo, réputation, faction de prédilection,
##   mods d'arme — de quoi afficher les noms et vérifier les déblocages partout.
## Déblocages (niveau seulement) : un objet de faction est disponible dès que la réputation
## avec cette faction atteint son niveau requis (Config.economy.rep_levels) ; les objets de départ
## (faction 0 ou niveau 0) le sont toujours.


const ProfileStorage := preload("res://systems/profiles/profile_storage.gd")
const LoadoutRules := preload("res://systems/profiles/profile_loadout_rules.gd")
const PublicReader := preload("res://systems/profiles/profile_public_reader.gd")
const PROFILES_DIR := "user://profiles/"
const COLOR := Color(0.75, 0.85, 1.0)

static var _current: ProfileManager

## Synchronisé : peer -> { name, rep: {faction: points}, preferred, weapon_mods: {arme: mod} }.
var public: Dictionary = {}

# --- Serveur ---
var _profiles: Dictionary = {}   # peer -> profil complet (sauvegardé)
var _dirty: Dictionary = {}      # peer -> true : à sauvegarder
var _save_left: float = 0.0


func _init() -> void:
	var config := SceneReplicationConfig.new()
	var path := NodePath(".:public")
	config.add_property(path)
	config.property_set_spawn(path, true)
	config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "PublicSync"
	sync.replication_config = config
	add_child(sync)


func _ready() -> void:
	_current = self
	set_physics_process(multiplayer.is_server())
	if multiplayer.is_server():
		DirAccess.make_dir_recursive_absolute(PROFILES_DIR)
		Events.player_left.connect(_on_player_left)
		Events.player_died.connect(_on_player_died)
		Events.player_evacuated.connect(func(peer: int) -> void: _stat(peer, "evacs", 1))
		Events.match_ended.connect(_on_match_ended)


func _exit_tree() -> void:
	if _current == self:
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			for peer: int in _profiles:
				_save(peer)
		_current = null


# =========================================================================
# Lecture (tous les peers)
# =========================================================================

## Nom affiché d'un joueur (son pseudo, sinon « Joueur <id> »).
static func name_of(peer: int) -> String:
	return PublicReader.name_of(_public_of_current(), peer)


static func rep_points(peer: int, faction: int) -> int:
	return PublicReader.rep_points(_public_of_current(), peer, faction)


## Niveau de réputation (0 à 10) : nombre de seuils de Config.economy.rep_levels atteints.
static func rep_level_of_points(points: int) -> int:
	var level := 0
	for threshold: int in Config.economy.rep_levels:
		if points >= threshold:
			level += 1
	return level


static func rep_level(peer: int, faction: int) -> int:
	return rep_level_of_points(rep_points(peer, faction))


## Objet de `faction` demandant `level` : disponible pour ce joueur ?
static func is_unlocked(peer: int, faction: int, level: int) -> bool:
	if faction <= 0 or level <= 0:
		return true
	return rep_level(peer, faction) >= level


static func preferred_faction(peer: int) -> int:
	return PublicReader.preferred_faction(_public_of_current(), peer)


## Mods d'arme choisis par ce joueur : { id d'arme : id de mod }.
static func weapon_mods(peer: int) -> Dictionary:
	return PublicReader.weapon_mods(_public_of_current(), peer)


## Arme de départ du joueur (une arme secondaire débloquée), Config.start_loadout.base_weapon par défaut.
static func start_weapon(peer: int) -> StringName:
	return PublicReader.start_weapon(_public_of_current(), peer)


## Boutique configurée : { weapons: [4 ids], gadgets: [4 ids] } ("" = case vide).
static func shop_of(peer: int) -> Dictionary:
	var shop := PublicReader.shop_of(_public_of_current(), peer)
	return shop if not shop.is_empty() else default_shop()


static func _public_of_current() -> Dictionary:
	return _current.public if _current else {}


static func default_shop() -> Dictionary:
	return {"weapons": Config.start_loadout.default_shop_weapons.duplicate(), "gadgets": Config.start_loadout.default_shop_gadgets.duplicate()}


## Profil complet du joueur local tel que le serveur l'a renvoyé (équipement), ou {}.
var local_loadout: Dictionary = {}


# =========================================================================
# Serveur
# =========================================================================


@rpc("any_peer", "call_local", "reliable")
func request_register(raw_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var name := ProfileStorage.sanitize(raw_name)
	if name == "":
		name = "Joueur%d" % (peer % 10000)
	# Deux joueurs connectés ne peuvent pas avoir le même pseudo.
	for other: int in public:
		if other != peer and String(public[other].get("name", "")).to_lower() == name.to_lower():
			name = (name + "_%d" % (peer % 100)).left(16)
	var profile := ProfileStorage.load_or_default(name)
	_profiles[peer] = profile
	_publish(peer)
	print("[Profil] Joueur %d = %s" % [peer, name])
	server_apply_loadout(peer)
	Events.profile_loaded.emit(peer)
	_send_loadout.rpc_id(peer, profile["loadout"], profile["preferred"])
	_save(peer)


## Met à jour l'entrée publique du joueur (envoyée à tous).
func _publish(peer: int) -> void:
	var d := public.duplicate(true)
	d[peer] = PublicReader.public_entry(_profiles[peer])
	public = d


func server_profile(peer: int) -> Dictionary:
	return _profiles.get(peer, {})


## Serveur : réputation gagnée avec un contrat de `faction` (+ bonus de faction de prédilection).
func server_add_rep(peer: int, faction: int, amount: int) -> void:
	if not _profiles.has(peer) or faction <= 0 or amount <= 0:
		return
	var profile: Dictionary = _profiles[peer]
	if int(profile["preferred"]) == faction:
		amount = roundi(amount * (1.0 + Config.economy.preferred_faction_bonus))
	var key := str(faction)
	var before := int(profile["rep"].get(key, 0))
	profile["rep"][key] = before + amount
	_publish(peer)
	_dirty[peer] = true
	var level_before := rep_level_of_points(before)
	var level_after := rep_level_of_points(before + amount)
	if level_after > level_before:
		var players := get_parent().get_node_or_null("Players")
		var p := players.get_node_or_null(str(peer)) as Player if players else null
		if p:
			p.score.notify.rpc_id(peer, "Réputation %s : niveau %d ! Nouveaux objets débloqués" % [FactionData.name_of(faction), level_after], FactionData.color_of(faction))


## Serveur : enregistre l'équipement choisi (déjà vérifié par l'appelant).
func server_store_loadout(peer: int, loadout: Dictionary, preferred: int) -> void:
	if not _profiles.has(peer):
		return
	var profile: Dictionary = _profiles[peer]
	profile["loadout"].merge(loadout, true)
	profile["preferred"] = preferred
	_publish(peer)
	_save(peer)


func _stat(peer: int, key: String, amount: int) -> void:
	if not _profiles.has(peer):
		return
	var stats: Dictionary = _profiles[peer]["stats"]
	stats[key] = int(stats.get(key, 0)) + amount
	_dirty[peer] = true


func _on_player_died(victim: int, killer: int) -> void:
	if killer > 0 and killer != victim:
		_stat(killer, "kills", 1)


func _on_match_ended() -> void:
	var players := get_parent().get_node_or_null("Players")
	for peer: int in _profiles:
		_stat(peer, "matches", 1)
		var p := players.get_node_or_null(str(peer)) as Player if players else null
		if p:
			var stats: Dictionary = _profiles[peer]["stats"]
			stats["best_fame"] = maxi(int(stats.get("best_fame", 0)), p.score.rank_points)
		_save(peer)


func _on_player_left(peer: int) -> void:
	_save(peer)
	_profiles.erase(peer)
	_dirty.erase(peer)
	var d := public.duplicate(true)
	d.erase(peer)
	public = d


func _save(peer: int) -> void:
	if not _profiles.has(peer):
		return
	ProfileStorage.save_profile(_profiles[peer])
	_dirty.erase(peer)


## Sauvegarde groupée de la réputation (pas à chaque point gagné).
func _physics_process(delta: float) -> void:
	_save_left -= delta
	if _save_left > 0.0 or _dirty.is_empty():
		return
	_save_left = 10.0
	for peer: int in _dirty.keys():
		_save(peer)


# =========================================================================
# Client : équipement sauvegardé, pour pré-remplir le lobby
# =========================================================================

@rpc("authority", "call_local", "reliable")
func _send_loadout(loadout: Dictionary, preferred: int) -> void:
	local_loadout = loadout.duplicate(true)
	local_loadout["preferred"] = preferred
	Events.local_loadout_received.emit(local_loadout)


# =========================================================================
# Équipement (lobby) : vérifié et appliqué par le serveur
# =========================================================================

func _player(peer: int) -> Player:
	var players := get_parent().get_node_or_null("Players")
	return players.get_node_or_null(str(peer)) as Player if players else null



## Serveur : applique au joueur l'équipement de son profil (ce qui est débloqué).
## Les capacités ne viennent plus du profil : elles s'achètent en partie (boutique -> Q / F).
func server_apply_loadout(peer: int) -> void:
	var p := _player(peer)
	if p == null or not _profiles.has(peer):
		return
	var loadout: Dictionary = _profiles[peer]["loadout"]
	var kit_id := String(loadout.get("kit", Config.start_loadout.default_kit))
	var kit := LoadoutRules.kit_data(kit_id)
	if kit and is_unlocked(peer, kit.faction, kit.faction_level):
		if p.kit.kit_id != kit_id:
			p.kit.server_set_kit(kit_id)
	var kit_mods: Dictionary = loadout.get("kit_mods", {})
	p.kit.server_set_mod(String(kit_mods.get(p.kit.kit_id, "")))
	# Dans le lobby, la nouvelle arme de départ est tout de suite en main.
	if MatchManager.is_lobby() and StringName(p.inventory.slot_ids[0]) != start_weapon(peer):
		p.inventory.reset_loadout()



## Arme de départ valable : une arme secondaire (pas un gadget) débloquée.
static func start_weapon_ok(peer: int, id: String) -> bool:
	return LoadoutRules.start_weapon_ok(peer, id)


## Boutique valable (voir ProfileLoadoutRules.clean_shop) : renvoie la boutique nettoyée, ou {}.
static func clean_shop(peer: int, shop: Dictionary) -> Dictionary:
	return LoadoutRules.clean_shop(peer, shop)


## Lobby : le joueur envoie son équipement.
## { kit, kit_mod, weapon_mods: {arme: mod}, start_weapon, shop: {weapons, gadgets} }
## + faction de prédilection. Le lobby l'envoie à chaque changement : la réussite est silencieuse.
@rpc("any_peer", "call_local", "reliable")
func request_set_loadout(loadout: Dictionary, preferred: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var p := _player(peer)
	if p == null or not _profiles.has(peer):
		return
	if not MatchManager.is_lobby():
		_reply(peer, "Équipement : modifiable seulement dans le lobby")
		return
	var result := LoadoutRules.check_request(peer, loadout, _profiles[peer]["loadout"].get("kit_mods", {}))
	if result.has("error"):
		_reply(peer, String(result["error"]))
		return
	server_store_loadout(peer, result["loadout"], clampi(preferred, 0, 3))
	server_apply_loadout(peer)


func _reply(peer: int, text: String) -> void:
	var p := _player(peer)
	if p:
		p.score.notify.rpc_id(peer, text, COLOR)
