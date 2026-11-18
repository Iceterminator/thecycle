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
			_update_bar()
var state: int = State.PATROL:
	set(value):
		state = value
		if is_node_ready():
			_update_look()

# --- Serveur uniquement ---
var camp: MonsterCamp
var players_root: Node
var home: Vector3
var objective: Node3D          ## monstre de vague : ce qu'il doit détruire
var damage_mult: float = 1.0   ## vagues difficiles et niveau : coups plus forts
var credits_mult: float = 1.0  ## niveau : crédits versés au tueur
var _slow_mult: float = 1.0       ## Entrave : vitesse réduite jusqu'à _slow_until_ms
var _slow_until_ms: int = 0
var _projectiles: Array[Dictionary] = []  ## { id, pos, dir, travelled, max_dist }
var _next_projectile_id: int = 0
var _had_objective: bool = false
var _agent: NavigationAgent3D
var _target: Node3D
var _has_patrol_point: bool = false
var _idle_left: float = 0.0
var _scan_left: float = 0.0
var _repath_left: float = 0.0
var _state_left: float = 0.0
var _pause_left: float = 0.0  ## pause après un coup réussi (recule un peu, ne colle pas)
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# --- Visuels ---
var _mat: StandardMaterial3D
var _bar: Label3D
var _visual_projectiles: Dictionary[int, Node3D] = {}
var _model_meshes: Array[MeshInstance3D] = []
var _anim: AnimationPlayer
var _anim_last_pos: Vector3
var _anim_speed := 0.0
var _anim_last_health := -1.0
var _hit_left := 0.0

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
	_build_visual()
	_build_sync()


func _ready() -> void:
	add_to_group("damageable")
	_update_bar()
	_update_look()
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
	_idle_left = randf_range(0.5, 2.5)


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
	_state_left -= delta
	_scan_left -= delta
	_repath_left -= delta
	match state:
		State.PATROL:
			_do_patrol(delta)
		State.CHASE:
			_do_chase()
		State.WINDUP:
			_do_windup()
		State.RECOVER:
			if _pause_left > 0.0:
				# Juste après un coup qui a touché : petite pause en reculant.
				_pause_left -= delta
				_back_off()
			else:
				# Puis il reprend la poursuite, sans frapper avant la fin de la recharge.
				_do_chase(false)
			if state == State.RECOVER and _state_left <= 0.0:
				state = State.CHASE
		State.RETURN:
			_do_return()
	move_and_slide()
	if not _projectiles.is_empty():
		_step_projectiles(delta)
	_tick_dots(delta)


## Monstres plus agressifs dans la tempête.
func _aggro_mult() -> float:
	return Config.match_rules.storm_monster_mult if StormManager.is_in_storm(global_position) else 1.0


func _do_patrol(delta: float) -> void:
	if _scan_left <= 0.0:
		_scan_left = SCAN_INTERVAL
		var player := _find_player()
		if player:
			aggro(player, true)
			return
	if _idle_left > 0.0:
		_idle_left -= delta
		_halt()
		return
	if not _has_patrol_point:
		var angle := randf() * TAU
		var dist := sqrt(randf()) * (camp.radius if camp else 6.0)
		_agent.target_position = home + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		_has_patrol_point = true
		return  # laisse une frame au chemin pour se calculer
	# get_next_path_position() calcule le chemin : à appeler AVANT de tester s'il est fini.
	var next := _agent.get_next_path_position()
	if _agent.is_navigation_finished() or _agent.get_current_navigation_path().is_empty():
		_has_patrol_point = false
		_idle_left = randf_range(1.0, 3.0)
		_halt()
		return
	_move_to(next, data.walk_speed)


func _do_chase(can_attack: bool = true) -> void:
	if not _valid_target():
		_start_return()
		return
	var target_pos := _target.global_position
	var dist := _target_dist()
	# Pas d'abandon ni de laisse quand on attaque son objectif.
	var on_objective := _target == objective
	if not on_objective and (dist > data.lose_radius or (objective == null and _flat_dist(home) > data.leash_radius)):
		_start_return()
		return
	if data.ranged:
		_chase_ranged(target_pos, dist, can_attack)
		return
	if can_attack and dist <= data.attack_range:
		state = State.WINDUP
		_state_left = data.attack_windup
	if dist <= data.attack_range * CONTACT_RATIO:
		# Déjà au contact : on ne pousse pas le joueur, on le regarde.
		_halt()
		_face(target_pos)
		return
	_move_toward_with_path(target_pos, data.run_speed * _aggro_mult())


