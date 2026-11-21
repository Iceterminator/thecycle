class_name QuestFactory
extends RefCounted
## Fabrique des nœuds de quête (cristal, contrats) à partir des données de spawn.
## Appelée par la spawn_function du QuestManager sur tous les peers : même résultat partout.

const CRYSTAL_SCRIPT := preload("res://systems/quests/crystal.gd")
const CONTRACT_SCRIPTS := {
	&"uplink": preload("res://systems/contracts/uplink.gd"),
	&"extractor": preload("res://systems/contracts/extractor.gd"),
	&"collector": preload("res://systems/contracts/collector.gd"),
	&"facility": preload("res://systems/contracts/facility.gd"),
	&"drones": preload("res://systems/contracts/drone_site.gd"),
	&"central": preload("res://systems/contracts/central_station.gd"),
}


static func create(data: Dictionary) -> Node:
	var kind: StringName = data.get("kind", &"crystal")
	if kind == &"crystal":
		var crystal: Crystal = CRYSTAL_SCRIPT.new()
		crystal.name = "Crystal_%d" % data["uid"]
		crystal.setup(load(data["data"]) as CrystalData)
		crystal.position = data["pos"]
		return crystal
	var node: Node3D = CONTRACT_SCRIPTS[kind].new()
	node.name = "%s_%d" % [String(kind).capitalize(), data["uid"]]
	node.setup(load(data["data"]) as ContractData)
	node.position = data["pos"]
	return node
