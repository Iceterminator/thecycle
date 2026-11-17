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

signal changed
signal dead_changed(dead: bool)

var health: float = Config.KIT_DEFAULT_HEALTH:
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
var _applied_max_health: float = Config.KIT_DEFAULT_HEALTH


func _ready() -> void:
	max_shield = Config.KIT_DEFAULT_SHIELD
	shield = max_shield
	# La régénération n'est calculée que par le serveur.
	set_physics_process(multiplayer.is_server())


func get_peer_id() -> int:
	return get_parent().name.to_int()


func _kit() -> KitController:
	return get_parent().get_node_or_null("Kit") as KitController


func get_max_health() -> float:
	var kit := _kit()
	return kit.max_health() if kit else Config.KIT_DEFAULT_HEALTH


## Serveur : nouveau kit ou niveau. `refill` : tout plein ; sinon le gain de max s'ajoute.
func server_apply_kit(new_max_health: float, new_max_shield: float, refill: bool) -> void:
	if refill or is_dead:
		health = new_max_health
		max_shield = new_max_shield
		shield = new_max_shield
	else:
		health = clampf(health + new_max_health - _applied_max_health, 1.0, new_max_health)
		var gain := new_max_shield - max_shield
		max_shield = new_max_shield
		shield = clampf(shield + gain, 0.0, new_max_shield)
	_applied_max_health = new_max_health


## Serveur uniquement. Le bouclier absorbe d'abord, le reste passe sur les PV.
## Renvoie true si ce coup a tué le joueur.
func apply_damage(amount: float, attacker_id: int, shield_mult: float = 1.0, health_mult: float = 1.0) -> bool:
	if not multiplayer.is_server():
		push_error("[Health] apply_damage appelé hors du serveur")
		return false
	if is_dead or amount <= 0.0:
		return false
	# Défense du kit contre les créatures (bonus de niveau).
	var kit := _kit()
	if kit and attacker_id == Config.MONSTER_KILLER_ID:
		amount *= maxf(1.0 - kit.get_effect("creature_defense"), 0.0)
	_since_damage = 0.0
	# Le bouclier prend d'abord (dégâts x shield_mult), le reste passe sur les PV (x health_mult)
	# (ex. fusil à pompe plus mortel une fois le bouclier tombé).
	var absorbed := minf(shield, amount * shield_mult)
	shield -= absorbed
	var rest := amount - absorbed / maxf(shield_mult, 0.001)
	health = maxf(health - rest * health_mult, 0.0)
	Events.player_damaged.emit(get_peer_id(), amount, attacker_id)
	if health <= 0.0:
		killer_id = attacker_id
		is_dead = true
		print("[Combat] Joueur %d tué par %d" % [get_peer_id(), attacker_id])
		Events.player_died.emit(get_peer_id(), attacker_id)
		return true
	return false


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
	var kit := _kit()
	if kit:
		max_shield = kit.max_shield()
	health = get_max_health()
	_applied_max_health = health
	shield = max_shield
	killer_id = 0
	_since_damage = 0.0
	is_dead = false


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# Tombé sous la carte : mort (le serveur a la position envoyée par le client).
	var body := get_parent() as Player
	if body and not body.is_evacuated and body.global_position.y < Config.KILL_Y:
		apply_damage(health + shield + 1.0, Config.FALL_KILLER_ID)
		return
	_since_damage += delta
	if _since_damage >= Config.SHIELD_REGEN_DELAY and shield < max_shield:
		shield = minf(shield + Config.SHIELD_REGEN_RATE * delta, max_shield)
	var kit := _kit()
	var max_health := get_max_health()
	var delay := kit.health_regen_delay() if kit else Config.HEALTH_REGEN_DELAY
	var rate := kit.health_regen_rate() if kit else Config.HEALTH_REGEN_RATE
	if _since_damage >= delay and health < max_health:
		health = minf(health + rate * delta, max_health)


## Serveur : nouvelle partie. Tout plein (le kit est remis au niveau 1 par le KitController).
func server_reset() -> void:
	revive()