## Monstre à distance : à portée avec ligne de vue, il s'arrête (ou recule si on est trop
## près) et prépare un tir ; sinon il se rapproche.
func _chase_ranged(target_pos: Vector3, dist: float, can_attack: bool) -> void:
	if dist <= data.attack_range and _has_line_of_sight(_target):
		if dist < data.min_range and _target != objective:
			_back_off()
		else:
			_halt()
			_face(target_pos)
		if can_attack:
			state = State.WINDUP
			_state_left = data.attack_windup
		return
	_move_toward_with_path(target_pos, data.run_speed * _aggro_mult())


## Préparation du coup : le monstre continue d'avancer (plus lentement) vers la cible.
## Le coup part à la fin s'il est encore à portée ; s'il rate, la pause est courte.
## Monstre à distance : il reste sur place et vise, puis tire s'il voit toujours la cible.
func _do_windup() -> void:
	if not _valid_target():
		_start_return()
		return
	var target_pos := _target.global_position
	if data.ranged:
		_halt()
		_face(target_pos)
		if _state_left > 0.0:
			return
		if _target_dist() <= data.attack_range * HIT_RANGE_RATIO and _has_line_of_sight(_target):
			_fire_projectile()
			_state_left = data.attack_cooldown
		else:
			_state_left = MISS_RECOVERY
		_pause_left = 0.0
		state = State.RECOVER
		return
	if _target_dist() > data.attack_range * CONTACT_RATIO:
		_move_to(target_pos, data.run_speed * LUNGE_SPEED_RATIO)
	else:
		_halt()
	_face(target_pos)
	if _state_left > 0.0:
		return
	if _target_dist() <= data.attack_range * HIT_RANGE_RATIO:
		_target.server_receive_hit(data.attack_damage * damage_mult, Config.MONSTER_KILLER_ID)
		_state_left = data.attack_cooldown
		_pause_left = data.post_hit_pause
	else:
		_state_left = MISS_RECOVERY
	state = State.RECOVER


## Recule doucement face à la cible (pendant la pause après un coup).
func _back_off() -> void:
	if not _valid_target():
		_halt()
		return
	var away := global_position - _target.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		_halt()
		return
	away = away.normalized() * data.walk_speed * BACK_OFF_SPEED_RATIO
	velocity.x = away.x
	velocity.z = away.z
	_face(_target.global_position)


func _do_return() -> void:
	if _flat_dist(home) < 2.0:
		health = max_health  # de retour au camp : PV au max (pas de « kiting » gratuit)
		state = State.PATROL
		_has_patrol_point = false
		_idle_left = randf_range(0.5, 1.5)
		_halt()
		return
	_move_toward_with_path(home, data.walk_speed * 1.6)


func _start_return() -> void:
	# Monstre de vague : il retourne attaquer son objectif plutôt que rentrer.
	if is_instance_valid(objective) and objective.can_be_hit():
		_target = objective
		state = State.CHASE
		_repath_left = 0.0
		return
	if _had_objective:
		# Objectif détruit / joueur ciblé mort : le monstre de vague n'a plus de raison d'être.
		queue_free()
		return
	_target = null
	state = State.RETURN
	_repath_left = 0.0


## Joueur vivant le plus proche dans le rayon de détection, avec ligne de vue.
func _find_player() -> Player:
	if players_root == null:
		return null
	var best: Player = null
	var best_dist := data.detection_radius * _aggro_mult()
	for node in players_root.get_children():
		var player := node as Player
		if player == null or not player.can_be_hit():
			continue
		# Joueur camouflé : invisible pour les monstres, sauf tout près.
		var cloaked := player.buffs != null and player.buffs.get_cloak(0.0) >= Config.combat.cloak_monster_ignore
		if cloaked and global_position.distance_to(player.global_position) > 4.0:
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist <= best_dist and _has_line_of_sight(player):
			best = player
			best_dist = dist
	return best


## Rien du décor entre le monstre et la cible (la cible elle-même peut être du décor :
## une foreuse est sur la couche « monde »).
func _has_line_of_sight(target: Node3D) -> bool:
	var from := global_position + Vector3.UP * data.height * 0.8
	var to := target.global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)  # couche « monde » seulement
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == target


func _move_toward_with_path(target_pos: Vector3, speed: float) -> void:
	if _repath_left <= 0.0:
		_repath_left = REPATH_INTERVAL
		_agent.target_position = target_pos
	var next := _agent.get_next_path_position()
	# Pas de chemin (navmesh pas prêt, cible hors navmesh) ou cible toute proche : tout droit.
	if _agent.get_current_navigation_path().is_empty() or _flat_dist(target_pos) < DIRECT_CHASE_DIST:
		next = target_pos
	_move_to(next, speed)


func _move_to(point: Vector3, speed: float) -> void:
	if _slow_until_ms > Time.get_ticks_msec():
		speed *= _slow_mult
	var dir := point - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		_halt()
		return
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(global_position + dir)


func _face(point: Vector3) -> void:
	var dir := point - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 0.25)


