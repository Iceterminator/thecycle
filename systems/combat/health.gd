class_name Health
extends Node
## Santé + bouclier d'un joueur.
## SEUL LE SERVEUR modifie ces valeurs. Le nœud HealthSync (autorité serveur,
## voir player.gd::_enter_tree) les envoie à tous les clients.
## Les setters émettent des signaux locaux : le HUD et le joueur s'y branchent.

signal changed
signal dead_changed(dead: bool)

var health: float = Config.MAX_HEALTH:
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
## Palier de bouclier (Config.SHIELD_PER_TIER), amélioré via la boutique.
var shield_tier: int = Config.STARTING_SHIELD_TIER:
	set(value):
		shield_tier = value
		changed.emit()
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


func _ready() -> void:
	max_shield = Config.SHIELD_PER_TIER[shield_tier]
	shield = max_shield
	# La régénération n'est calculée que par le serveur.
	set_physics_process(multiplayer.is_server())


func get_peer_id() -> int:
	return get_parent().name.to_int()


## Serveur uniquement. Le bouclier absorbe d'abord, le reste passe sur les PV.
## Renvoie true si ce coup a tué le joueur.
func apply_damage(amount: float, attacker_id: int) -> bool:
	if not multiplayer.is_server():
		push_error("[Health] apply_damage appelé hors du serveur")
		return false
	if is_dead or amount <= 0.0:
		return false
	_since_damage = 0.0
	var absorbed := minf(shield, amount)
	shield -= absorbed
	health = maxf(health - (amount - absorbed), 0.0)
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
		health = minf(health + amount, Config.MAX_HEALTH)


## Serveur uniquement : recharge de bouclier (cellule).
func restore_shield(amount: float) -> void:
	if not is_dead:
		shield = minf(shield + amount, max_shield)


## Serveur uniquement : nouveau palier de bouclier (amélioration ramassée). Bouclier rempli.
func set_shield_tier(tier: int) -> void:
	shield_tier = clampi(tier, 0, Config.SHIELD_PER_TIER.size() - 1)
	max_shield = Config.SHIELD_PER_TIER[shield_tier]
	if not is_dead:
		shield = max_shield


## Serveur uniquement : remet le joueur sur pied (réapparition).
func revive() -> void:
	if not Config.KEEP_SHIELD_TIER_ON_DEATH:
		set_shield_tier(Config.STARTING_SHIELD_TIER)
	health = Config.MAX_HEALTH
	shield = max_shield
	killer_id = 0
	_since_damage = 0.0
	is_dead = false


## Régénération (valeurs provisoires) : le bouclier remonte de 1/20 de son max par
## seconde après 10 s sans dégâts, les PV de 1 par seconde après 20 s.
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
		shield = minf(shield + max_shield * Config.SHIELD_REGEN_FRACTION * delta, max_shield)
	if _since_damage >= Config.HEALTH_REGEN_DELAY and health < Config.MAX_HEALTH:
		health = minf(health + Config.HEALTH_REGEN_RATE * delta, Config.MAX_HEALTH)


## Serveur : nouvelle partie. Palier de bouclier de départ (les achats sont perdus), plein.
func server_reset() -> void:
	set_shield_tier(Config.STARTING_SHIELD_TIER)
	revive()
