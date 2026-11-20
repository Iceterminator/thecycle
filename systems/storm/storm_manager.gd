class_name StormManager
extends Node3D
## Grande Marée : tempête qui couvre toute la carte. Pas de zone, pas de dégâts : elle change
## l'ambiance (ciel sombre, pluie, éclairs violets, brouillard) et rend les monstres plus
## agressifs. Créée en code par World sur tous les peers.
##
## Les tempêtes viennent de data/storm/*.tres (StormPhaseData). Tout l'état se calcule à
## partir du temps de partie (MatchManager.elapsed), sur le serveur comme chez les clients :
## les sauts de temps du menu admin marchent sans rien de plus. Le serveur fait les annonces.

const StormVisuals := preload("res://systems/storm/storm_visuals.gd")
const PHASES_DIR := "res://data/storm/"
const STORM_NAME := "Grande Marée"
const WARNING_COLOR := Color(0.55, 0.9, 0.55)       ## annonce (bandeau vert)
const ANNOUNCE_COLOR := Color(0.8, 0.55, 1.0)
# Ambiance au plus fort de la tempête (on part de l'ambiance de la scène).
const STORM_FOG_DENSITY := 0.02
const BRIEFING_FOG := 0.2  ## brume réduite pendant le briefing : la carte se voit par la baie vitrée
const STORM_FOG_COLOR := Color(0.3, 0.28, 0.42)
const STORM_SKY_TOP := Color(0.13, 0.14, 0.2)
const STORM_SKY_HORIZON := Color(0.26, 0.25, 0.34)
const STORM_SUN_ENERGY := 0.25
const STORM_SUN_COLOR := Color(0.7, 0.75, 1.0)
const RAIN_HEIGHT := 12.0

## Instance active (une seule partie par processus) : lue par les fonctions statiques.
static var _current: StormManager

var phases: Array[StormPhaseData] = []

var _world: World
var _last_elapsed: float = 0.0
# --- Visuels (clients) ---
var _flash: ColorRect
var _rain: GPUParticles3D
var _env: Environment
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _base := {}  ## valeurs d'ambiance de la scène, hors tempête
var _lightning_left: float = 2.0


func _ready() -> void:
	_current = self
	_world = get_parent() as World
	_load_phases()
	if not Net.is_dedicated_server:
		StormVisuals.build(self)


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


## { active, intensity (0..1, pour les visuels), next_in (s avant la prochaine tempête annoncée, -1 sinon) }
func compute_state(elapsed: float) -> Dictionary:
	for phase in phases:
		var end := INF if phase.duration <= 0.0 else phase.start_time + phase.duration
		if elapsed < phase.start_time:
			var next_in := phase.start_time - elapsed
			return {"active": false, "intensity": 0.0, "next_in": next_in if next_in <= phase.warning_time else -1.0}
		if elapsed < end + phase.fade_time:
			var fade := maxf(phase.fade_time, 0.01)
			var intensity := minf(clampf((elapsed - phase.start_time) / fade, 0.0, 1.0), clampf((end + phase.fade_time - elapsed) / fade, 0.0, 1.0))
			return {"active": elapsed < end, "intensity": intensity, "next_in": -1.0}
	return {"active": false, "intensity": 0.0, "next_in": -1.0}


## Vrai pendant une tempête (partout sur la carte) : les monstres y sont plus agressifs.
static func is_in_storm(_pos: Vector3) -> bool:
	return _current != null and _current.compute_state(_current._elapsed())["active"]


## Texte du HUD ("" = rien à afficher).
static func hud_text(_pos: Vector3) -> String:
	if _current == null:
		return ""
	var s := _current.compute_state(_current._elapsed())
	if s["next_in"] > 0.0:
		return "La %s débute dans %d s" % [STORM_NAME, ceili(s["next_in"])]
	if s["active"]:
		return "%s en cours" % STORM_NAME.to_upper()
	return ""


# =========================================================================
# Serveur : annonces
# =========================================================================

func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	var elapsed := _elapsed()
	if elapsed < _last_elapsed:  # nouvelle partie
		_last_elapsed = elapsed
	for phase in phases:
		var warn := phase.start_time - phase.warning_time
		if _last_elapsed < warn and elapsed >= warn and elapsed < phase.start_time:
			Events.announce_requested.emit("La %s débute dans %d s !" % [STORM_NAME, int(phase.warning_time)], WARNING_COLOR)
		if _last_elapsed < phase.start_time and elapsed >= phase.start_time:
			Events.announce_requested.emit("LA %s COMMENCE — les monstres sont plus agressifs" % STORM_NAME.to_upper(), ANNOUNCE_COLOR)
			Events.storm_started.emit(phase.shard_count)
	_last_elapsed = elapsed


# =========================================================================
# Visuels (clients)
# =========================================================================

func _process(delta: float) -> void:
	if _flash == null:
		return
	var k: float = compute_state(_elapsed())["intensity"]
	if _env:
		var base_fog: float = _base["fog_density"] * (BRIEFING_FOG if MatchManager.is_briefing() else 1.0)
		_env.fog_density = lerpf(base_fog, STORM_FOG_DENSITY, k)
		_env.fog_light_color = (_base["fog_color"] as Color).lerp(STORM_FOG_COLOR, k)
	if _sky:
		_sky.sky_top_color = (_base["sky_top"] as Color).lerp(STORM_SKY_TOP, k)
		_sky.sky_horizon_color = (_base["sky_horizon"] as Color).lerp(STORM_SKY_HORIZON, k)
		_sky.ground_horizon_color = (_base["ground_horizon"] as Color).lerp(STORM_SKY_HORIZON, k)
	if _sun:
		_sun.light_energy = lerpf(_base["sun_energy"], STORM_SUN_ENERGY, k)
		_sun.light_color = (_base["sun_color"] as Color).lerp(STORM_SUN_COLOR, k)
	# Pluie autour de la caméra.
	_rain.emitting = k > 0.05
	_rain.amount_ratio = k
	var camera := get_viewport().get_camera_3d()
	if camera:
		_rain.global_position = camera.global_position + Vector3.UP * RAIN_HEIGHT
	# Éclairs violets.
	if k > 0.5:
		_lightning_left -= delta
		if _lightning_left <= 0.0:
			_lightning_left = randf_range(3.0, 8.0)
			_flash.modulate.a = 0.45
	_flash.modulate.a = maxf(_flash.modulate.a - 3.0 * delta, 0.0)