func _halt() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _valid_target() -> bool:
	return is_instance_valid(_target) and _target.can_be_hit()


## Distance au bord de la cible (une foreuse est plus large qu'un joueur).
func _target_dist() -> float:
	var radius: float = _target.get_hit_radius() if _target.has_method("get_hit_radius") else 0.0
	return maxf(_flat_dist(_target.global_position) - radius, 0.0)


func _flat_dist(point: Vector3) -> float:
	return Vector2(global_position.x - point.x, global_position.z - point.z).length()


func _die(killer_id: int) -> void:
	state = State.RETURN
	set_physics_process(false)
	# Pour l'instant : seulement des crédits, versés directement au tueur (rien au sol).
	# Plus tard, vider un camp donnera aussi des points de quête.
	var killer := players_root.get_node_or_null(str(killer_id)) as Player if players_root else null
	if killer and data.credits > 0:
		killer.inventory.add_credits(roundi(data.credits * credits_mult))
	if data.biomass_drop > 0:
		Events.loot_drop_requested.emit(&"biomass", data.biomass_drop, -1, global_position + Vector3.UP * 0.4, true)
	Events.monster_killed.emit(data.id, killer_id)
	if camp:
		camp.on_monster_died(self, killer_id)
	if is_instance_valid(objective) and objective.has_method("on_wave_monster_died"):
		objective.on_wave_monster_died(self)
	queue_free()


# =========================================================================
# Construction : synchro réseau et visuels
# =========================================================================

## Animation du modèle d'après le déplacement observé et l'état synchronisé (tous les peers).
func _process(delta: float) -> void:
	if _anim == null or delta <= 0.0:
		return
	var moved := global_position - _anim_last_pos
	var first := _anim_last_pos == Vector3.ZERO
	_anim_last_pos = global_position
	if first:
		return
	_anim_speed = lerpf(_anim_speed, Vector2(moved.x, moved.z).length() / delta, clampf(delta * 6.0, 0.0, 1.0))
	if _anim_last_health >= 0.0 and health < _anim_last_health:
		_hit_left = 0.3
	_anim_last_health = health
	_hit_left -= delta
	var anim_name := "Idle"
	if state == State.WINDUP:
		anim_name = "Attack"
	elif _hit_left > 0.0:
		anim_name = "Hit"
	elif _anim_speed > data.walk_speed * 1.3:
		anim_name = "Run"
	elif _anim_speed > 0.3:
		anim_name = "Walk"
	if not _anim.has_animation(anim_name):
		anim_name = "Idle"
	if _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.15)


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


func _build_visual() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = data.color
	if data.model:
		_build_model()
	else:
		_build_capsule()
	_bar = Label3D.new()
	_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bar.font_size = 36
	_bar.outline_size = 8
	_bar.pixel_size = 0.004
	_bar.position.y = data.height + 0.45
	add_child(_bar)


## Modèle animé (MonsterData.model), mis à la hauteur du monstre.
func _build_model() -> void:
	var model := data.model.instantiate() as Node3D
	add_child(model)
	model.rotation.y = deg_to_rad(data.model_yaw_deg)
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		_model_meshes.append(mi)
		box = mi.get_aabb() if first else box.merge(mi.get_aabb())
		first = false
	if not first and box.size.y > 0.0:
		model.scale = Vector3.ONE * data.height * data.model_height_mult / box.size.y
		model.position.y = -box.position.y * model.scale.y
	var found := model.find_children("*", "AnimationPlayer", true, false)
	if not found.is_empty():
		_anim = found[0] as AnimationPlayer
		for anim_name: String in ["Idle", "Walk", "Run"]:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		_anim.play("Idle")
	# Flash de préparation du coup : voile rouge par-dessus le modèle.
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(1.0, 0.1, 0.05, 0.45)


func _build_capsule() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = data.radius
	capsule.height = data.height
	capsule.radial_segments = 8
	capsule.rings = 2
	body.mesh = capsule
	body.material_override = _mat
	body.position.y = data.height / 2.0
	add_child(body)

	# Des « yeux » à l'avant (-Z) pour voir où il regarde.
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(1.0, 0.85, 0.2)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * data.radius * 0.3
		eye.mesh = box
		eye.material_override = eye_mat
		eye.position = Vector3(side * data.radius * 0.4, data.height * 0.78, -data.radius * 0.9)
		add_child(eye)


## Barre de PV au-dessus du monstre, visible seulement s'il est blessé.
func _update_bar() -> void:
	if _bar == null or data == null:
		return
	var ratio := clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
	_bar.visible = ratio < 1.0 and ratio > 0.0
	var filled := ceili(ratio * 10.0)
	var title := data.display_name if level <= 1 else "%s (niv. %d)" % [data.display_name, level]
	_bar.text = "%s\n%s%s" % [title, "■".repeat(filled), "□".repeat(10 - filled)]
	_bar.modulate = Color(1.0, 0.35, 0.3).lerp(Color(0.4, 1.0, 0.4), ratio)


