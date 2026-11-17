class_name QuestManager
extends Node
## Crée les cristaux (quête foreuse) via le CrystalSpawner (règle 3 : seul le serveur crée).
## - Sur tous les peers : fournit la spawn_function.
## - Sur le serveur : un cristal par CrystalSpot de la carte.

const CRYSTAL_SCRIPT := preload("res://systems/quests/crystal.gd")

@export var spawner: MultiplayerSpawner
@export var spots: Node3D

var _next_uid: int = 0


func _ready() -> void:
	spawner.spawn_function = _spawn_node
	if not multiplayer.is_server():
		return
	_spawn_crystals.call_deferred()


func _spawn_crystals() -> void:
	for node in spots.get_children():
		var spot := node as CrystalSpot
		if spot == null or spot.crystal_data == null:
			continue
		_next_uid += 1
		spawner.spawn({
			"uid": _next_uid,
			"data": spot.crystal_data.resource_path,
			"pos": spot.global_position,
		})
		print("[Quête] Cristal %s placé en %s" % [spot.crystal_data.difficulty_name, spot.global_position])


## Appelée sur tous les peers avec les mêmes données : recrée le même cristal.
func _spawn_node(data: Dictionary) -> Node:
	var crystal: Crystal = CRYSTAL_SCRIPT.new()
	crystal.name = "Crystal_%d" % data["uid"]
	crystal.setup(load(data["data"]) as CrystalData)
	crystal.position = data["pos"]
	return crystal
