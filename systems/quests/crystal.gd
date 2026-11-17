class_name Crystal
extends StaticBody3D
## Quête « cristal + foreuse ». Créé par le serveur (QuestManager -> CrystalSpawner),
## construit en code à partir d'un CrystalData (facile / moyen / difficile).
##
## Déroulement (tout décidé par le SERVEUR) :
##   IDLE     : maintenir E 3 s -> la foreuse se déploie.
##   DEFENSE  : des vagues de monstres arrivent et attaquent la foreuse (PV de foreuse).
##              Il faut tuer tous les monstres de toutes les vagues.
##              Si la foreuse est détruite -> FAILED, puis retour à IDLE après un délai.
##   EXTRACT  : maintenir E 5 s -> points d'objectif « Forage » pour celui qui extrait.
##   DONE     : épuisé ; réapparaît après Config.CRYSTAL_RESPAWN_DELAY (tests).
##
## La foreuse n'est PAS dans le groupe "damageable" : les armes des joueurs ne la
## touchent pas, seuls les monstres (cible `objective`) l'abîment.

enum State { IDLE, DEFENSE, EXTRACT, DONE, FAILED }

const HIT_RADIUS := 1.3

var data: CrystalData

## Synchronisés (serveur -> clients) pour l'affichage.
var state: int = State.IDLE:
	set(value):
		state = value
		if is_node_ready():
			_update_look()
var drill_health: float = 0.0:
	set(value):
		drill_health = value
		if is_node_ready():
			_update_label()
var wave_index: int = 0           ## vague en cours (1 = première), 0 = pas commencé
var monsters_left: int = 0:
	set(value):
		monsters_left = value
		if is_node_ready():
			_update_label()
var next_wave_in: float = 0.0     ## compte à rebours avant la prochaine vague (s)

# --- Serveur ---
var _alive: Array[Monster] = []
var _wave_timer: float = -1.0

# --- Visuels ---
var _crystal_mat: StandardMaterial3D
var _drill: Node3D
var _bit: Node3D
var _label: Label3D


## Appelé par la spawn_function, sur tous les peers, avant l'entrée dans l'arbre.
func setup(crystal_data: CrystalData) -> void:
	data = crystal_data
	drill_health = data.drill_health
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.1
	cylinder.height = 2.6
	shape.shape = cylinder
	shape.position.y = 1.3
	add_child(shape)
	_build_visual()
	_build_sync()


func _ready() -> void:
	add_to_group("interactable")
	_update_look()
	set_physics_process(multiplayer.is_server())


func _process(delta: float) -> void:
	if state == State.DEFENSE:
		_bit.rotate_y(6.0 * delta)
		if next_wave_in > 0.0:
			next_wave_in = maxf(next_wave_in - delta, 0.0)  # affichage local seulement
			_update_label()


# =========================================================================
# Interaction (Interactor)
# =========================================================================

func get_prompt(_player: Player) -> String:
	match state:
		State.IDLE:
			return "Maintenir E (%d s) : lancer la foreuse — %s %s (+%d pts de Forage)" % [
				int(Config.CRYSTAL_ACTIVATE_TIME), data.display_name, data.difficulty_name, data.objective_points]
		State.EXTRACT:
			return "Maintenir E (%d s) : extraire le cristal (+%d pts de Forage)" % [
				int(Config.CRYSTAL_EXTRACT_TIME), data.objective_points]
	return ""


## Durée de maintien de E (0 = pas d'interaction possible).
func get_hold_time(_player: Player) -> float:
	match state:
		State.IDLE:
			return Config.CRYSTAL_ACTIVATE_TIME
		State.EXTRACT:
			return Config.CRYSTAL_EXTRACT_TIME
	return 0.0


## Serveur (après un maintien de E validé par l'Interactor).
func server_interact(player: Player) -> void:
	match state:
		State.IDLE:
			_start_defense(player)
		State.EXTRACT:
			_complete(player)


# =========================================================================
# Cible des monstres de vague (Monster.objective)
# =========================================================================

func can_be_hit() -> bool:
	return state == State.DEFENSE and drill_health > 0.0


func get_hit_radius() -> float:
	return HIT_RADIUS