## Flash rouge pendant la préparation du coup (pour pouvoir l'esquiver).
func _update_look() -> void:
	if _mat == null:
		return
	for mi in _model_meshes:
		mi.material_overlay = _mat if state == State.WINDUP else null
	_mat.emission_enabled = state == State.WINDUP
	_mat.emission = Color(1.0, 0.1, 0.05)
	_mat.emission_energy_multiplier = 2.0


# =========================================================================
# Tir à distance (serveur), effets visibles chez tous
# =========================================================================

## Crache un projectile vers le torse de la cible (pas d'anticipation : on peut l'esquiver).
func _fire_projectile() -> void:
	var forward := -global_basis.z
	var from := global_position + Vector3.UP * data.height * 0.75 + forward * data.radius
	var aim := _target.global_position + Vector3.UP * 1.0
	var dir := (aim - from).normalized()
	_next_projectile_id += 1
	var max_dist := data.attack_range * 1.6
	_projectiles.append({"id": _next_projectile_id, "pos": from, "dir": dir, "travelled": 0.0, "max_dist": max_dist})
	_show_projectile.rpc(_next_projectile_id, from, dir, data.projectile_speed, max_dist)


## Un raycast par image sur le segment parcouru : décor (couche 1) et joueurs (couche 2).
## Touche aussi une foreuse (décor avec server_receive_hit).
func _step_projectiles(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	for i in range(_projectiles.size() - 1, -1, -1):
		var p := _projectiles[i]
		var step := minf(data.projectile_speed * delta, p["max_dist"] - p["travelled"])
		var from: Vector3 = p["pos"]
		var to: Vector3 = from + p["dir"] * step
		var query := PhysicsRayQueryParameters3D.create(from, to, 1 | (1 << 1) | Config.SHOT_ONLY_LAYER)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var target := hit["collider"] as Node
			if target and target.has_method("server_receive_hit") and target.has_method("can_be_hit") and target.can_be_hit():
				target.server_receive_hit(data.attack_damage * damage_mult, Config.MONSTER_KILLER_ID)
			_end_projectile.rpc(p["id"], hit["position"])
			_projectiles.remove_at(i)
			continue
		p["pos"] = to
		p["travelled"] += step
		if p["travelled"] >= p["max_dist"]:
			_end_projectile.rpc(p["id"], to)
			_projectiles.remove_at(i)


@rpc("authority", "call_local", "unreliable")
func _show_projectile(id: int, from: Vector3, dir: Vector3, speed: float, max_dist: float) -> void:
	if Net.is_dedicated_server:
		return
	var world := get_parent().get_parent() as Node3D
	if world == null:
		return
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = data.color.lightened(0.4)
	sphere.material = mat
	orb.mesh = sphere
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(orb)
	orb.global_position = from
	_visual_projectiles[id] = orb
	var tween := orb.create_tween()
	tween.tween_property(orb, "global_position", from + dir * max_dist, max_dist / speed)
	tween.finished.connect(_free_projectile_visual.bind(id))


@rpc("authority", "call_local", "reliable")
func _end_projectile(id: int, _point: Vector3) -> void:
	_free_projectile_visual(id)


func _free_projectile_visual(id: int) -> void:
	var orb: Node3D = _visual_projectiles.get(id)
	_visual_projectiles.erase(id)
	if is_instance_valid(orb):
		orb.queue_free()


func _exit_tree() -> void:
	# Le monstre disparaît : ses projectiles visibles aussi.
	for id: int in _visual_projectiles.keys():
		_free_projectile_visual(id)


## Serveur : ralentissement temporaire (capacité Entrave).
func apply_slow(mult: float, duration: float) -> void:
	_slow_mult = clampf(mult, 0.1, 1.0)
	_slow_until_ms = Time.get_ticks_msec() + int(duration * 1000.0)


# --- Dégâts sur la durée (mods d'arme feu / poison) ---
var _dots: Array = []        # [par seconde, fin (ms), attaquant]
var _dot_left: float = 0.0


func apply_dot(per_s: float, duration: float, attacker_id: int) -> void:
	_dots.append([per_s, Time.get_ticks_msec() + int(duration * 1000.0), attacker_id])


func _tick_dots(delta: float) -> void:
	if _dots.is_empty() or health <= 0.0:
		return
	_dot_left -= delta
	if _dot_left > 0.0:
		return
	_dot_left = 0.25
	var now := Time.get_ticks_msec()
	_dots = _dots.filter(func(d: Array) -> bool: return now < int(d[1]))
	for d: Array in _dots.duplicate():
		if health > 0.0:
			server_receive_hit(float(d[0]) * 0.25, int(d[2]))
