class_name KitMovement
extends Node
## Capacités de mouvement du kit (étape 8b), selon KitData.mobility_type, plus la
## glissade commune à tous les kits. Valeurs dans KitData.movement (référence).
##
## Le déplacement est décidé par le client propriétaire (règle 2, exception) : ce nœud
## modifie la vitesse du Player dans son _physics_process. Ce qui fait des dégâts
## (plongée du Martinet, coup de poing du Bastion) est DEMANDÉ au serveur, qui vérifie la
## recharge et la position puis applique. Créé en code par le Player sur tous les peers
## (nœud « Movement ») pour que les RPC aient le même chemin partout.
##
## Ce nœud garde l'API publique, l'état partagé et les RPC ; la logique par capacité est
## dans les helpers kit_movement_*.gd :
## - jet (Martinet, Kit de prospecteur) : jetpack, plongée, propulseurs.
## - dash (Furet) : charges d'énergie, double saut, esquive.
## - bastion : super saut (maintenir Saut au sol), coup de poing chargé (V).
## - slide (tous) : Accroupi pendant un sprint ; Saut pendant la glissade = élan.
## - server : dégâts et vérifications côté serveur.

const KitMovementSlide := preload("res://systems/kits/kit_movement_slide.gd")
const KitMovementJet := preload("res://systems/kits/kit_movement_jet.gd")
const KitMovementDash := preload("res://systems/kits/kit_movement_dash.gd")
const KitMovementBastion := preload("res://systems/kits/kit_movement_bastion.gd")
const KitMovementServer := preload("res://systems/kits/kit_movement_server.gd")

const DODGE_ACTIVATION_HOLD := 0.2   ## jetpack : Saut maintenu avant la poussée (s)
const SUPER_JUMP_TAP := 0.15         ## super saut : en dessous, c'est un saut normal (s)
const PUNCH_DASH_TIME := 0.25        ## durée de la ruée du coup de poing (s)
const PUNCH_HIT_DELAY := 0.2         ## le serveur frappe un peu après la demande (ruée)

var player: Player
var kit: KitController

# --- Client propriétaire ---
var fuel: float = 0.0
var charges: float = 0.0
var _dash_left: float = 0.0
var _dash_velocity := Vector3.ZERO
var _jump_used: bool = false        ## Saut déjà utilisé ce tour (glissade, esquive…)
var _last_kit_id: String = "?"
var _last_hp: float = -1.0

var _slide: KitMovementSlide
var _jet: KitMovementJet
var _dash: KitMovementDash
var _bastion: KitMovementBastion
var _server: KitMovementServer


func _ready() -> void:
	player = get_parent() as Player
	kit = player.get_node("Kit") as KitController
	_slide = KitMovementSlide.new(self)
	_jet = KitMovementJet.new(self)
	_dash = KitMovementDash.new(self)
	_bastion = KitMovementBastion.new(self)
	_server = KitMovementServer.new(self)
	# Mod « plus de charges mais fragile » : un coup reçu fait perdre une charge.
	player.health.changed.connect(_on_health_changed)


func mobility() -> int:
	var data := kit.get_kit()
	return data.mobility_type if data else KitData.MobilityType.NONE


# =========================================================================
# Client propriétaire : appelé par Player._physics_process
# =========================================================================

## Avant le déplacement : recharges, saut et capacités. Peut changer player.velocity.
func pre_physics(delta: float, input_dir: Vector2) -> void:
	if kit.kit_id != _last_kit_id:
		_reset_for_kit()
	var on_floor := player.is_on_floor()
	_jump_used = false
	_jet.dive_cd = maxf(_jet.dive_cd - delta, 0.0)
	_bastion.super_cd = maxf(_bastion.super_cd - delta, 0.0)
	_bastion.punch_cd = maxf(_bastion.punch_cd - delta, 0.0)
	_slide.cd = maxf(_slide.cd - delta, 0.0)
	_dash_left = maxf(_dash_left - delta, 0.0)
	if on_floor:
		_dash.air_jumps_used = 0
	_slide.process(delta, on_floor, input_dir)
	match mobility():
		KitData.MobilityType.JETPACK:
			_jet.process_jet(delta, on_floor, "jetpack", true)
			_jet.process_dive(on_floor)
		KitData.MobilityType.JETBOOSTERS:
			_jet.process_jet(delta, on_floor, "jetboosters", false)
		KitData.MobilityType.DASH:
			_dash.process(delta, on_floor, input_dir)
		KitData.MobilityType.SUPER_JUMP:
			_bastion.process_super_jump(delta, on_floor)
			_bastion.process_punch(delta)
		_:
			_basic_jump(on_floor)


