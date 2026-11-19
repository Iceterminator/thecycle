class_name DropPodRide
extends Node
## Largage d'un joueur en capsule (enfant « Drop » du joueur, créé sur tous les peers).
## Le SERVEUR décide des étapes (descente -> posée -> ouverte) et les envoie à tous (_sync) ;
## chaque peer garde l'état et l'heure locale de réception. Le déplacement étant décidé par
## le client, seul le propriétaire applique la trajectoire (déterministe : step()) ; les autres
## voient la capsule suivre la position répliquée du joueur.
## Tant que ce n'est pas fini (is_active), le joueur est figé et invulnérable (voir Player.is_dropping).

enum State { NONE, FALLING, LANDED }

var state: State = State.NONE

var _ground := Vector3.ZERO
var _start_ms: int = 0
var _generation: int = 0  ## invalide les minuteries d'un largage annulé
var _visual: DropPodVisual
var _player: Player


func _ready() -> void:
	_player = get_parent() as Player


func is_active() -> bool:
	return state != State.NONE


## Propriétaire : position imposée par la trajectoire (appelé à la place du déplacement).
func step() -> void:
	_player.velocity = Vector3.ZERO
	if state == State.NONE:
		return
	var rules := Config.match_rules
	var t := (Time.get_ticks_msec() - _start_ms) / 1000.0
	var height := 0.0
	if state == State.FALLING:
		# Rapide au début, de plus en plus lent à l'approche du sol.
		var u := clampf(t / rules.drop_pod_fall_time, 0.0, 1.0)
		height = rules.drop_pod_height * pow(1.0 - u, 1.5)
	_player.global_position = _ground + Vector3.UP * height


# =========================================================================
# Serveur
# =========================================================================

## Lance le largage vers `ground` ; la capsule s'ouvre après chute + délai, rien ne tue le joueur.
func server_start(ground: Vector3) -> void:
	_generation += 1
	var generation := _generation
	_sync.rpc(State.FALLING, ground)
	await get_tree().create_timer(Config.match_rules.drop_pod_fall_time).timeout
	if generation != _generation:
		return
	_sync.rpc(State.LANDED, ground)
	await get_tree().create_timer(Config.match_rules.drop_pod_open_delay).timeout
	if generation != _generation:
		return
	_sync.rpc(State.NONE, ground)


## Largage annulé (retour au lobby).
func server_cancel() -> void:
	_generation += 1
	if state != State.NONE:
		_sync.rpc(State.NONE, _ground)


# =========================================================================
# Tous les peers
# =========================================================================

@rpc("authority", "call_local", "reliable")
func _sync(new_state: int, ground: Vector3) -> void:
	if not ground.is_finite():
		return
	state = new_state as State
	_ground = ground
	_start_ms = Time.get_ticks_msec()
	var is_owner := _player.is_multiplayer_authority()
	match state:
		State.FALLING:
			if Net.is_dedicated_server:
				return
			_visual = DropPodVisual.new()
			_visual.name = "PodVisual"
			_player.add_child(_visual)
			if is_owner:
				step()
		State.LANDED:
			if _visual:
				_visual.land()
			if is_owner:
				step()
		State.NONE:
			if _visual and is_instance_valid(_visual):
				_visual.open()
			_visual = null
