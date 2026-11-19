## Construction d'un Monster : forme de collision, agent de navigation (serveur) et synchronisation.
extends RefCounted


## Capsule de collision d'après le MonsterData.
static func build_collision(monster: Node3D, data: MonsterData) -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = data.radius
	capsule.height = data.height
	shape.shape = capsule
	shape.position.y = data.height / 2.0
	monster.add_child(shape)


## Agent de navigation (serveur uniquement) ; renvoyé pour que le monstre le garde.
static func build_agent(monster: Node3D, data: MonsterData) -> NavigationAgent3D:
	var agent := NavigationAgent3D.new()
	agent.path_desired_distance = 0.6
	agent.target_desired_distance = 0.6
	agent.radius = data.radius
	agent.height = data.height
	monster.add_child(agent)
	return agent


## MonsterSync : position, rotation, PV et état (autorité serveur).
static func build_sync(monster: Node3D) -> void:
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
	monster.add_child(sync)
