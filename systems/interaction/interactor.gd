class_name Interactor
extends Node
## Interaction (touche E) avec les caisses et objets au sol.
## Client propriétaire : raycast depuis la caméra, affiche le message, envoie la demande.
## Serveur : vérifie propriétaire, vie et distance (selon SA position du joueur),
## puis appelle target.server_interact(player).
## Un objet interactif est dans le groupe "interactable" et a get_prompt / server_interact.

signal prompt_changed(text: String)

const RAY_MASK := 1 | (1 << 3)  # monde + interaction (les joueurs ne bloquent pas)

@onready var player: Player = get_parent()

var _prompt: String = ""


func _ready() -> void:
	set_process(player.is_multiplayer_authority())


func _process(_delta: float) -> void:
	var target: Node3D = null
	if not player.health.is_dead:
		target = _find_target()
	var text: String = target.get_prompt(player) if target else ""
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)
	if target and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_just_pressed("interact"):
		request_interact.rpc_id(1, target.get_path())


func _find_target() -> Node3D:
	var cam := player.camera
	var from := cam.global_position
	var to := from - cam.global_basis.z * Config.INTERACT_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, RAY_MASK, [player.get_rid()])
	query.collide_with_areas = true
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var collider := hit["collider"] as Node3D
	return collider if collider and collider.is_in_group("interactable") else null


@rpc("any_peer", "call_local", "reliable")
func request_interact(path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != player.get_peer_id() or player.health.is_dead:
		return
	var target := get_node_or_null(path) as Node3D
	if target == null or not target.is_in_group("interactable") or not target.has_method("server_interact"):
		return
	var dist := player.camera.global_position.distance_to(target.global_position)
	if dist > Config.INTERACT_RANGE + Config.INTERACT_SERVER_MARGIN:
		push_warning("[Interact] Refusé : joueur %d trop loin (%.1f m)" % [player.get_peer_id(), dist])
		return
	target.server_interact(player)
