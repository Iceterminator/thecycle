class_name EvacShip
extends Node3D
## Vaisseau d'évacuation (étape 6), construit en code par World sur tous les peers
## (même chemin partout, pour les RPC). Formes simples : une soute surélevée fermée sur
## trois côtés, une seule porte et une seule rampe d'accès (le point chaud de la partie).
## Sous le plancher, on peut passer accroupi (le Cœur stellaire est posé au centre).
##
## Serveur : descend sur Events.evac_landed, repart sur Events.evac_departed, revient
## au ciel sur Events.match_reset_requested. Une fois posé, un joueur vivant qui reste
## Config.EVAC_BOARD_TIME s dans la soute embarque (Events.player_evacuated).
## Le compteur repart de zéro s'il sort de la soute ou meurt.

enum State { SKY, LANDING, LANDED, DEPARTING }

const HULL_COLOR := Color(0.55, 0.58, 0.62)
const BAY_COLOR := Color(0.3, 0.9, 0.6)
const PROGRESS_SEND_INTERVAL := 0.1  ## s entre deux envois de progression au joueur
## Soute (coordonnées locales) : |x| < BAY_HALF.x, |z| < BAY_HALF.y, pieds entre ces hauteurs.
const BAY_HALF := Vector2(3.7, 4.7)
const BAY_MIN_Y := 1.3
const BAY_MAX_Y := 4.2

## Joueurs (Players de World), donné par World avant l'ajout à l'arbre.
var players_root: Node3D
var state: State = State.SKY

var _tween: Tween
var _bay_floor_mat: StandardMaterial3D
var _beacon: Label3D
# --- Serveur ---
var _progress: Dictionary = {}  # peer_id -> secondes passées dans la soute
var _send_left: float = 0.0


func _ready() -> void:
	_build()
	_apply_state(State.SKY, false)
	set_physics_process(multiplayer.is_server())
	if not multiplayer.is_server():
		return
	Events.evac_landed.connect(func() -> void: _set_state(State.LANDING))
	Events.evac_departed.connect(func() -> void: _set_state(State.DEPARTING))
	Events.match_reset_requested.connect(func() -> void: _set_state(State.SKY))
	Events.player_joined.connect(_on_player_joined)


# =========================================================================
# Serveur
# =========================================================================

func _set_state(new_state: State) -> void:
	_clear_progress()
	_sync_state.rpc(new_state, true)
	if new_state == State.LANDING:
		await get_tree().create_timer(Config.EVAC_FLIGHT_TIME).timeout
		if state == State.LANDING:
			_sync_state.rpc(State.LANDED, false)


func _physics_process(delta: float) -> void:
	if state != State.LANDED or players_root == null:
		return
	_send_left -= delta
	var send := _send_left <= 0.0
	if send:
		_send_left = PROGRESS_SEND_INTERVAL
	for node in players_root.get_children():
		var player := node as Player
		if player == null:
			continue
		var peer := player.get_peer_id()
		var inside := not player.health.is_dead and not player.is_evacuated and is_in_bay(player.global_position)
		if not inside:
			if _progress.has(peer):
				_progress.erase(peer)
				_board_progress.rpc_id(peer, 0.0)
			continue
		var t: float = _progress.get(peer, 0.0) + delta
		if t >= Config.EVAC_BOARD_TIME:
			_progress.erase(peer)
			_board_progress.rpc_id(peer, 0.0)
			Events.player_evacuated.emit(peer)
			continue
		_progress[peer] = t
		if send:
			_board_progress.rpc_id(peer, t / Config.EVAC_BOARD_TIME)


func is_in_bay(world_pos: Vector3) -> bool:
	var p := to_local(world_pos)
	return absf(p.x) < BAY_HALF.x and absf(p.z) < BAY_HALF.y and p.y > BAY_MIN_Y and p.y < BAY_MAX_Y


func _clear_progress() -> void:
	for peer: int in _progress:
		if peer in multiplayer.get_peers() or peer == 1:
			_board_progress.rpc_id(peer, 0.0)
	_progress.clear()


func _on_player_joined(peer_id: int) -> void:
	await get_tree().create_timer(1.0).timeout
	if peer_id in multiplayer.get_peers():
		_sync_state.rpc_id(peer_id, state, false)


# =========================================================================
# Tous les peers
# =========================================================================

@rpc("authority", "call_local", "reliable")
func _sync_state(new_state: int, animate: bool) -> void:
	_apply_state(new_state as State, animate)


