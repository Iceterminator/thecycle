class_name Monster
extends CharacterBody3D
## Monstre PvE. Créé par le serveur (MonsterManager -> MonsterSpawner, spawn_function),
## construit en code à partir d'un MonsterData.
## Toute l'IA tourne sur le SERVEUR. Les clients reçoivent position, rotation, PV et
## état via le MonsterSync (autorité serveur), et s'en servent seulement pour l'affichage.
##
## IA (DESIGN §7) : patrouille -> poursuite -> préparation / coup -> retour au camp.
## Couche physique 3 (« monstres »). Groupe "damageable" : touchable par les armes.
##
## Cible : un joueur, ou un `objective` (ex. foreuse d'un cristal) pour les monstres de
## vague. Toute cible a can_be_hit() et server_receive_hit() ; get_hit_radius() optionnel.
## Un monstre de vague attaque son objectif, riposte si on lui tire dessus, puis y revient.
##
## Monstre à distance (data.ranged, ex. Cracheur) : s'arrête à portée de tir avec ligne
## de vue, recule si on l'approche à moins de data.min_range, et crache un projectile
## lent (simulé par le serveur, visible chez tous) qu'on peut esquiver.
## Niveau (1 à 3, donné à l'apparition) : PV, dégâts et crédits multipliés (Config).
## Dans la tempête : détection et vitesse de course × Config.match_rules.storm_monster_mult.

## Détail découpé : monster_ai (états, patrouille), monster_combat_ai (poursuite, coups),
## monster_motion (déplacement, vue), monster_projectiles, monster_dots, monster_visual.

const MonsterAi := preload("res://systems/monsters/monster_ai.gd")
const MonsterCombatAi := preload("res://systems/monsters/monster_combat_ai.gd")
const MonsterMotion := preload("res://systems/monsters/monster_motion.gd")
const MonsterProjectiles := preload("res://systems/monsters/monster_projectiles.gd")
const MonsterDots := preload("res://systems/monsters/monster_dots.gd")
const MonsterVisual := preload("res://systems/monsters/monster_visual.gd")
const MonsterDeath := preload("res://systems/monsters/monster_death.gd")

enum State { PATROL, CHASE, WINDUP, RECOVER, RETURN }

const SCAN_INTERVAL := 0.3      ## recherche de joueurs en patrouille (s)
const REPATH_INTERVAL := 0.25   ## recalcul du chemin en poursuite (s)
const DIRECT_CHASE_DIST := 3.0  ## en dessous, on fonce droit sur la cible
const CONTACT_RATIO := 0.6      ## sous attack_range × ce ratio, il s'arrête (ne pousse pas)
const LUNGE_SPEED_RATIO := 1.0  ## vitesse pendant la préparation (× run_speed) : on ne le distance pas en marchant
const HIT_RANGE_RATIO := 1.5    ## le coup touche jusqu'à attack_range × ce ratio
const MISS_RECOVERY := 0.3      ## pause après un coup raté (s)
const BACK_OFF_SPEED_RATIO := 0.6  ## recul pendant la pause après un coup (× walk_speed)


var data: MonsterData

## Synchronisés (serveur -> clients).
var max_health: float = 1.0
var health: float = 0.0:
	set(value):
		health = value
		if is_node_ready():
			_visual.update_bar()
var state: int = State.PATROL:
	set(value):
		state = value
		if is_node_ready():
			_visual.update_look()

