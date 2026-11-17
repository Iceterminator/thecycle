class_name LootManager
extends Node
## Crée les objets de loot réseau via le LootSpawner (règle 3 : seul le serveur crée).
## - Sur tous les peers : fournit la spawn_function (recrée les objets reçus).
## - Sur le serveur :
##   * Events.loot_drop_requested -> pose un objet au sol (mort d'un joueur, arme échangée).
##   * Events.drop_pod_requested  -> fait tomber une capsule de largage (achat en boutique),
##     puis pose l'objet dans la capsule quand elle a atterri.

const PICKUP_SCRIPT := preload("res://systems/loot/pickup.gd")
const DROP_POD_SCRIPT := preload("res://systems/shop/drop_pod.gd")

@export var spawner: MultiplayerSpawner

var _next_uid: int = 0
## Incrémenté à chaque nouvelle partie : les largages en cours d'une partie finie s'arrêtent.
var _generation: int = 0


func _ready() -> void:
	spawner.spawn_function = _spawn_node
	if not multiplayer.is_server():
		return
	Events.loot_drop_requested.connect(_on_drop_requested)
	Events.drop_pod_requested.connect(_on_drop_pod_requested)
	Events.match_reset_requested.connect(_on_match_reset)


## Nouvelle partie : plus rien au sol (le spawner retire aussi les objets chez les clients).
func _on_match_reset() -> void:
	_generation += 1
	for node in spawner.get_node(spawner.spawn_path).get_children():
		node.queue_free()


func _on_drop_requested(item_id: StringName, amount: int, ammo: int, position: Vector3, scatter: bool) -> void:
	if Items.get_item(item_id) == null:
		push_error("[Loot] Objet inconnu : %s" % item_id)
		return
	var pos := position
	if scatter:
		var r := Config.LOOT_SCATTER_RADIUS
		pos += Vector3(randf_range(-r, r), 0.0, randf_range(-r, r))
	spawner.spawn({
		"type": "pickup",
		"uid": _new_uid(),
		"item": String(item_id),
		"amount": amount,
		"ammo": ammo,
		"pos": _ground(pos),
	})


func _on_drop_pod_requested(item_id: StringName, position: Vector3) -> void:
	var item := Items.get_item(item_id)
	if item == null:
		push_error("[Loot] Largage d'un objet inconnu : %s" % item_id)
		return
	var landing := _ground(position)
	var generation := _generation
	var pod := spawner.spawn({"type": "pod", "uid": _new_uid(), "pos": landing})
	await get_tree().create_timer(Config.DROP_POD_FALL_TIME).timeout
	if generation != _generation:
		return
	spawner.spawn({
		"type": "pickup",
		"uid": _new_uid(),
		"item": String(item_id),
		"amount": item.amount,
		"ammo": -1,
		"pos": landing,
	})
	await get_tree().create_timer(Config.DROP_POD_LIFETIME).timeout
	if is_instance_valid(pod):
		pod.queue_free()


## Appelée sur tous les peers avec les mêmes données : recrée le même objet.
func _spawn_node(data: Dictionary) -> Node:
	if data.get("type") == "pod":
		var pod: Node3D = DROP_POD_SCRIPT.new()
		pod.name = "Pod_%d" % data["uid"]
		pod.position = data["pos"]
		return pod
	var pickup: Pickup = PICKUP_SCRIPT.new()
	pickup.name = "Pickup_%d" % data["uid"]
	pickup.setup(Items.get_item(StringName(data["item"])), data["amount"], data["ammo"])
	pickup.position = data["pos"]
	return pickup


## Pose une position au sol (raycast vers le bas sur la couche « monde », depuis haut :
## une capsule peut atterrir sur un rocher).
func _ground(pos: Vector3) -> Vector3:
	var world := spawner.get_parent() as Node3D
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 30.0, pos + Vector3.DOWN * 20.0, 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else pos


func _new_uid() -> int:
	_next_uid += 1
	return _next_uid