@rpc("authority", "call_local", "reliable")
func _board_progress(ratio: float) -> void:
	Events.evac_board_progress.emit(ratio)


func _apply_state(new_state: State, animate: bool) -> void:
	state = new_state
	if _tween:
		_tween.kill()
	var ground := Config.EVAC_POSITION
	var sky := ground + Vector3.UP * Config.EVAC_SKY_HEIGHT
	_beacon.visible = state == State.LANDING or state == State.LANDED
	_bay_floor_mat.emission_enabled = state == State.LANDED
	match state:
		State.SKY:
			visible = false
			global_position = sky
		State.LANDING:
			visible = true
			if animate:
				global_position = sky
				_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				_tween.tween_property(self, "global_position", ground, Config.EVAC_FLIGHT_TIME)
			else:
				global_position = ground
		State.LANDED:
			visible = true
			global_position = ground
		State.DEPARTING:
			visible = true
			_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_tween.tween_property(self, "global_position", sky, Config.EVAC_FLIGHT_TIME if animate else 0.01)
			_tween.tween_callback(func() -> void: visible = false)


# =========================================================================
# Construction (formes simples, collisions sur la couche « monde »)
# =========================================================================

func _build() -> void:
	var body := StaticBody3D.new()
	body.name = "Hull"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var hull := StandardMaterial3D.new()
	hull.albedo_color = HULL_COLOR
	_bay_floor_mat = StandardMaterial3D.new()
	_bay_floor_mat.albedo_color = BAY_COLOR.darkened(0.5)
	_bay_floor_mat.emission = BAY_COLOR
	_bay_floor_mat.emission_energy_multiplier = 0.6

	# Plancher de la soute (dessus à 1,5 m) : on passe dessous accroupi.
	_box(body, Vector3(8, 0.3, 10), Vector3(0, 1.35, 0), 0.0, _bay_floor_mat)
	# Murs gauche, droit, arrière, toit.
	_box(body, Vector3(0.5, 4.2, 10.5), Vector3(-4.25, 3.6, 0), 0.0, hull)
	_box(body, Vector3(0.5, 4.2, 10.5), Vector3(4.25, 3.6, 0), 0.0, hull)
	_box(body, Vector3(9.0, 4.2, 0.5), Vector3(0, 3.6, -5.25), 0.0, hull)
	_box(body, Vector3(9.5, 0.5, 11.5), Vector3(0, 5.95, 0), 0.0, hull)
	# Façade avant avec une seule porte de 3 m (de 1,5 m à 4 m de haut).
	_box(body, Vector3(3.0, 4.2, 0.5), Vector3(-2.75, 3.6, 5.25), 0.0, hull)
	_box(body, Vector3(3.0, 4.2, 0.5), Vector3(2.75, 3.6, 5.25), 0.0, hull)
	_box(body, Vector3(2.5, 1.7, 0.5), Vector3(0, 4.85, 5.25), 0.0, hull)
	# Rampe : du seuil de la porte (z = 5,5, y = 1,5) jusqu'au sol (z = 10,5, y = 0).
	var ramp_angle := -atan2(1.5, 5.0)
	_box(body, Vector3(3.0, 0.25, 5.25), Vector3(0, 0.7, 8.0), ramp_angle, hull)
	# Pieds sous le plancher, aux quatre coins.
	for corner: Vector2 in [Vector2(-3.6, -4.6), Vector2(3.6, -4.6), Vector2(-3.6, 4.6), Vector2(3.6, 4.6)]:
		_box(body, Vector3(0.4, 1.2, 0.4), Vector3(corner.x, 0.6, corner.y), 0.0, hull)

	_beacon = Label3D.new()
	_beacon.text = "ÉVAC"
	_beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_beacon.no_depth_test = true
	_beacon.fixed_size = true
	_beacon.pixel_size = 0.0012
	_beacon.font_size = 36
	_beacon.outline_size = 10
	_beacon.modulate = Color(0.6, 0.85, 1.0)
	_beacon.position = Vector3(0, 8.5, 0)
	add_child(_beacon)


func _box(body: StaticBody3D, size: Vector3, pos: Vector3, rot_x: float, mat: Material) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	shape.rotation.x = rot_x
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = mat
	mesh.mesh = box_mesh
	mesh.position = pos
	mesh.rotation.x = rot_x
	add_child(mesh)
