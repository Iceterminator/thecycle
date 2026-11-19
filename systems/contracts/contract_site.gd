class_name ContractSite
extends StaticBody3D
## Base des contrats posés dans la carte (relais, extracteur, collecteur, station, drones).
## Créé par le serveur (QuestManager -> CrystalSpawner), construit en code à partir d'un
## ContractData. Les sous-classes déclarent leurs propriétés synchronisées via _sync_props()
## et leur visuel via _build_visual(). Interface d'interaction : get_prompt, get_hold_time,
## server_interact (voir Interactor).

var data: ContractData
var _label: Label3D
var _points_acc: Dictionary = {}  # peer_id -> fraction de point en attente (gains continus)


## Appelé par la spawn_function, sur tous les peers, avant l'entrée dans l'arbre.
func setup(contract_data: ContractData) -> void:
	data = contract_data
	_build_visual()
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Visible de loin et à travers le décor : les joueurs doivent repérer les contrats.
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0009
	_label.font_size = 30
	_label.outline_size = 8
	_label.modulate = data.color
	_label.position.y = _label_height()
	add_child(_label)
	var config := SceneReplicationConfig.new()
	for key: String in _sync_props():
		var path := NodePath(".:" + key)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "ContractSync"
	sync.replication_config = config
	add_child(sync)


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("map_marker")  # écran Tab (systems/map/)
	set_physics_process(multiplayer.is_server())
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


# --- À redéfinir ---------------------------------------------------------

func _sync_props() -> Array[String]:
	return []


func _build_visual() -> void:
	pass


func _label_height() -> float:
	return 3.5


## Met à jour le texte flottant (appelé chaque frame sur tous les peers).
func _refresh() -> void:
	pass


func get_prompt(_player: Player) -> String:
	return ""


func get_hold_time(_player: Player) -> float:
	return 0.0


func server_interact(_player: Player) -> void:
	pass


# --- Outils --------------------------------------------------------------

func players_root() -> Node:
	return get_parent().get_parent().get_node("Players")


func find_player(peer_id: int) -> Player:
	return players_root().get_node_or_null(str(peer_id)) as Player if peer_id > 0 else null


static func player_name(peer_id: int) -> String:
	return ProfileManager.name_of(peer_id)


## Serveur : gain continu de points d'objectif (fractions cumulées).
func give_points_over_time(player: Player, rate: float, delta: float) -> void:
	var peer := player.get_peer_id()
	var acc: float = _points_acc.get(peer, 0.0) + rate * delta
	var whole := int(acc)
	_points_acc[peer] = acc - whole
	if whole > 0:
		player.score.add_objective_points(data.track, whole)


func announce(text: String) -> void:
	Events.announce_requested.emit(text, data.color)


## Monstres de vague autour de `center`, qui attaquent `objective`.
func spawn_wave(wave: CampData, center: Vector3, objective: Node3D) -> int:
	var count := 0
	for monster_data in wave.roll():
		var angle := randf() * TAU
		var dist := randf_range(Config.match_rules.crystal_wave_spawn_min * 0.75, Config.match_rules.crystal_wave_spawn_max * 0.75)
		var pos := center + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		pos.y = MapTerrain.height_at(pos.x, pos.z)
		Events.wave_spawn_requested.emit(objective, monster_data, pos, data.monster_health_mult, data.monster_damage_mult)
		count += 1
	return count


func add_cylinder_collision(radius: float, height: float) -> void:
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	shape.shape = cylinder
	shape.position.y = height / 2.0
	add_child(shape)


static func make_mesh(mesh: Mesh, color: Color, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
	mi.material_override = mat
	return mi


## Écran Tab : texte de l'état (le même que le texte flottant), couleur, type de repère.
func map_info() -> Dictionary:
	return {"text": _label.text if _label else data.display_name, "color": data.color, "kind": "contract"}


## Texte flottant visible seulement de près (appelé par le HUD du joueur local).
func set_map_tag_visible(value: bool) -> void:
	if _label:
		_label.visible = value
