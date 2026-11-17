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
## Id du dernier tueur (0 = aucun). Synchronisé AVANT is_dead pour que le HUD l'ait.
var killer_id: int = 0
var is_dead: bool = false:
	set(value):
		if value == is_dead:
			return
		is_dead = value
		dead_changed.emit(value)

var _regen_cooldown: float = 0.0


func _ready() -> void:
	max_shield = Config.SHIELD_PER_TIER[Config.STARTING_SHIELD_TIER]
	shield = max_shield
	# La recharge du bouclier n'est calculée que par le serveur.
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
	_regen_cooldown = Config.SHIELD_REGEN_DELAY
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


## Serveur uniquement : remet le joueur sur pied (réapparition).
func revive() -> void:
	health = Config.MAX_HEALTH
	shield = max_shield
	killer_id = 0
	_regen_cooldown = 0.0
	is_dead = false


func _physics_process(delta: float) -> void:
	if is_dead or shield >= max_shield:
		return
	_regen_cooldown -= delta
	if _regen_cooldown <= 0.0:
		shield = minf(shield + Config.SHIELD_REGEN_RATE * delta, max_shield)
