class_name KitController
extends Node
## Kit (combinaison) d'un joueur : PV, bouclier, vitesse, capacités de mouvement, niveau.
## Créé en code par le Player sur tous les peers (nœud « Kit », autorité serveur).
##
## Serveur : choisit le kit (au largage, à la réapparition, ou par le menu admin), donne
## l'XP (joueurs tués, monstres tués, points d'objectif et Fame gagnés), fait monter le
## niveau (1 à 6, Config.economy.kit_level_xp) et applique PV / bouclier à la Health.
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
## Mod de kit équipé (id dans KitData.mods, "" = aucun) ; choisi dans le lobby (étape 9).
var mod_id: String = "":
	set(value):
		mod_id = value
		changed.emit()

var player: Player
var _kit: KitData
# --- Serveur ---
var _change_until_ms: int = 0   # le kit peut être changé jusqu'à ce moment


func _init() -> void:
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
		player.health.dead_changed.connect(func(dead: bool) -> void:
			if not dead:
				_open_change_window())
		Events.match_reset_requested.connect(_server_on_match_reset)
		Events.monster_killed.connect(_on_monster_killed)
		Events.player_died.connect(_on_player_died)
		kit_id = String(Config.start_loadout.default_kit)
		_server_apply_stats(true)
		# Le client n'a pas encore ce joueur à cet instant : un RPC tout de suite serait perdu (erreur « Node not found »).
		get_tree().create_timer(1.0).timeout.connect(_open_change_window)
	if player.is_multiplayer_authority():
		var ui: Node = EQUIPMENT_UI_SCRIPT.new()
		add_child(ui)
		ui.setup(player, self)


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
	var kit := get_kit()
	var total := 0.0
	if kit == null:
		return total
	for i in mini(level, kit.level_perk_effects.size()):
		total += float(kit.level_perk_effects[i].get(effect, 0.0))
	# Mod équipé.
	var mod := get_mod()
	if not mod.is_empty():
		total += float(mod.get("effects", {}).get(effect, 0.0))
	return total


## Paramètre d'une capacité de mouvement (KitData.movement). Sans `default`, la valeur
## doit être dans les données du kit (sinon 0 et un avertissement).
func move_param(ability: String, key: String, default: float = NAN) -> float:
	var kit := get_kit()
	var block: Dictionary = kit.movement.get(ability, {}) if kit else {}
	if block.has(key):
		return float(block[key])
	if is_nan(default):
		if not block.is_empty():
			push_warning("[Kit] %s.%s absent des données du kit" % [ability, key])
		return 0.0
	return default


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
	var base := kit.health if kit and kit.health > 0.0 else Config.combat.kit_default_health
	return base + get_effect("max_health_add")


func max_shield() -> float:
	var kit := get_kit()
	var base := kit.shield if kit and kit.shield > 0.0 else Config.combat.kit_default_shield
	return base + get_effect("max_shield_add")


## Vitesse de marche (m/s) ; le sprint la multiplie par Config.combat.sprint_multiplier.
func move_speed() -> float:
	var kit := get_kit()
	var base := kit.move_speed_mps if kit and kit.move_speed_mps > 0.0 else Config.combat.kit_default_speed
	base += get_effect("move_speed_add")
	return base * (1.0 + get_effect("move_speed_mult"))


## Régénération des PV : délai et vitesse (le Bastion a la sienne, plus rapide).
func health_regen_delay() -> float:
	var delay := move_param("fast_health_regen", "health_regen_delay_s", Config.combat.health_regen_delay)
	return delay * (1.0 + get_effect("health_regen_delay_mult"))


func health_regen_rate() -> float:
	var rate := move_param("fast_health_regen", "health_regen_per_s", Config.combat.health_regen_rate)
	return rate * (1.0 + get_effect("health_regen_mult"))


## XP manquante pour le niveau suivant (-1 au niveau max).
func xp_for_next_level() -> int:
	if level - 1 >= Config.economy.kit_level_xp.size():
		return -1
	return Config.economy.kit_level_xp[level - 1]


## Secondes restantes pour changer de kit (0 = fermé). Approximation côté client.
func can_change_kit_now() -> bool:
	return player.health.is_dead or Time.get_ticks_msec() < _change_until_ms


# =========================================================================
# Serveur
# =========================================================================

func _open_change_window() -> void:
	_change_until_ms = Time.get_ticks_msec() + int(Config.match_rules.kit_change_window * 1000.0)
	_notify_change_window.rpc_id(player.get_peer_id(), Config.match_rules.kit_change_window)


## Menu Équipement : le joueur demande un kit (au largage / à la réapparition seulement).
@rpc("any_peer", "call_local", "reliable")
func request_kit(id: String) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player.get_peer_id():
		return
	var wanted: KitData = load(KITS_DIR + id + ".tres") as KitData if ResourceLoader.exists(KITS_DIR + id + ".tres") else null
	if wanted and not ProfileManager.is_unlocked(player.get_peer_id(), wanted.faction, wanted.faction_level):
		_kit_result.rpc_id(player.get_peer_id(), false, "Kit verrouillé : " + FactionData.lock_text(wanted.faction, wanted.faction_level))
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
	mod_id = ""
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
		server_add_xp(Config.economy.kit_xp_monster_kill)


func _on_player_died(victim_id: int, killer_id: int) -> void:
	if killer_id == player.get_peer_id() and victim_id != killer_id:
		server_add_xp(Config.economy.kit_xp_player_kill)


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


# =========================================================================
# Mods de kit (étape 9)
# =========================================================================

## Mod équipé : { id, effect, effects, unlock_level }, ou {}.
func get_mod() -> Dictionary:
	var kit := get_kit()
	if kit == null or mod_id == "":
		return {}
	for m: Dictionary in kit.mods:
		if String(m.get("id", "")) == mod_id:
			return m
	return {}


## Le mod `id` de ce kit est-il débloqué pour ce joueur (réputation de la faction du kit) ?
static func mod_unlocked(peer: int, kit: KitData, id: String) -> bool:
	if kit == null:
		return false
	for m: Dictionary in kit.mods:
		if String(m.get("id", "")) == id:
			return ProfileManager.is_unlocked(peer, kit.faction, int(m.get("unlock_level", 0)))
	return false


## Serveur : équipe un mod du kit actuel ("" = aucun), s'il est débloqué. PV / bouclier
## recalculés (ex. +200 bouclier).
func server_set_mod(id: String) -> void:
	if id != "" and not mod_unlocked(player.get_peer_id(), get_kit(), id):
		id = ""
	if id == mod_id:
		return
	mod_id = id
	_server_apply_stats(false)
