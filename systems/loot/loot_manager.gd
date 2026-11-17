class_name LootManager
extends Node
## Crée les objets de loot réseau (caisses, objets au sol) via le LootSpawner.
## - Sur tous les peers : fournit la spawn_function (pour recréer les objets reçus).
## - Sur le serveur : pose une caisse sur chaque marqueur de CrateSpawns, et écoute
##   Events.loot_drop_requested pour poser des objets au sol.

const CRATE_SCENE := preload("res://systems/loot/crate.tscn")
const PICKUP_SCRIPT := preload("res://systems/loot/pickup.gd")

@export var spawner: MultiplayerSpawner
@export var crate_spawns: Node3D

var _next_uid: int = 0


func _ready() -> void:
	spawner.spawn_function = _spawn_node
	if not multiplayer.is_server():
		return
	Events.loot_drop_requested.connect(_on_drop_requested)
	_spawn_crates.call_deferred()


func _spawn_crates() -> void:
	for marker in crate_spawns.get_children():
		var m := marker as Node3D
		spawner.spawn({
			"type": "crate",
			"uid": _new_uid(),
			"pos": _ground(m.global_position),
			"rot": m.global_rotation.y,
		})


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


## Appelée sur tous les peers avec les mêmes données : recrée le même objet.
func _spawn_node(data: Dictionary) -> Node:
	if data.get("type") == "crate":
		var crate: Node3D = CRATE_SCENE.instantiate()
		crate.name = "Crate_%d" % data["uid"]
		crate.position = data["pos"]
		crate.rotation.y = data["rot"]
		return crate
	var pickup: Pickup = PICKUP_SCRIPT.new()
	pickup.name = "Pickup_%d" % data["uid"]
	pickup.setup(Items.get_item(StringName(data["item"])), data["amount"], data["ammo"])
	pickup.position = data["pos"]
	return pickup


## Pose une position au sol (raycast vers le bas sur la couche « monde »).
func _ground(pos: Vector3) -> Vector3:
	var world := spawner.get_parent() as Node3D
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 1.5, pos + Vector3.DOWN * 20.0, 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else pos


func _new_uid() -> int:
	_next_uid += 1
	return _next_uid
