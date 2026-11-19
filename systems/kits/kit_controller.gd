class_name KitController
extends Node
## Kit (combinaison) d'un joueur : PV, bouclier, vitesse, capacités de mouvement, niveau.
## Créé en code par le Player sur tous les peers (nœud « Kit », autorité serveur).
##
## Serveur : applique le kit choisi dans le lobby (ou par le menu admin), donne
## l'XP (joueurs tués, monstres tués, points d'objectif et Fame gagnés), fait monter le
## niveau (1 à 6, Config.economy.kit_level_xp) et applique PV / bouclier à la Health.
## kit_id, level et xp sont envoyés à tous (KitSync) : chaque peer calcule les mêmes bonus.
## Bonus de niveau : KitData.level_perk_effects[0 .. level-1] (index 0 = niveau 1, actif
## dès le départ). Tout est remis à zéro à chaque partie.
## Les calculs sont dans kit_controller_effects.gd, la logique serveur dans
## kit_controller_server.gd.

signal changed
signal leveled_up(level: int)

const KitControllerEffects := preload("res://systems/kits/kit_controller_effects.gd")
const KitControllerServer := preload("res://systems/kits/kit_controller_server.gd")
const KITS_DIR := "res://data/kits/"

## Synchronisés (serveur -> tous).
var kit_id: String = "":
	set(value):
		if value == kit_id:
			return
		kit_id = value
		_kit = null
		changed.emit()
var level: int = 1:
	set(value):
		level = value
		changed.emit()
var xp: int = 0:
	set(value):
		xp = value
		changed.emit()
## Mod de kit équipé (id dans KitData.mods, "" = aucun) ; choisi dans le lobby (étape 9).
var mod_id: String = "":
	set(value):
		mod_id = value
		changed.emit()

var player: Player
var _kit: KitData
var _fx: KitControllerEffects
var _srv: KitControllerServer


func _init() -> void:
	_fx = KitControllerEffects.new(self)
	_srv = KitControllerServer.new(self)
	var config := SceneReplicationConfig.new()
	for key in ["kit_id", "level", "xp", "mod_id"]:
		var path := NodePath(".:" + key)
		config.add_property(path)
		config.property_set_spawn(path, true)
		# ALWAYS : un joueur qui arrive en cours de partie reçoit aussi les valeurs.
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "KitSync"
	sync.replication_config = config
	add_child(sync)


func _ready() -> void:
	player = get_parent() as Player
	if multiplayer.is_server():
		Events.match_reset_requested.connect(_server_on_match_reset)
		Events.monster_killed.connect(_srv.on_monster_killed)
		Events.player_died.connect(_srv.on_player_died)
		kit_id = String(Config.start_loadout.default_kit)
		_srv.apply_stats(true)


## Kit actuel (celui par défaut tant que rien n'est reçu).
func get_kit() -> KitData:
	if _kit == null:
		var id := kit_id if kit_id != "" else String(Config.start_loadout.default_kit)
		_kit = load(KITS_DIR + id + ".tres") as KitData
	return _kit


static func list_kits() -> Array[KitData]:
	var result: Array[KitData] = []
	for file in ResourceLoader.list_directory(KITS_DIR):
		var k: KitData = load(KITS_DIR + file) as KitData if file.ends_with(".tres") else null
		if k:
			result.append(k)
	result.sort_custom(func(a: KitData, b: KitData) -> bool: return a.display_name < b.display_name)
	return result


## Somme d'un effet sur les bonus débloqués (niveaux 1 à `level`).
func get_effect(effect: String) -> float:
	return _fx.get_effect(effect)


## Paramètre d'une capacité de mouvement (KitData.movement). Sans `default`, la valeur
## doit être dans les données du kit (sinon 0 et un avertissement).
func move_param(ability: String, key: String, default: float = NAN) -> float:
	return _fx.move_param(ability, key, default)


func get_display_name() -> String:
	return KitController.kit_name(get_kit())


## Nom affiché d'un kit (nom d'origine tant que Config.SHOW_REFERENCE_WEAPON_NAMES est vrai).
static func kit_name(kit: KitData) -> String:
	if kit == null:
		return "?"
	if Config.SHOW_REFERENCE_WEAPON_NAMES and kit.reference_name != "":
		return kit.reference_name
	return kit.display_name


func max_health() -> float:
	return _fx.max_health()


func max_shield() -> float:
	return _fx.max_shield()


## Vitesse de marche (m/s) ; le sprint la multiplie par Config.combat.sprint_multiplier.
func move_speed() -> float:
	return _fx.move_speed()


## Régénération des PV : délai et vitesse (le Bastion a la sienne, plus rapide).
func health_regen_delay() -> float:
	return _fx.health_regen_delay()


func health_regen_rate() -> float:
	return _fx.health_regen_rate()


## XP manquante pour le niveau suivant (-1 au niveau max).
func xp_for_next_level() -> int:
	if level - 1 >= Config.economy.kit_level_xp.size():
		return -1
	return Config.economy.kit_level_xp[level - 1]


## Change de kit (menu admin) : niveau 1, PV et bouclier pleins.
func server_set_kit(id: String) -> bool:
	return _srv.set_kit(id)


func server_add_xp(amount: int) -> void:
	_srv.add_xp(amount)


func _server_on_match_reset() -> void:
	level = 1
	xp = 0
	_srv.apply_stats(true)


## Mod équipé : { id, effect, effects, unlock_level }, ou {}.
func get_mod() -> Dictionary:
	return _fx.get_mod()


## Le mod `id` de ce kit est-il débloqué pour ce joueur (réputation de la faction du kit) ?
static func mod_unlocked(peer: int, kit: KitData, id: String) -> bool:
	return KitControllerEffects.mod_unlocked(peer, kit, id)


## Serveur : équipe un mod du kit actuel ("" = aucun), s'il est débloqué. PV / bouclier
## recalculés (ex. +200 bouclier).
func server_set_mod(id: String) -> void:
	_srv.set_mod(id)
