class_name StormManager
extends Node3D
## Tempête façon « zone qui se referme » (étape 7). Créée en code par World sur tous les
## peers (même chemin partout, pour les RPC).
##
## Les phases viennent de data/storm/*.tres (StormPhaseData). Au début de chaque partie, le
## serveur tire les centres des zones : la dernière est centrée sur l'évac, chaque zone
## contient la suivante. Il envoie ce « plan » aux clients ; ensuite tout l'état de la
## tempête (centre, rayon, dégâts, avertissement) se calcule à partir du temps de partie
## (MatchManager.elapsed), sur le serveur comme chez les clients : les sauts de temps du
## menu admin marchent sans rien de plus.
##
## Serveur : hors de la zone sûre, les joueurs prennent damage_per_second (même à l'abri),
## toutes les Config.STORM_TICK s. Clients : mur de tempête, brouillard et éclairs.
## Les monstres et le HUD lisent l'état via les fonctions statiques (is_in_storm, hud_text).

const PHASES_DIR := "res://data/storm/"
const WALL_HEIGHT := 140.0
const STORM_COLOR := Color(0.55, 0.25, 0.85)
const ANNOUNCE_COLOR := Color(0.8, 0.55, 1.0)
const STORM_FOG_DENSITY := 0.035

## Instance active (une seule partie par processus) : lue par les fonctions statiques.
static var _current: StormManager

var phases: Array[StormPhaseData] = []
## Centre de la zone sûre de chaque phase (même index que `phases`).
var centers: Array[Vector2] = []

var _world: World
var _tick_left: float = 0.0
var _last_elapsed: float = 0.0
# --- Visuels (clients) ---
var _wall: MeshInstance3D
var _next_ring: MeshInstance3D
var _flash: ColorRect
var _env: Environment
var _base_fog_density: float = 0.0
var _base_fog_color: Color
var _lightning_left: float = 2.0


func _ready() -> void:
	_current = self
	_world = get_parent() as World
	_load_phases()
	if not Net.is_dedicated_server:
		_build_visuals()
	if multiplayer.is_server():
		Events.match_reset_requested.connect(_new_plan)
		Events.player_joined.connect(_on_player_joined)
		_new_plan()


func _exit_tree() -> void:
	if _current == self:
		_current = null


func _load_phases() -> void:
	for file in ResourceLoader.list_directory(PHASES_DIR):
		var phase: StormPhaseData = load(PHASES_DIR + file) as StormPhaseData if file.ends_with(".tres") else null
		if phase:
			phases.append(phase)
	phases.sort_custom(func(a: StormPhaseData, b: StormPhaseData) -> bool: return a.start_time < b.start_time)


# =========================================================================
# Calcul de l'état (serveur et clients, à partir du temps de partie)
# =========================================================================

func _elapsed() -> float:
	return _world.match_manager.elapsed if _world and _world.match_manager else 0.0


## { active, center, radius, damage, next (index de la phase annoncée ou -1), next_in (s) }
func compute_state(elapsed: float) -> Dictionary:
	var center := Vector2.ZERO
	var radius := Config.STORM_START_RADIUS
	var damage := 0.0
	var active := false
	var next := -1
	var next_in := 0.0
	for i in phases.size():
		var phase := phases[i]
		var target := centers[i] if i < centers.size() else Vector2.ZERO
		if elapsed < phase.start_time:
			if elapsed >= phase.start_time - phase.warning_time:
				next = i
				next_in = phase.start_time - elapsed
			break
		active = true
		damage = phase.damage_per_second
		var t := clampf((elapsed - phase.start_time) / maxf(phase.shrink_duration, 0.01), 0.0, 1.0)
		center = center.lerp(target, t)
		radius = lerpf(radius, phase.radius, t)
		if t < 1.0:
			next = i  # zone visée pendant la fermeture
			next_in = 0.0
			break
	return {"active": active, "center": center, "radius": radius, "damage": damage, "next": next, "next_in": next_in}


static func is_in_storm(pos: Vector3) -> bool:
	if _current == null:
		return false
	var s := _current.compute_state(_current._elapsed())
	return s["active"] and Vector2(pos.x, pos.z).distance_to(s["center"]) > s["radius"]


## Texte du HUD pour un joueur à `pos` ("" = rien à afficher).
static func hud_text(pos: Vector3) -> String:
	if _current == null:
		return ""
	var s := _current.compute_state(_current._elapsed())
	var lines: PackedStringArray = []
	var next: int = s["next"]
	if next >= 0 and s["next_in"] > 0.0:
		lines.append("La tempête se referme dans %d s" % ceili(s["next_in"]))
	elif next >= 0:
		lines.append("La tempête se referme !")
	if s["active"]:
		var out: float = Vector2(pos.x, pos.z).distance_to(s["center"]) - s["radius"]
		if out > 0.0:
			lines.append("DANS LA TEMPÊTE : -%d PV/s — zone sûre à %d m" % [int(s["damage"]), ceili(out)])
	return "\n".join(lines)


# =========================================================================
# Serveur
# =========================================================================

func _new_plan() -> void:
	# Dernière zone : centrée sur l'évac ; chaque zone contient entièrement la suivante.
	var n := phases.size()
	var plan: Array[Vector2] = []
	plan.resize(n)
	var evac := Vector2(Config.EVAC_POSITION.x, Config.EVAC_POSITION.z)
	for i in range(n - 1, -1, -1):
		if i == n - 1:
			plan[i] = evac
		else:
			var slack := maxf(phases[i].radius - phases[i + 1].radius, 0.0)
			plan[i] = plan[i + 1] + Vector2.from_angle(randf() * TAU) * randf() * slack
	_last_elapsed = 0.0
	_sync_plan.rpc(plan)


