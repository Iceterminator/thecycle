class_name Relic
extends Area3D
## Contrat « Cœur stellaire ». Un objet unique au sol : E pour le prendre.
## Son porteur gagne data.points_per_second tant qu'il le garde, et TOUS les autres
## joueurs voient sa position (balise au-dessus de sa tête, annonce).
## À sa mort (ou déconnexion), le Cœur tombe au sol à sa position.
## Champs utilisés : points_per_second, color, display_name.

var data: ContractData
## Synchronisés.
var carrier_id: int = 0:
	set(value):
		carrier_id = value
		if is_node_ready():
			_visual.visible = carrier_id == 0
			_label.visible = carrier_id == 0

var _visual: Node3D
var _label: Label3D
var _points_acc: float = 0.0


func setup(contract_data: ContractData) -> void:
	data = contract_data
	collision_layer = 1 << 3  # couche « interaction »
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	shape.position.y = 0.8
	add_child(shape)
	_visual = ContractSite.make_mesh(SphereMesh.new(), data.color, true)
	_visual.scale = Vector3.ONE * 0.6
	_visual.position.y = 0.8
	add_child(_visual)
	var light := OmniLight3D.new()
	light.light_color = data.color
	light.omni_range = 4.0
	_visual.add_child(light)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0009
	_label.font_size = 30
	_label.outline_size = 8
	_label.modulate = data.color
	_label.text = "★ %s (+%d pts/s en le portant)" % [data.display_name, int(data.points_per_second)]
	_label.position.y = 2.0
	add_child(_label)
	var config := SceneReplicationConfig.new()
	for key in [".:carrier_id", ".:position"]:
		config.add_property(NodePath(key))
		config.property_set_spawn(NodePath(key), true)
		config.property_set_replication_mode(NodePath(key), SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.replication_config = config
	add_child(sync)


func _ready() -> void:
	add_to_group("interactable")
	carrier_id = carrier_id  # applique la visibilité
	set_physics_process(multiplayer.is_server())
	if multiplayer.is_server():
		Events.player_died.connect(func(victim: int, _k: int) -> void: if victim == carrier_id: _drop())
		Events.player_left.connect(func(peer: int) -> void: if peer == carrier_id: _drop())


func _process(delta: float) -> void:
	_visual.rotate_y(1.5 * delta)


func get_prompt(_player: Player) -> String:
	return "E : prendre le %s (tous les joueurs verront où vous êtes)" % data.display_name if carrier_id == 0 else ""


func get_hold_time(_player: Player) -> float:
	return 0.0


func server_interact(player: Player) -> void:
	if carrier_id != 0:
		return
	carrier_id = player.get_peer_id()
	player.score.set_beacon(&"relic", "★ %s" % data.display_name)
	Events.announce_requested.emit("%s porte le %s ! Sa position est visible." % [ContractSite.player_name(carrier_id), data.display_name], data.color)


func _physics_process(delta: float) -> void:
	if carrier_id == 0:
		return
	var carrier := get_parent().get_parent().get_node("Players").get_node_or_null(str(carrier_id)) as Player
	if carrier == null:
		_drop()
		return
	global_position = carrier.global_position  # pour tomber au bon endroit
	_points_acc += data.points_per_second * delta
	var whole := int(_points_acc)
	if whole > 0:
		_points_acc -= whole
		carrier.score.add_quest_points(whole)


func _drop() -> void:
	if carrier_id == 0:
		return
	var carrier := get_parent().get_parent().get_node("Players").get_node_or_null(str(carrier_id)) as Player
	if carrier:
		carrier.score.set_beacon(&"relic", "")
		global_position = carrier.global_position
	carrier_id = 0
	Events.announce_requested.emit("Le %s est tombé au sol !" % data.display_name, data.color)
