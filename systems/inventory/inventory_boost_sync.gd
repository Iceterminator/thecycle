extends RefCounted
## Crée le MultiplayerSynchronizer « BoostSync » de l'inventaire (paliers de boost et
## améliorations de boutique), synchronisé à part pour que player.tscn reste inchangé.


static func create() -> MultiplayerSynchronizer:
	var config := SceneReplicationConfig.new()
	for property in [".:slot_boosts", ".:weapon_upgrades"]:
		var path := NodePath(property)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "BoostSync"
	sync.replication_config = config
	return sync