func _on_player_joined(peer_id: int) -> void:
	await get_tree().create_timer(1.0).timeout
	if peer_id in multiplayer.get_peers():
		_sync_plan.rpc_id(peer_id, centers)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)


func _server_tick(delta: float) -> void:
	var elapsed := _elapsed()
	# Annonces quand l'horloge franchit un avertissement ou un début de phase.
	for phase in phases:
		var warn := phase.start_time - phase.warning_time
		if _last_elapsed < warn and elapsed >= warn:
			Events.storm_warning.emit(phase.warning_time)
			Events.announce_requested.emit("La tempête se referme dans %d s ! Rejoignez la zone sûre." % int(phase.warning_time), ANNOUNCE_COLOR)
		if _last_elapsed < phase.start_time and elapsed >= phase.start_time:
			Events.announce_requested.emit("La tempête se referme ! Hors de la zone : -%d PV/s" % int(phase.damage_per_second), ANNOUNCE_COLOR)
	_last_elapsed = elapsed

	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = Config.STORM_TICK
	var s := compute_state(elapsed)
	if not s["active"] or _world == null:
		return
	for node in _world.players.get_children():
		var player := node as Player
		if player == null or not player.can_be_hit():
			continue
		if Vector2(player.global_position.x, player.global_position.z).distance_to(s["center"]) > s["radius"]:
			player.server_receive_hit(s["damage"] * Config.STORM_TICK, Config.STORM_KILLER_ID)


@rpc("authority", "call_local", "reliable")
func _sync_plan(plan: Array) -> void:
	centers.clear()
	for c in plan:
		centers.append(c)


# =========================================================================
# Visuels (clients)
# =========================================================================

func _process(delta: float) -> void:
	if _wall == null:
		return
	var s := compute_state(_elapsed())
	# Mur de la zone sûre actuelle, visible dès le premier avertissement.
	var shown: bool = s["active"] or s["next"] >= 0
	_wall.visible = shown
	if shown:
		_place_cylinder(_wall, s["center"], s["radius"])
	var next: int = s["next"]
	_next_ring.visible = next >= 0 and next < centers.size()
	if _next_ring.visible:
		_place_cylinder(_next_ring, centers[next], phases[next].radius)
	# Brouillard et éclairs si le joueur local est dans la tempête.
	var me := _local_player()
	var inside: bool = me != null and not me.is_evacuated and s["active"] \
			and Vector2(me.global_position.x, me.global_position.z).distance_to(s["center"]) > s["radius"]
	if _env:
		var target_density := STORM_FOG_DENSITY if inside else _base_fog_density
		_env.fog_density = lerpf(_env.fog_density, target_density, clampf(2.0 * delta, 0.0, 1.0))
		_env.fog_light_color = _base_fog_color.lerp(STORM_COLOR, clampf((_env.fog_density - _base_fog_density) / STORM_FOG_DENSITY, 0.0, 1.0))
	if inside:
		_lightning_left -= delta
		if _lightning_left <= 0.0:
			_lightning_left = randf_range(1.5, 4.0)
			_flash.modulate.a = 0.55
	_flash.modulate.a = maxf(_flash.modulate.a - 3.0 * delta, 0.0)


func _local_player() -> Player:
	if _world == null:
		return null
	return _world.get_player(multiplayer.get_unique_id())


func _place_cylinder(mesh: MeshInstance3D, center: Vector2, radius: float) -> void:
	mesh.global_position = Vector3(center.x, WALL_HEIGHT / 2.0 - 5.0, center.y)
	mesh.scale = Vector3(radius, 1.0, radius)


func _build_visuals() -> void:
	_wall = _make_cylinder(Color(STORM_COLOR, 0.35))
	_next_ring = _make_cylinder(Color(1, 1, 1, 0.12))
	var env_node := _world.get_node_or_null("WorldEnvironment") as WorldEnvironment if _world else null
	if env_node and env_node.environment:
		_env = env_node.environment
		_base_fog_density = _env.fog_density
		_base_fog_color = _env.fog_light_color
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_flash = ColorRect.new()
	_flash.color = Color(0.85, 0.8, 1.0)
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Cylindre ouvert de rayon 1 (mis à l'échelle), visible des deux côtés.
func _make_cylinder(color: Color) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = WALL_HEIGHT
	cyl.radial_segments = 96
	cyl.cap_top = false
	cyl.cap_bottom = false
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	cyl.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = cyl
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visible = false
	add_child(mesh)
	return mesh



## Carte et minimap : zone sûre actuelle (si la tempête a commencé) et prochaine zone
## (si annoncée). { active, center, radius, has_next, next_center, next_radius }
static func map_circles() -> Dictionary:
	if _current == null:
		return {"active": false, "has_next": false}
	var s := _current.compute_state(_current._elapsed())
	var next: int = s["next"]
	var has_next := next >= 0 and next < _current.centers.size()
	return {
		"active": s["active"],
		"center": s["center"],
		"radius": s["radius"],
		"has_next": has_next,
		"next_center": _current.centers[next] if has_next else Vector2.ZERO,
		"next_radius": _current.phases[next].radius if has_next else 0.0,
	}