# --- Serveur uniquement ---
var camp: MonsterCamp
var players_root: Node
var home: Vector3
var objective: Node3D          ## monstre de vague : ce qu'il doit détruire
var damage_mult: float = 1.0   ## vagues difficiles et niveau : coups plus forts
var credits_mult: float = 1.0  ## niveau : crédits versés au tueur
var _had_objective: bool = false
var _agent: NavigationAgent3D
var _target: Node3D
var _repath_left: float = 0.0
var _state_left: float = 0.0
var _pause_left: float = 0.0  ## pause après un coup réussi (recule un peu, ne colle pas)
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Aides (voir l'en-tête) ---
var _ai: MonsterAi = MonsterAi.new(self)
var _combat_ai: MonsterCombatAi = MonsterCombatAi.new(self)
var _motion: MonsterMotion = MonsterMotion.new(self)
var _projectiles: MonsterProjectiles = MonsterProjectiles.new(self)
var _dots: MonsterDots = MonsterDots.new(self)
var _visual: MonsterVisual = MonsterVisual.new(self)

## Niveau du monstre (1 à 3), connu de tous (affiché au-dessus de lui).
var level: int = 1


## Appelé par la spawn_function, sur tous les peers, avant l'entrée dans l'arbre.
func setup(monster_data: MonsterData, health_mult: float = 1.0, monster_level: int = 1) -> void:
	data = monster_data
	level = monster_level
	max_health = data.max_health * health_mult
	health = max_health
	collision_layer = 1 << 2
	collision_mask = 1 | (1 << 1) | (1 << 2)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = data.radius
	capsule.height = data.height
	shape.shape = capsule
	shape.position.y = data.height / 2.0
	add_child(shape)
	_visual.build()
	_build_sync()


func _ready() -> void:
	add_to_group("damageable")
	_visual.update_bar()
	_visual.update_look()
	if not multiplayer.is_server():
		set_physics_process(false)
		return
	home = global_position
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.6
	_agent.radius = data.radius
	_agent.height = data.height
	add_child(_agent)
	_ai.idle_left = randf_range(0.5, 2.5)


# =========================================================================
# Interface « damageable » (appelée par Weapon, côté serveur)
# =========================================================================

func can_be_hit() -> bool:
	return health > 0.0


func is_headshot(point: Vector3) -> bool:
	return point.y >= global_position.y + data.height * 0.75


## Serveur : renvoie true si le coup tue le monstre.
func server_receive_hit(amount: float, attacker_id: int) -> bool:
	if health <= 0.0:
		return false
	health = maxf(health - amount, 0.0)
	var attacker := players_root.get_node_or_null(str(attacker_id)) as Player if players_root else null
	if attacker and attacker.can_be_hit():
		aggro(attacker, true)
	if health <= 0.0:
		_die(attacker_id)
		return true
	return false


# =========================================================================
# IA (serveur)
# =========================================================================

## Monstre de vague : fonce sur son objectif dès son apparition.
func aggro_objective() -> void:
	_had_objective = true
	if is_instance_valid(objective):
		_target = objective
		state = State.CHASE
		_repath_left = 0.0


## Prend `player` pour cible. `alert_camp` : prévient le reste de la meute.
func aggro(player: Player, alert_camp: bool) -> void:
	if health <= 0.0:
		return
	_target = player
	if state == State.PATROL or state == State.RETURN:
		state = State.CHASE
		_repath_left = 0.0
	if alert_camp and camp:
		camp.alert(player, self)



func _physics_process(delta: float) -> void:
	if global_position.y < Config.KILL_Y:
		_die(0)  # tombé hors de la carte : pas de crédits
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	_ai.step(delta)
	_motion.move_body(delta)
	if not _projectiles.is_empty():
		_projectiles.step(delta)
	_dots.tick(delta)


func _die(killer_id: int) -> void:
	MonsterDeath.die(self, killer_id)



## Animation du modèle d'après le déplacement observé et l'état synchronisé (tous les peers).
func _process(delta: float) -> void:
	_visual.animate(delta)


func _build_sync() -> void:
	var config := SceneReplicationConfig.new()
	var props := {
		".:position": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
		".:rotation": SceneReplicationConfig.REPLICATION_MODE_ALWAYS,
		".:max_health": SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE,
		".:health": SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE,
		".:state": SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE,
	}
	for key: String in props:
		var path := NodePath(key)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, props[key])
	var sync := MultiplayerSynchronizer.new()
	sync.name = "MonsterSync"
	sync.replication_config = config
	add_child(sync)



@rpc("authority", "call_local", "unreliable")
func _show_projectile(id: int, from: Vector3, dir: Vector3, speed: float, max_dist: float) -> void:
	_projectiles.show_visual(id, from, dir, speed, max_dist)


@rpc("authority", "call_local", "reliable")
func _end_projectile(id: int, _point: Vector3) -> void:
	_projectiles.free_visual(id)


func _exit_tree() -> void:
	_projectiles.free_all_visuals()


## Serveur : ralentissement temporaire (capacité Entrave).
func apply_slow(mult: float, duration: float) -> void:
	_motion.apply_slow(mult, duration)


## Dégâts sur la durée (mods d'arme feu / poison).
func apply_dot(per_s: float, duration: float, attacker_id: int) -> void:
	_dots.apply_dot(per_s, duration, attacker_id)
