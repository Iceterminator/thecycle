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

## État « à terre » (étape 8e) : à 0 PV, un joueur qui a un allié vivant tombe à terre
## Config.DOWNED_TIME s (PV d'agonie : Config.DOWNED_HEALTH) ; un allié le relève (E),
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
	if not Config.PACT_PARTNER_IS_ALLY:
		return false
	var partner := PactManager.partner_of(get_peer_id())
	var players := get_parent().get_parent()
	var ally := players.get_node_or_null(str(partner)) as Player if partner > 0 and players else null
	return ally != null and not ally.health.is_dead and not ally.health.is_downed and not ally.is_evacuated


## Serveur : relevé par un allié (E maintenu).
func server_revive_downed(by_id: int) -> void:
	if not is_downed or is_dead:
		return
	is_downed = false
	downed_by = 0
	health = get_max_health() * Config.REVIVE_HEALTH_RATIO
	shield = 0.0
	_since_damage = 0.0
	Events.player_revived.emit(get_peer_id(), by_id)


func _ready() -> void:
	max_shield = Config.KIT_DEFAULT_SHIELD
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
	var base := kit.max_health() if kit else Config.KIT_DEFAULT_HEALTH
	return base + (buffs.get_add("max_health_add") if buffs else 0.0)


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
	# Pacte : deux partenaires ne peuvent pas se blesser.
	if PactManager.allied(get_peer_id(), attacker_id):
		return false
	# Défense du kit contre les créatures (bonus de niveau).
	var kit := _kit()
	if kit and attacker_id == Config.MONSTER_KILLER_ID:
		amount *= maxf(1.0 - kit.get_effect("creature_defense"), 0.0)
	# Effets temporaires : Coque (invulnérable), stimulants / camouflages (dégâts subis).
	var buffs := _buffs()
	if buffs:
		if buffs.get_max("invulnerable") > 0.0 and attacker_id != Config.FALL_KILLER_ID:
			return false
		amount *= buffs.get_mult("damage_taken_mult")
	_since_damage = 0.0
	# Le bouclier prend d'abord (dégâts x shield_mult), le reste passe sur les PV (x health_mult)
	# (ex. fusil à pompe plus mortel une fois le bouclier tombé).
	var absorbed := minf(shield, amount * shield_mult)
	shield -= absorbed
	var rest := amount - absorbed / maxf(shield_mult, 0.001)
	health = maxf(health - rest * health_mult, 0.0)
	Events.player_damaged.emit(get_peer_id(), amount, attacker_id)
	if health <= 0.0 and not is_downed and _has_ally_standing() and attacker_id != Config.FALL_KILLER_ID:
		# À terre plutôt que mort : un allié peut venir relever.
		is_downed = true
		downed_by = attacker_id
		_downed_left = Config.DOWNED_TIME
		health = Config.DOWNED_HEALTH
		shield = 0.0
		Events.player_downed.emit(get_peer_id(), attacker_id)
		return false
	if health <= 0.0:
		# Achevé à terre : le kill revient à celui qui l'a mis à terre.
		if is_downed and downed_by != 0:
			attacker_id = downed_by
		is_downed = false
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
	is_downed = false
	downed_by = 0
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
	# À terre : on saigne, pas de régénération ; à la fin, mort (kill pour celui qui l'a mis à terre).
	if is_downed:
		_downed_left -= delta
		if _downed_left <= 0.0:
			_server_bleed_out()
		return
	_since_damage += delta
	if _since_damage >= Config.SHIELD_REGEN_DELAY and shield < max_shield:
		shield = minf(shield + Config.SHIELD_REGEN_RATE * delta, max_shield)
	var kit := _kit()
	var buffs := _buffs()
	var max_health := get_max_health()
	var delay := kit.health_regen_delay() if kit else Config.HEALTH_REGEN_DELAY
	var rate := kit.health_regen_rate() if kit else Config.HEALTH_REGEN_RATE
	if buffs:
		if buffs.get_max("no_health_regen") > 0.0:
			return  # régénération retardée tant que l'effet dure
		if buffs.get_max("regen_now") > 0.0:
			delay = 0.0
		rate *= buffs.get_mult("health_regen_mult")
	if _since_damage >= delay and health < max_health:
		health = minf(health + rate * delta, max_health)


## Serveur : nouvelle partie. Tout plein (le kit est remis au niveau 1 par le KitController).
func server_reset() -> void:
	revive()


## Serveur : fin du temps à terre, mort directe (rien ne peut l'empêcher) ; le kill revient
## à celui qui l'a mis à terre.
func _server_bleed_out() -> void:
	var killer := downed_by
	is_downed = false
	downed_by = 0
	health = 0.0
	shield = 0.0
	killer_id = killer
	is_dead = true
	print("[Combat] Joueur %d mort à terre (mis à terre par %d)" % [get_peer_id(), killer])
	Events.player_died.emit(get_peer_id(), killer)
