extends RefCounted
## Construction commune des contrats (ContractSite) : texte flottant et synchronisation.


## Texte flottant, visible de loin et à travers le décor : les joueurs doivent repérer les contrats.
static func make_label(site: ContractSite) -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0009
	label.font_size = 30
	label.outline_size = 8
	label.modulate = site.data.color
	label.position.y = site._label_height()
	return label


## Synchro des propriétés déclarées par _sync_props() (ajoutée comme enfant du site).
static func add_sync(site: ContractSite) -> void:
	var config := SceneReplicationConfig.new()
	for key: String in site._sync_props():
		var path := NodePath(".:" + key)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "ContractSync"
	sync.replication_config = config
	site.add_child(sync)
