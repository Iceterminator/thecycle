class_name Monster
extends CharacterBody3D
## Monstre PvE. Créé par le serveur (MonsterManager -> MonsterSpawner, spawn_function),
## construit en code à partir d'un MonsterData. Toute l'IA tourne sur le SERVEUR ; les clients
## reçoivent position, rotation, PV et état via le MonsterSync (autorité serveur) pour l'affichage.
## IA (DESIGN §7) : patrouille -> poursuite -> préparation / coup -> retour au camp.
## Couche physique 3 (« monstres »). Groupe "damageable" : touchable par les armes.
## Cible : un joueur, ou un `objective` (ex. foreuse d'un cristal) pour les monstres de vague
## (can_be_hit(), server_receive_hit(), get_hit_radius() optionnel) ; il riposte si on lui tire dessus.
## À distance (data.ranged, ex. Cracheur) : s'arrête à portée avec ligne de vue, recule sous
## data.min_range, crache un projectile lent (simulé par le serveur) qu'on peut esquiver.
## Niveau (1 à 3) : PV, dégâts, crédits multipliés (Config). Tempête : détection et course × storm_monster_mult.
## Détail : monster_ai (états, aggro), monster_combat_ai, monster_motion, monster_projectiles,
## monster_dots, monster_visual, monster_death, monster_setup.

const MonsterAi := preload("res://systems/monsters/monster_ai.gd")
const MonsterCombatAi := preload("res://systems/monsters/monster_combat_ai.gd")
const MonsterMotion := preload("res://systems/monsters/monster_motion.gd")
const MonsterProjectiles := preload("res://systems/monsters/monster_projectiles.gd")
const MonsterDots := preload("res://systems/monsters/monster_dots.gd")
const MonsterVisual := preload("res://systems/monsters/monster_visual.gd")
const MonsterDeath := preload("res://systems/monsters/monster_death.gd")
const MonsterSetup := preload("res://systems/monsters/monster_setup.gd")

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
	MonsterSetup.build_collision(self, data)
	_visual.build()
	MonsterSetup.build_sync(self)


func _ready() -> void:
	add_to_group("damageable")
	_visual.update_bar()
	_visual.update_look()
	if not multiplayer.is_server():
		set_physics_process(false)
		return
	home = global_position
	_agent = MonsterSetup.build_agent(self, data)
	_ai.idle_left = randf_range(0.5, 2.5)


# --- Interface « damageable » (appelée par Weapon, côté serveur) ---

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


## Monstre de vague : fonce sur son objectif dès son apparition.
func aggro_objective() -> void:
	_ai.aggro_objective()


## Prend `player` pour cible. `alert_camp` : prévient le reste de la meute.
func aggro(player: Player, alert_camp: bool) -> void:
	_ai.aggro(player, alert_camp)


func _physics_process(delta: float) -> void:
	if global_position.y < Config.KILL_Y:
		_die(0)  # tombé hors de la carte : pas de crédits
		return
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	if _motion.ai_due(delta):  # allégée loin des joueurs (MonsterLod)
		_ai.step(_motion.ai_elapsed)
	_motion.move_body(delta)
	if not _projectiles.is_empty():
		_projectiles.step(delta)
	_dots.tick(delta)


func _die(killer_id: int) -> void:
	MonsterDeath.die(self, killer_id)


## Animation du modèle d'après le déplacement observé et l'état synchronisé (tous les peers).
func _process(delta: float) -> void:
	_visual.animate(delta)


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
