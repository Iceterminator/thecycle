class_name ProfileManager
extends Node
## Profils des joueurs (étape 9). Créé en code par World sur tous les peers.
## - Le client envoie son pseudo à l'arrivée (request_register) ; le serveur charge (ou crée)
##   user://profiles/<pseudo>.json : réputation par faction, faction de prédilection, équipement,
##   statistiques. Sauvegardé à chaque changement important, en fin de partie et au départ.
## - « public » (envoyé à tous, PublicSync) : pseudo, réputation, faction de prédilection,
##   mods d'arme — de quoi afficher les noms et vérifier les déblocages partout.
## Déblocages (niveau seulement) : un objet de faction est disponible dès que la réputation
## avec cette faction atteint son niveau requis (Config.economy.rep_levels) ; les objets de départ
## (faction 0 ou niveau 0) le sont toujours. Logique serveur : profile_manager_server.gd.

const ProfileStorage := preload("res://systems/profiles/profile_storage.gd")
const LoadoutRules := preload("res://systems/profiles/profile_loadout_rules.gd")
const PublicReader := preload("res://systems/profiles/profile_public_reader.gd")
const ServerLogic := preload("res://systems/profiles/profile_manager_server.gd")
const PROFILES_DIR := "user://profiles/"
const COLOR := Color(0.75, 0.85, 1.0)

static var _current: ProfileManager

## Synchronisé : peer -> { name, rep: {faction: points}, preferred, weapon_mods: {arme: {emplacement: mod}} }.
var public: Dictionary = {}

var _profiles: Dictionary = {}   # peer -> profil complet (sauvegardé)
var _dirty: Dictionary = {}      # peer -> true : à sauvegarder
var _save_left: float = 0.0

func _init() -> void:
	add_child(ServerLogic.make_public_sync())

func _ready() -> void:
	_current = self
	set_physics_process(multiplayer.is_server())
	if multiplayer.is_server():
		DirAccess.make_dir_recursive_absolute(PROFILES_DIR)
		Events.player_left.connect(func(peer: int) -> void: ServerLogic.on_player_left(self, peer))
		Events.player_died.connect(func(victim: int, killer: int) -> void: ServerLogic.on_player_died(self, victim, killer))
		Events.player_evacuated.connect(func(peer: int) -> void: ServerLogic.add_stat(self, peer, "evacs", 1))
		Events.match_ended.connect(func() -> void: ServerLogic.on_match_ended(self))

func _exit_tree() -> void:
	if _current == self:
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			for peer: int in _profiles:
				_save(peer)
		_current = null

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

## Apparence choisie dans le lobby ("" = automatique, voir PlayerAvatar.model_scene).
static func appearance_of(peer: int) -> String:
	return PublicReader.appearance(_public_of_current(), peer)

static func _public_of_current() -> Dictionary:
	return _current.public if _current else {}

static func default_shop() -> Dictionary:
	return {"weapons": Config.start_loadout.default_shop_weapons.duplicate(), "gadgets": Config.start_loadout.default_shop_gadgets.duplicate()}

## Profil complet du joueur local tel que le serveur l'a renvoyé (équipement), ou {}.
var local_loadout: Dictionary = {}

@rpc("any_peer", "call_local", "reliable")
func request_register(raw_name: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var name := ServerLogic.unique_name(self, peer, ProfileStorage.sanitize(raw_name))
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
	ServerLogic.add_rep(self, peer, faction, amount)

## Serveur : enregistre l'équipement choisi (déjà vérifié par l'appelant).
func server_store_loadout(peer: int, loadout: Dictionary, preferred: int) -> void:
	ServerLogic.store_loadout(self, peer, loadout, preferred)

func _save(peer: int) -> void:
	if not _profiles.has(peer):
		return
	ProfileStorage.save_profile(_profiles[peer])
	_dirty.erase(peer)

## Sauvegarde groupée de la réputation (pas à chaque point gagné).
func _physics_process(delta: float) -> void:
	ServerLogic.flush_dirty(self, delta)

# Client : équipement sauvegardé, pour pré-remplir le lobby
@rpc("authority", "call_local", "reliable")
func _send_loadout(loadout: Dictionary, preferred: int) -> void:
	local_loadout = loadout.duplicate(true)
	local_loadout["preferred"] = preferred
	Events.local_loadout_received.emit(local_loadout)

func _player(peer: int) -> Player:
	return ServerLogic.player_of(self, peer)

## Serveur : applique au joueur l'équipement de son profil (ce qui est débloqué).
func server_apply_loadout(peer: int) -> void:
	ServerLogic.apply_loadout(self, peer)

## Arme de départ valable : une arme secondaire (pas un gadget) débloquée.
static func start_weapon_ok(peer: int, id: String) -> bool:
	return LoadoutRules.start_weapon_ok(peer, id)

## Boutique valable (voir ProfileLoadoutRules.clean_shop) : renvoie la boutique nettoyée, ou {}.
static func clean_shop(peer: int, shop: Dictionary) -> Dictionary:
	return LoadoutRules.clean_shop(peer, shop)

## Lobby : le joueur envoie son équipement.
## { kit, kit_mod, weapon_mods: {arme: {emplacement: mod}}, start_weapon, shop: {weapons, gadgets} }
## + faction de prédilection. Le lobby l'envoie à chaque changement : la réussite est silencieuse.
@rpc("any_peer", "call_local", "reliable")
func request_set_loadout(loadout: Dictionary, preferred: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var result := ServerLogic.check_set_loadout(self, peer, loadout)
	if result.is_empty():
		return
	server_store_loadout(peer, result["loadout"], clampi(preferred, 0, 3))
	server_apply_loadout(peer)
