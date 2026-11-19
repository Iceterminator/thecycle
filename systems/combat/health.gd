class_name Health
extends Node
## Santé + bouclier d'un joueur.
## SEUL LE SERVEUR modifie ces valeurs. Le nœud HealthSync (autorité serveur,
## voir player.gd::_enter_tree) les envoie à tous les clients.
## Les setters émettent des signaux locaux : le HUD et le joueur s'y branchent.
##
## PV et bouclier max viennent du kit (KitController, nœud « Kit » du joueur) :
## get_max_health() se calcule pareil sur tous les peers ; max_shield est synchronisé.
## Régénération (référence) : bouclier +90/s après 7 s sans dégâts ; PV +25/s après 7 s
## (le Bastion régénère plus vite, voir son kit). Défense contre les créatures du kit.

const HealthDamage := preload("res://systems/combat/health_damage.gd")
const HealthRegen := preload("res://systems/combat/health_regen.gd")
const HealthServer := preload("res://systems/combat/health_server.gd")

signal changed
signal dead_changed(dead: bool)

var health: float = Config.combat.kit_default_health:
	set(value):
		health = value
		changed.emit()
var shield: float = 0.0:
	set(value):
		shield = value
		changed.emit()
var max_shield: float = 0.0:
	set(value):
		max_shield = value
		changed.emit()
## Ancien palier de bouclier (boutique) : gardé seulement pour la synchro de player.tscn.
var shield_tier: int = Config.STARTING_SHIELD_TIER
## Id du dernier tueur (0 = aucun). Synchronisé AVANT is_dead pour que le HUD l'ait.
var killer_id: int = 0
var is_dead: bool = false:
	set(value):
		if value == is_dead:
			return
		is_dead = value
		dead_changed.emit(value)

## Temps écoulé depuis les derniers dégâts (régénération des PV et du bouclier).
var _since_damage: float = 0.0
## Serveur : PV max appliqués la dernière fois (pour ajouter un gain de niveau aux PV).
var _applied_max_health: float = Config.combat.kit_default_health

## État « à terre » (étape 8e) : à 0 PV, un joueur qui a un allié vivant tombe à terre
## Config.combat.downed_time s (PV d'agonie : Config.combat.downed_health) ; un allié le relève (E),
## un ennemi peut l'achever ; la Fame du kill va à celui qui l'a mis à terre.
## Synchronisé par DownedSync (créé en code ; player.tscn reste inchangé).
signal downed_changed(downed: bool)
var is_downed: bool = false:
	set(value):
		if value == is_downed:
			return
		is_downed = value
		downed_at_ms = Time.get_ticks_msec()
		downed_changed.emit(value)
## Moment local où l'état a changé (compte à rebours du HUD).
var downed_at_ms: int = 0
var downed_by: int = 0
var _downed_left: float = 0.0


func _init() -> void:
	var config := SceneReplicationConfig.new()
	for key in ["is_downed", "downed_by"]:
		var path := NodePath(".:" + key)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "DownedSync"
	sync.replication_config = config
	add_child(sync)


## Un allié vivant, debout et pas embarqué peut-il relever ce joueur ?
func _has_ally_standing() -> bool:
	return HealthServer.has_ally_standing(self)


## Serveur : relevé par un allié (E maintenu).
func server_revive_downed(by_id: int) -> void:
	HealthServer.revive_downed(self, by_id)


func _ready() -> void:
	max_shield = Config.combat.kit_default_shield
	shield = max_shield
	# La régénération n'est calculée que par le serveur.
	set_physics_process(multiplayer.is_server())


func get_peer_id() -> int:
	return get_parent().name.to_int()


func _kit() -> KitController:
	return get_parent().get_node_or_null("Kit") as KitController


func _buffs() -> BuffController:
	return get_parent().get_node_or_null("Buffs") as BuffController


## PV max : ceux du kit, plus les bonus temporaires (ex. Pied ferme +150).
func get_max_health() -> float:
	var kit := _kit()
	var buffs := _buffs()
	var base := kit.max_health() if kit else Config.combat.kit_default_health
	return base + (buffs.get_add("max_health_add") if buffs else 0.0)


## Serveur : nouveau kit ou niveau. `refill` : tout plein ; sinon le gain de max s'ajoute.
func server_apply_kit(new_max_health: float, new_max_shield: float, refill: bool) -> void:
	HealthServer.apply_kit(self, new_max_health, new_max_shield, refill)


## Serveur uniquement. Le bouclier absorbe d'abord, le reste passe sur les PV.
## Renvoie true si ce coup a tué le joueur.
func apply_damage(amount: float, attacker_id: int, shield_mult: float = 1.0, health_mult: float = 1.0) -> bool:
	return HealthDamage.apply(self, amount, attacker_id, shield_mult, health_mult)


## Serveur uniquement : soin (kit de soin).
func heal(amount: float) -> void:
	if not is_dead:
		health = minf(health + amount, get_max_health())


## Serveur uniquement : recharge de bouclier (cellule).
func restore_shield(amount: float) -> void:
	if not is_dead:
		shield = minf(shield + amount, max_shield)


## Serveur uniquement : remet le joueur sur pied (réapparition), PV et bouclier du kit pleins.
func revive() -> void:
	HealthServer.revive(self)


func _physics_process(delta: float) -> void:
	HealthRegen.tick(self, delta)


## Serveur : nouvelle partie. Tout plein (le kit est remis au niveau 1 par le KitController).
func server_reset() -> void:
	revive()

