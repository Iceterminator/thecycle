extends RefCounted
## Déplacement d'un monstre (serveur) : vitesse, orientation, chemin de navigation,
## ligne de vue, distances et déplacement physique allégé (MonsterLod).

var _m: Monster
var _slow_mult: float = 1.0       ## Entrave : vitesse réduite jusqu'à _slow_until_ms
var _slow_until_ms: int = 0
var _far: bool = false           ## loin de tout joueur (MonsterLod)
var _far_check_left: float = randf() * MonsterLod.CHECK_INTERVAL  ## décalé entre monstres (pas de pic)
var _force_slide: bool = true    ## un move_and_slide est nécessaire (reprise après le mode loin)
var ai_elapsed: float = 0.0       ## temps à donner à l'IA quand ai_due() est vrai
var _ai_accum: float = randf() * MonsterLod.FAR_AI_INTERVAL


func _init(monster: Monster) -> void:
	_m = monster


## Serveur : ralentissement temporaire (capacité Entrave).
func apply_slow(mult: float, duration: float) -> void:
	_slow_mult = clampf(mult, 0.1, 1.0)
	_slow_until_ms = Time.get_ticks_msec() + int(duration * 1000.0)


## IA allégée (MonsterLod) : en patrouille loin de tout joueur, l'IA ne réfléchit que toutes les
## MonsterLod.FAR_AI_INTERVAL s (avec le temps cumulé) ; sinon à chaque image.
func ai_due(delta: float) -> bool:
	_ai_accum += delta
	if _far and _m.state == Monster.State.PATROL and _ai_accum < MonsterLod.FAR_AI_INTERVAL:
		return false
	ai_elapsed = _ai_accum
	_ai_accum = 0.0
	return true


## Déplacement physique, allégé (MonsterLod) : sans collision en patrouille loin des joueurs,
## aucun calcul à l'arrêt au sol, move_and_slide sinon.
func move_body(delta: float) -> void:
	_far_check_left -= delta
	if _far_check_left <= 0.0:
		_far_check_left = MonsterLod.CHECK_INTERVAL
		_far = MonsterLod.is_far(_m, _m.players_root)
	if _far and _m.state == Monster.State.PATROL:
		_m.velocity.y = 0.0  # posé sur le relief : pas de chute accumulée (elle traverserait le sol au retour)
		if _m.velocity.x != 0.0 or _m.velocity.z != 0.0:
			MonsterLod.step_far(_m, delta)
		_force_slide = true
		return
	var at_rest := _m.velocity.length_squared() < 0.0001 and _m.is_on_floor()
	if at_rest and not _force_slide:
		return
	_force_slide = false
	_m.move_and_slide()


func move_toward_with_path(target_pos: Vector3, speed: float) -> void:
	if _m._repath_left <= 0.0:
		_m._repath_left = Monster.REPATH_INTERVAL
		_m._agent.target_position = target_pos
	var next := _m._agent.get_next_path_position()
	# Pas de chemin (navmesh pas prêt, cible hors navmesh) ou cible toute proche : tout droit.
	if _m._agent.get_current_navigation_path().is_empty() or flat_dist(target_pos) < Monster.DIRECT_CHASE_DIST:
		next = target_pos
	move_to(next, speed)


func move_to(point: Vector3, speed: float) -> void:
	if _slow_until_ms > Time.get_ticks_msec():
		speed *= _slow_mult
	var dir := point - _m.global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		halt()
		return
	dir = dir.normalized()
	_m.velocity.x = dir.x * speed
	_m.velocity.z = dir.z * speed
	face(_m.global_position + dir)


func face(point: Vector3) -> void:
	var dir := point - _m.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	_m.rotation.y = lerp_angle(_m.rotation.y, atan2(-dir.x, -dir.z), 0.25)


func halt() -> void:
	_m.velocity.x = 0.0
	_m.velocity.z = 0.0


## Recule doucement face à la cible (pendant la pause après un coup).
func back_off() -> void:
	if not valid_target():
		halt()
		return
	var away := _m.global_position - _m._target.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		halt()
		return
	away = away.normalized() * _m.data.walk_speed * Monster.BACK_OFF_SPEED_RATIO
	_m.velocity.x = away.x
	_m.velocity.z = away.z
	face(_m._target.global_position)


func valid_target() -> bool:
	return is_instance_valid(_m._target) and _m._target.can_be_hit()


## Distance au bord de la cible (une foreuse est plus large qu'un joueur).
func target_dist() -> float:
	var radius: float = _m._target.get_hit_radius() if _m._target.has_method("get_hit_radius") else 0.0
	return maxf(flat_dist(_m._target.global_position) - radius, 0.0)


func flat_dist(point: Vector3) -> float:
	return Vector2(_m.global_position.x - point.x, _m.global_position.z - point.z).length()


## Rien du décor entre le monstre et la cible (la cible elle-même peut être du décor :
## une foreuse est sur la couche « monde »).
func has_line_of_sight(target: Node3D) -> bool:
	var from := _m.global_position + Vector3.UP * _m.data.height * 0.8
	var to := target.global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)  # couche « monde » seulement
	var hit := _m.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == target
