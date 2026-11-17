class_name KitController
extends Node
## Kit (combinaison) d'un joueur : PV, bouclier, vitesse, capacités de mouvement, niveau.
## Créé en code par le Player sur tous les peers (nœud « Kit », autorité serveur).
##
## Serveur : choisit le kit (au largage, à la réapparition, ou par le menu admin), donne
## l'XP (joueurs tués, monstres tués, points d'objectif et Fame gagnés), fait monter le
## niveau (1 à 6, Config.KIT_LEVEL_XP) et applique PV / bouclier à la Health.
## kit_id, level et xp sont envoyés à tous (KitSync) : chaque peer calcule les mêmes bonus.
## Bonus de niveau : KitData.level_perk_effects[0 .. level-1] (index 0 = niveau 1, actif
## dès le départ). Tout est remis à zéro à chaque partie.

signal changed
signal leveled_up(level: int)

const KITS_DIR := "res://data/kits/"
const EQUIPMENT_UI_SCRIPT := preload("res://systems/kits/equipment_ui.gd")

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

var player: Player
var _kit: KitData
# --- Serveur ---
var _change_until_ms: int = 0   # le kit peut être changé jusqu'à ce moment


func _init() -> void:
	var config := SceneReplicationConfig.new()
	for key in ["kit_id", "level", "xp"]:
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
		player.health.dead_changed.connect(func(dead: bool) -> void:
			if not dead:
				_open_change_window())
		Events.match_reset_requested.connect(_server_on_match_reset)
		Events.monster_killed.connect(_on_monster_killed)
		Events.player_died.connect(_on_player_died)
		kit_id = String(Config.DEFAULT_KIT)
		_server_apply_stats(true)
		_open_change_window()
	if player.is_multiplayer_authority():
		var ui: Node = EQUIPMENT_UI_SCRIPT.new()
		add_child(ui)
		ui.setup(player, self)


## Kit actuel (celui par défaut tant que rien n'est reçu).
func get_kit() -> KitData:
	if _kit == null:
		var id := kit_id if kit_id != "" else String(Config.DEFAULT_KIT)
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
	var kit := get_kit()
	var total := 0.0
	if kit == null:
		return total
	for i in mini(level, kit.level_perk_effects.size()):
		total += float(kit.level_perk_effects[i].get(effect, 0.0))
	return total


## Paramètre d'une capacité de mouvement (KitData.movement), ou `default`.
func move_param(ability: String, key: String, default: float) -> float:
	var kit := get_kit()
	if kit == null or not kit.movement.has(ability):
		return default
	var block: Dictionary = kit.movement[ability]
	return float(block.get(key, default))


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
	var kit := get_kit()
	var base := kit.health if kit and kit.health > 0.0 else Config.KIT_DEFAULT_HEALTH
	return base + get_effect("max_health_add")


func max_shield() -> float:
	var kit := get_kit()
	var base := kit.shield if kit and kit.shield > 0.0 else Config.KIT_DEFAULT_SHIELD
	return base + get_effect("max_shield_add")


## Vitesse de marche (m/s) ; le sprint la multiplie par Config.SPRINT_MULTIPLIER.
func move_speed() -> float:
	var kit := get_kit()
	var base := kit.move_speed_mps if kit and kit.move_speed_mps > 0.0 else Config.KIT_DEFAULT_SPEED
	return base * (1.0 + get_effect("move_speed_mult"))


## Régénération des PV : délai et vitesse (le Bastion a la sienne, plus rapide).
func health_regen_delay() -> float:
	var delay := move_param("fast_health_regen", "health_regen_delay_s", Config.HEALTH_REGEN_DELAY)
	return delay * (1.0 + get_effect("health_regen_delay_mult"))


func health_regen_rate() -> float:
	var rate := move_param("fast_health_regen", "health_regen_per_s", Config.HEALTH_REGEN_RATE)
	return rate * (1.0 + get_effect("health_regen_mult"))


## XP manquante pour le niveau suivant (-1 au niveau max).
func xp_for_next_level() -> int:
	if level - 1 >= Config.KIT_LEVEL_XP.size():
		return -1
	return Config.KIT_LEVEL_XP[level - 1]


## Secondes restantes pour changer de kit (0 = fermé). Approximation côté client.
func can_change_kit_now() -> bool:
	return player.health.is_dead or Time.get_ticks_msec() < _change_until_ms


# =========================================================================
# Serveur
# =========================================================================

func _open_change_window() -> void:
	_change_until_ms = Time.get_ticks_msec() + int(Config.KIT_CHANGE_WINDOW * 1000.0)
	_notify_change_window.rpc_id(player.get_peer_id(), Config.KIT_CHANGE_WINDOW)


## Menu Équipement : le joueur demande un kit (au largage / à la réapparition seulement).
@rpc("any_peer", "call_local", "reliable")
func request_kit(id: String) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player.get_peer_id():
		return
	if not (player.health.is_dead or Time.get_ticks_msec() < _change_until_ms):
		_kit_result.rpc_id(player.get_peer_id(), false, "Changement de kit seulement au largage ou à la réapparition")
		return
	if server_set_kit(id):
		_kit_result.rpc_id(player.get_peer_id(), true, "Kit équipé : %s" % get_display_name())


## Change de kit (menu Équipement ou admin) : niveau 1, PV et bouclier pleins.
func server_set_kit(id: String) -> bool:
	if not ResourceLoader.exists(KITS_DIR + id + ".tres") or (load(KITS_DIR + id + ".tres") as KitData) == null:
		return false
	kit_id = id
	level = 1
	xp = 0
	_server_apply_stats(true)
	print("[Kit] Joueur %d : %s" % [player.get_peer_id(), get_display_name()])
	return true


func server_add_xp(amount: int) -> void:
	if not multiplayer.is_server() or amount <= 0 or player.is_evacuated:
		return
	xp += amount
	while xp_for_next_level() > 0 and xp >= xp_for_next_level():
		level += 1
		_server_apply_stats(false)
		var perk := ""
		var kit := get_kit()
		if kit and level - 1 < kit.level_perks.size():
			perk = " : " + kit.level_perks[level - 1]
		player.score.notify.rpc_id(player.get_peer_id(), "%s niveau %d%s" % [get_display_name(), level, perk], Color(0.6, 1.0, 0.7))
		leveled_up.emit(level)


## PV / bouclier max du kit sur la Health. `refill` : tout plein ; sinon le gain de max
## s'ajoute aux valeurs actuelles.
func _server_apply_stats(refill: bool) -> void:
	player.health.server_apply_kit(max_health(), max_shield(), refill)


func _server_on_match_reset() -> void:
	level = 1
	xp = 0
	_server_apply_stats(true)
	_open_change_window()


func _on_monster_killed(_monster_id: StringName, killer_id: int) -> void:
	if killer_id == player.get_peer_id():
		server_add_xp(Config.KIT_XP_MONSTER_KILL)


func _on_player_died(victim_id: int, killer_id: int) -> void:
	if killer_id == player.get_peer_id() and victim_id != killer_id:
		server_add_xp(Config.KIT_XP_PLAYER_KILL)


# =========================================================================
# Client propriétaire
# =========================================================================

signal kit_result(ok: bool, message: String)


@rpc("any_peer", "call_local", "reliable")
func _kit_result(ok: bool, message: String) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	kit_result.emit(ok, message)


@rpc("any_peer", "call_local", "reliable")
func _notify_change_window(seconds: float) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	_change_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)