## Serveur : un monstre frappe la foreuse.
func server_receive_hit(amount: float, _attacker_id: int) -> bool:
	if not can_be_hit():
		return false
	drill_health = maxf(drill_health - amount, 0.0)
	if drill_health <= 0.0:
		_fail()
		return true
	return false


func register_wave_monster(monster: Monster) -> void:
	_alive.append(monster)
	monsters_left = _alive.size()


func on_wave_monster_died(monster: Monster) -> void:
	_alive.erase(monster)
	monsters_left = _alive.size()
	if state != State.DEFENSE or not _alive.is_empty() or _wave_timer >= 0.0:
		return
	if wave_index < data.waves.size():
		_schedule_wave()
	else:
		state = State.EXTRACT
		print("[Quête] %s : vagues terminées, extraction possible" % name)


# =========================================================================
# Déroulement (serveur)
# =========================================================================

func _start_defense(player: Player) -> void:
	state = State.DEFENSE
	drill_health = data.drill_health
	wave_index = 0
	print("[Quête] %s (%s) lancé par %d" % [name, data.difficulty_name, player.get_peer_id()])
	Events.quest_started.emit(StringName(name), player.get_peer_id())
	_schedule_wave()


func _schedule_wave() -> void:
	_wave_timer = Config.CRYSTAL_WAVE_DELAY
	next_wave_in = Config.CRYSTAL_WAVE_DELAY


func _physics_process(delta: float) -> void:
	if state != State.DEFENSE or _wave_timer < 0.0:
		return
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = -1.0
		_spawn_wave()


func _spawn_wave() -> void:
	var wave: CampData = data.waves[wave_index]
	wave_index += 1
	next_wave_in = 0.0
	var count := 0
	for monster_data in wave.roll():
		var angle := randf() * TAU
		var dist := randf_range(Config.CRYSTAL_WAVE_SPAWN_MIN, Config.CRYSTAL_WAVE_SPAWN_MAX)
		var pos := global_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		Events.wave_spawn_requested.emit(self, monster_data, pos, data.monster_health_mult, data.monster_damage_mult)
		count += 1
	print("[Quête] %s : vague %d/%d (%d monstres)" % [name, wave_index, data.waves.size(), count])
	_update_label()


func _fail() -> void:
	state = State.FAILED
	_wave_timer = -1.0
	print("[Quête] %s : foreuse détruite" % name)
	Events.quest_failed.emit(StringName(name))
	for monster in _alive:
		if is_instance_valid(monster):
			monster.queue_free()
	_alive.clear()
	monsters_left = 0
	await get_tree().create_timer(Config.CRYSTAL_RESET_DELAY).timeout
	if is_inside_tree() and state == State.FAILED:
		state = State.IDLE


func _complete(player: Player) -> void:
	state = State.DONE
	player.score.add_objective_points(data.track, data.objective_points)
	print("[Quête] %s extrait par %d : +%d points" % [name, player.get_peer_id(), data.objective_points])
	Events.quest_completed.emit(StringName(name), player.get_peer_id(), data.objective_points)
	await get_tree().create_timer(Config.CRYSTAL_RESPAWN_DELAY).timeout
	if is_inside_tree() and state == State.DONE:
		state = State.IDLE


# =========================================================================
# Construction : synchro et visuels
# =========================================================================

func _build_sync() -> void:
	var config := SceneReplicationConfig.new()
	for key in [".:state", ".:drill_health", ".:wave_index", ".:monsters_left", ".:next_wave_in"]:
		var path := NodePath(key)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "CrystalSync"
	sync.replication_config = config
	add_child(sync)


