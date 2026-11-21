class_name Interactor
extends Node
## Interaction (touche E) avec les objets au sol, les cristaux…
## Client propriétaire : raycast depuis la caméra, affiche le message, envoie la demande.
## Serveur : vérifie propriétaire, vie et distance (selon SA position du joueur),
## puis appelle target.server_interact(player).
##
## Un objet interactif est dans le groupe "interactable" et a get_prompt / server_interact.
## S'il a get_hold_time(player) > 0, il faut MAINTENIR E : le client annonce le début
## (request_hold_start), puis demande l'interaction à la fin ; le serveur vérifie que
## le temps écoulé depuis le début est suffisant.

signal prompt_changed(text: String)
signal hold_progress(ratio: float)  ## 0 = pas de maintien en cours

const RAY_MASK := 1 | (1 << 3)  # monde + interaction (les joueurs ne bloquent pas)

@onready var player: Player = get_parent()

var _prompt: String = ""
var current_target: Node3D  ## objet interactif visé (lu par WeaponPickup)
# Client : maintien en cours
var _hold_target: Node3D
var _hold_elapsed: float = 0.0
# Serveur : début du maintien annoncé par le client
var _srv_hold_path: NodePath
var _srv_hold_start_ms: int = 0


func _ready() -> void:
	set_process(player.is_multiplayer_authority())


func _process(delta: float) -> void:
	var target: Node3D = null
	if not player.health.is_dead and not player.health.is_downed and not player.is_evacuated and not player.is_dropping():
		target = _find_target()
	current_target = target
	var text: String = target.get_prompt(player) if target else ""
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)

	var can_use := target != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var hold_time: float = target.get_hold_time(player) if can_use and target.has_method("get_hold_time") else 0.0
	if hold_time <= 0.0:
		_cancel_hold()
		if can_use and Input.is_action_just_pressed("interact"):
			request_interact.rpc_id(1, target.get_path())
		return

	# Interaction à maintenir.
	if not Input.is_action_pressed("interact") or target != _hold_target:
		_cancel_hold()
		if Input.is_action_just_pressed("interact"):
			_hold_target = target
			_hold_elapsed = 0.0
			request_hold_start.rpc_id(1, target.get_path())
		return
	_hold_elapsed += delta
	hold_progress.emit(clampf(_hold_elapsed / hold_time, 0.0, 1.0))
	if _hold_elapsed >= hold_time:
		request_interact.rpc_id(1, target.get_path())
		_cancel_hold()


func _cancel_hold() -> void:
	if _hold_target != null or _hold_elapsed > 0.0:
		_hold_target = null
		_hold_elapsed = 0.0
		hold_progress.emit(0.0)


func _find_target() -> Node3D:
	var cam := player.camera
	var from := cam.global_position
	var to := from - cam.global_basis.z * Config.INTERACT_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, RAY_MASK, [player.get_rid()])
	query.collide_with_areas = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider := hit["collider"] as Node3D
		if collider and collider.is_in_group("interactable"):
			return collider
	return _find_downed_ally()


## Allié à terre tout près et devant soi (le rayon ignore les joueurs : on le cherche à part).
func _find_downed_ally() -> Node3D:
	var forward := -player.camera.global_basis.z
	forward.y = 0.0
	for node in get_tree().get_nodes_in_group("downed_players"):
		var other := node as Player
		if other == null or other == player or not Allies.can_revive(player.get_peer_id(), other.get_peer_id()):
			continue
		var to := other.global_position - player.global_position
		to.y = 0.0
		if to.length() <= Config.INTERACT_RANGE and (to.length() < 0.8 or to.normalized().dot(forward.normalized()) > 0.5):
			return other
	return null


# =========================================================================
# Serveur
# =========================================================================

@rpc("any_peer", "call_local", "reliable")
func request_hold_start(path: NodePath) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player.get_peer_id():
		return
	_srv_hold_path = path
	_srv_hold_start_ms = Time.get_ticks_msec()
	var target := get_node_or_null(path) as Node3D  # hook serveur (piratage) : prévenir la cible
	if target and target.has_method("server_hold_started") and not MatchManager.is_lobby() and player.can_be_hit() \
			and player.camera.global_position.distance_to(target.global_position) <= Config.INTERACT_RANGE + Config.INTERACT_SERVER_MARGIN:
		target.server_hold_started(player)


@rpc("any_peer", "call_local", "reliable")
func request_interact(path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	if MatchManager.is_lobby():
		return  # pas de contrats ni de ramassage dans le lobby
	if multiplayer.get_remote_sender_id() != player.get_peer_id() or player.health.is_dead or player.health.is_downed or player.is_evacuated or player.is_dropping():
		return
	var target := get_node_or_null(path) as Node3D
	if target == null or not target.is_in_group("interactable") or not target.has_method("server_interact"):
		return
	var dist := player.camera.global_position.distance_to(target.global_position)
	if dist > Config.INTERACT_RANGE + Config.INTERACT_SERVER_MARGIN:
		push_warning("[Interact] Refusé : joueur %d trop loin (%.1f m)" % [player.get_peer_id(), dist])
		return
	var hold_time: float = target.get_hold_time(player) if target.has_method("get_hold_time") else 0.0
	if hold_time > 0.0:
		var held := (Time.get_ticks_msec() - _srv_hold_start_ms) / 1000.0
		if _srv_hold_path != path or held < hold_time * Config.HOLD_SERVER_TOLERANCE:
			push_warning("[Interact] Refusé : E pas maintenu assez longtemps (%.1f s / %.1f s)" % [held, hold_time])
			return
		_srv_hold_path = NodePath()
	target.server_interact(player)