## Après move_and_slide : fin de plongée à l'atterrissage.
func post_physics() -> void:
	if _jet.diving and player.is_on_floor():
		_jet.on_landed()


## La vitesse horizontale est imposée (glissade, esquive, plongée, ruée) ?
func overrides_horizontal() -> bool:
	return _slide.left > 0.0 or _dash_left > 0.0 or _jet.diving


func is_sliding() -> bool:
	return _slide.left > 0.0


## Part de contrôle en l'air (le jetpack donne un contrôle total pendant la poussée).
func air_control() -> float:
	if _jet.active:
		return kit.move_param("jetpack", "air_control", Config.combat.air_control)
	return Config.combat.air_control


## Vitesse horizontale imposée quand overrides_horizontal() est vrai.
func forced_horizontal() -> Vector3:
	if _jet.diving:
		return Vector3(player.velocity.x, 0, player.velocity.z)
	if _dash_left > 0.0:
		return _dash_velocity
	# Glissade : ralentit jusqu'à la vitesse de marche.
	var t := _slide.left / maxf(_slide.duration(), 0.01)
	return _slide.dir * lerpf(kit.move_speed(), _slide.speed, t)


func _reset_for_kit() -> void:
	_last_kit_id = kit.kit_id
	fuel = _jet.fuel_max()
	charges = _dash.charges_max()
	_jet.diving = false
	_dash_left = 0.0


func _basic_jump(on_floor: bool) -> void:
	if not _jump_used and Input.is_action_just_pressed("jump") and on_floor and not player.is_crouching:
		player.velocity.y = Config.combat.jump_velocity
		_jump_used = true


## Texte du HUD : ressource et recharges de la capacité du kit.
func status_text() -> String:
	match mobility():
		KitData.MobilityType.JETPACK:
			var dive := "prête (Accroupi en l'air)" if _jet.dive_cd <= 0.0 else "%d s" % ceili(_jet.dive_cd)
			return "Jetpack %d %%  —  Plongée %s" % [roundi(100.0 * fuel / maxf(_jet.fuel_max(), 1.0)), dive]
		KitData.MobilityType.JETBOOSTERS:
			return "Propulseurs %d %%" % roundi(100.0 * fuel / maxf(_jet.fuel_max(), 1.0))
		KitData.MobilityType.DASH:
			var full := int(charges)
			return "Énergie %s" % ("■".repeat(full) + "□".repeat(maxi(int(_dash.charges_max()) - full, 0)))
		KitData.MobilityType.SUPER_JUMP:
			var jump := "prêt (maintenir Saut)" if _bastion.super_cd <= 0.0 else "%d s" % ceili(_bastion.super_cd)
			var punch := "prêt (V)" if _bastion.punch_cd <= 0.0 else "%d s" % ceili(_bastion.punch_cd)
			return "Super saut %s  —  Coup de poing %s" % [jump, punch]
	return ""


func _on_health_changed() -> void:
	var hp := player.health.health + player.health.shield
	if _last_hp >= 0.0 and hp < _last_hp - 0.5 and player.is_multiplayer_authority() \
			and kit.get_effect("lose_charge_on_damage") > 0.0:
		charges = maxf(charges - 1.0, 0.0)
	_last_hp = hp


# =========================================================================
# Serveur : les RPC restent ici (chemin du nœud), la logique est dans le helper
# =========================================================================

## Atterrissage d'une plongée : dégâts de zone autour du point (pas sur soi).
@rpc("any_peer", "call_local", "reliable")
func request_dive_impact(pos: Vector3) -> void:
	_server.dive_impact(pos)


## Coup de poing chargé : frappe la cible la plus proche devant soi, après la ruée.
@rpc("any_peer", "call_local", "reliable")
func request_punch(dir: Vector3) -> void:
	_server.punch(dir)


## Mod « esquive blindée » : dégâts subis réduits pendant l'esquive (le serveur l'accorde).
@rpc("any_peer", "call_local", "reliable")
func request_dodge_guard(duration: float) -> void:
	_server.dodge_guard(duration)