func _build_visual() -> void:
	# Socle rocheux.
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.35, 0.32, 0.3)
	var rock := MeshInstance3D.new()
	var rock_mesh := CylinderMesh.new()
	rock_mesh.top_radius = 1.0
	rock_mesh.bottom_radius = 1.4
	rock_mesh.height = 0.5
	rock_mesh.radial_segments = 7
	rock.mesh = rock_mesh
	rock.material_override = rock_mat
	rock.position.y = 0.25
	add_child(rock)

	# Grappe de cristaux (prismes), lumineux, couleur selon la difficulté.
	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.albedo_color = data.color
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = data.color
	_crystal_mat.emission_energy_multiplier = 1.5
	_crystal_mat.roughness = 0.2
	var shards := [
		[Vector3(0, 0.4, 0), 2.0, 0.35, Vector3.ZERO],
		[Vector3(0.4, 0.4, 0.2), 1.3, 0.25, Vector3(0, 0, -0.35)],
		[Vector3(-0.35, 0.4, -0.25), 1.5, 0.25, Vector3(0.3, 0, 0.3)],
		[Vector3(0.1, 0.4, -0.45), 1.0, 0.2, Vector3(0.4, 0, 0)],
	]
	for s in shards:
		var shard := MeshInstance3D.new()
		var prism := CylinderMesh.new()
		prism.top_radius = 0.0
		prism.bottom_radius = s[2]
		prism.height = s[1]
		prism.radial_segments = 6
		prism.rings = 1
		shard.mesh = prism
		shard.material_override = _crystal_mat
		shard.position = s[0] + Vector3.UP * s[1] / 2.0
		shard.rotation = s[3]
		add_child(shard)

	var light := OmniLight3D.new()
	light.light_color = data.color
	light.omni_range = 5.0
	light.light_energy = 1.2
	light.position.y = 1.5
	add_child(light)

	# Foreuse : 4 pieds + une mèche qui tourne au-dessus du cristal (cachée en IDLE).
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.8, 0.6, 0.2)
	metal.metallic = 0.6
	_drill = Node3D.new()
	add_child(_drill)
	for i in 4:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.15, 3.4, 0.15)
		leg.mesh = leg_mesh
		leg.material_override = metal
		var a := TAU * i / 4.0 + PI / 4.0
		leg.position = Vector3(cos(a) * 1.2, 1.6, sin(a) * 1.2)
		leg.rotation = Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25)
		_drill.add_child(leg)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(1.0, 0.5, 1.0)
	head.mesh = head_mesh
	head.material_override = metal
	head.position.y = 3.3
	_drill.add_child(head)
	_bit = Node3D.new()
	_bit.position.y = 3.05
	_drill.add_child(_bit)
	var bit := MeshInstance3D.new()
	var bit_mesh := CylinderMesh.new()
	bit_mesh.top_radius = 0.25
	bit_mesh.bottom_radius = 0.0
	bit_mesh.height = 0.8
	bit_mesh.radial_segments = 5
	bit.mesh = bit_mesh
	var bit_mat := StandardMaterial3D.new()
	bit_mat.albedo_color = Color(0.4, 0.4, 0.45)
	bit.material_override = bit_mat
	bit.position.y = -0.4
	_bit.add_child(bit)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 64
	_label.outline_size = 14
	_label.pixel_size = 0.007
	_label.position.y = 4.4
	add_child(_label)


func _update_look() -> void:
	if _drill == null:
		return
	_drill.visible = state == State.DEFENSE or state == State.EXTRACT
	var dim := state == State.DONE
	_crystal_mat.emission_enabled = not dim
	_crystal_mat.albedo_color = data.color.darkened(0.7) if dim else data.color
	_update_label()


func _update_label() -> void:
	if _label == null:
		return
	var title := "%s %s" % [data.display_name, data.difficulty_name]
	match state:
		State.IDLE:
			_label.text = "%s\n+%d pts de Forage" % [title, data.objective_points]
			_label.modulate = data.color
		State.DEFENSE:
			var wave_text := ""
			if next_wave_in > 0.0:
				wave_text = "Vague %d/%d dans %d s" % [wave_index + 1, data.waves.size(), ceili(next_wave_in)]
			else:
				wave_text = "Vague %d/%d — %d monstres" % [wave_index, data.waves.size(), monsters_left]
			_label.text = "Foreuse %d / %d\n%s" % [ceili(drill_health), int(data.drill_health), wave_text]
			_label.modulate = Color(1, 0.9, 0.5).lerp(Color(1, 0.3, 0.25), 1.0 - drill_health / data.drill_health)
		State.EXTRACT:
			_label.text = "%s\nExtraction prête !" % title
			_label.modulate = Color(0.5, 1, 0.5)
		State.DONE:
			_label.text = "%s\nÉpuisé" % title
			_label.modulate = Color(1, 1, 1, 0.5)
		State.FAILED:
			_label.text = "%s\nForeuse détruite !" % title
			_label.modulate = Color(1, 0.3, 0.25)
