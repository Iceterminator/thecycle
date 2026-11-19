class_name BuffController
extends Node
## Bonus / malus temporaires d'un joueur (étape 8c) : vitesse, dégâts subis, PV max,
## régénération, soin continu, camouflage, invulnérabilité, recul. Décidés par le SERVEUR
## (capacités, pièges), envoyés à tous (BuffSync) : chaque peer en tire les mêmes effets
## (vitesse côté client, dégâts côté serveur, transparence du camouflage chez les autres).
## Créé en code par le Player sur tous les peers (nœud « Buffs », autorité serveur).
##
## Effets connus (clé -> combinaison) : speed_mult, damage_taken_mult, health_regen_mult,
## recoil_mult (produit) ; max_health_add, heal_per_s (somme) ; cloak, cloak_moving,
## cloak_breaks_on_fire, invulnerable, no_health_regen, regen_now (maximum).

const Dots := preload("res://systems/abilities/buff_controller_dots.gd")
const DOT_TICK := Dots.DOT_TICK

signal changed

## Synchronisé : id -> { "mods": {…}, "dur": durée totale, "name": nom affiché }.
var active: Dictionary = {}:
	set(value):
		if value == active:
			return
		active = value
		_received_ms = Time.get_ticks_msec()
		_started_ms.clear()
		for id: String in active:
			_started_ms[id] = _received_ms - int(active[id].get("elapsed", 0.0) * 1000.0)
		changed.emit()

var player: Player
var _received_ms: int = 0
var _started_ms: Dictionary = {}   # client : id -> début estimé
# --- Serveur ---
var _ends: Dictionary = {}         # id -> fin (ms)
var _after: Dictionary = {}        # id -> [mods, durée, nom] à appliquer à la fin
var _dots: Dots


func _init() -> void:
	var config := SceneReplicationConfig.new()
	var path := NodePath(".:active")
	config.add_property(path)
	config.property_set_spawn(path, true)
	# ALWAYS : un joueur qui arrive en cours de partie reçoit aussi les effets en cours.
	config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "BuffSync"
	sync.replication_config = config
	add_child(sync)


func _ready() -> void:
	player = get_parent() as Player
	_dots = Dots.new(self)
	set_physics_process(multiplayer.is_server())
	if multiplayer.is_server():
		player.health.dead_changed.connect(func(dead: bool) -> void:
			if dead:
				server_clear())
		Events.match_reset_requested.connect(server_clear)


# =========================================================================
# Lecture (tous les peers)
# =========================================================================

func get_mult(key: String) -> float:
	var total := 1.0
	for id: String in active:
		total *= float(active[id]["mods"].get(key, 1.0))
	return total


func get_add(key: String) -> float:
	var total := 0.0
	for id: String in active:
		total += float(active[id]["mods"].get(key, 0.0))
	return total


func get_max(key: String) -> float:
	var best := 0.0
	for id: String in active:
		best = maxf(best, float(active[id]["mods"].get(key, 0.0)))
	return best


## Camouflage actuel (0 = visible, 1 = invisible) ; plus faible en courant si l'effet le dit.
func get_cloak(horizontal_speed: float) -> float:
	var cloak := get_max("cloak")
	if cloak <= 0.0:
		return 0.0
	var moving := get_max("cloak_moving")
	if moving > 0.0 and horizontal_speed > Config.combat.kit_default_speed * 1.2:
		return minf(cloak, moving)
	return cloak


## Secondes restantes d'un effet (estimation côté client).
func remaining(id: String) -> float:
	if not active.has(id):
		return 0.0
	var start: int = _started_ms.get(id, _received_ms)
	return maxf(float(active[id]["dur"]) - (Time.get_ticks_msec() - start) / 1000.0, 0.0)


## Texte du HUD : « Stimulant 3 s, Entrave 2 s ».
func status_text() -> String:
	var parts: PackedStringArray = []
	for id: String in active:
		parts.append("%s %d s" % [active[id].get("name", id), ceili(remaining(id))])
	return ", ".join(parts)


# =========================================================================
# Serveur
# =========================================================================

## Ajoute (ou relance) un effet pour `duration` s ; `after` s'applique à sa fin.
func server_add(id: String, display_name: String, mods: Dictionary, duration: float,
		after: Dictionary = {}, after_duration: float = 0.0) -> void:
	if not multiplayer.is_server() or mods.is_empty() or duration <= 0.0:
		return
	_ends[id] = Time.get_ticks_msec() + int(duration * 1000.0)
	if not after.is_empty() and after_duration > 0.0:
		_after[id] = [after, after_duration, display_name]
	else:
		_after.erase(id)
	var d := active.duplicate(true)
	d[id] = {"mods": mods, "dur": duration, "name": display_name, "elapsed": 0.0}
	active = d


func server_remove(id: String, apply_after: bool = true) -> void:
	if not active.has(id):
		return
	_ends.erase(id)
	var d := active.duplicate(true)
	d.erase(id)
	active = d
	if apply_after and _after.has(id):
		var after: Array = _after[id]
		_after.erase(id)
		server_add(id + "_apres", after[2] + " (contrecoup)", after[0], after[1])
	# Fin d'un bonus de PV max : on ne garde pas plus de PV que le nouveau max.
	player.health.health = minf(player.health.health, player.health.get_max_health())


## Retire tous les effets qui ont cette clé (ex. camouflage cassé par un tir).
func server_remove_with(key: String) -> void:
	for id: String in active.keys():
		if float(active[id]["mods"].get(key, 0.0)) > 0.0:
			server_remove(id)


func server_clear() -> void:
	_ends.clear()
	_after.clear()
	active = {}


func _physics_process(delta: float) -> void:
	_dots.tick(delta)
	if active.is_empty():
		return
	var now := Time.get_ticks_msec()
	for id: String in _ends.keys():
		if now >= _ends[id]:
			server_remove(id)
	# Soin continu (aura de soin).
	var heal := get_add("heal_per_s")
	if heal > 0.0 and not player.health.is_dead:
		player.health.heal(heal * delta)


## Serveur : brûlure / poison. Un nouveau coup relance la durée (pas de cumul infini).
func server_add_dot(id: String, display_name: String, per_s: float, duration: float,
		ignore_shield: bool, attacker_id: int) -> void:
	_dots.add_dot(id, display_name, per_s, duration, ignore_shield, attacker_id)
