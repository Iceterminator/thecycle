class_name Weapon
extends Node
## Arme hitscan du joueur, paramétrée par un WeaponData (.tres).
##
## Client propriétaire : lit le clic, gère cadence / chargeur / recul / visée pour le
## ressenti, puis DEMANDE au serveur de tirer (request_fire). Il n'annonce jamais
## « j'ai touché X ».
## Serveur : revérifie tout (propriétaire, vivant, cadence, munitions, origine),
## ajoute lui-même la dispersion, fait le raycast et applique les dégâts.
##
## Le nœud a l'autorité du client (héritée du Player) : les RPC venant du serveur
## sont donc en "any_peer" et vérifient que l'expéditeur est bien 1.

signal ammo_changed(ammo: int, magazine_size: int, reloading: bool)
signal hit_confirmed(headshot: bool, killed: bool)

enum HitKind { NONE, WORLD, TARGET }

## Arme en main : suit l'emplacement actif de l'Inventory (synchronisé par le serveur).
var data: WeaponData

@onready var player: Player = get_parent()
@onready var head: Node3D = $"../Head"
@onready var camera: Camera3D = $"../Head/Camera3D"
@onready var health: Health = $"../Health"
@onready var inventory: Inventory = $"../Inventory"

# --- État client (prédiction locale, pour le ressenti) ---
var ammo: int = 0
var is_reloading: bool = false
var is_aiming: bool = false
var _fire_cooldown: float = 0.0
var _reload_left: float = 0.0

# --- État serveur (c'est lui qui fait foi ; le chargeur est dans Inventory.slot_ammo) ---
var _srv_reload_end_ms: int = 0
var _srv_switch_until_ms: int = 0
var _srv_tokens: float = 0.0
var _srv_last_ms: int = 0

var _tracer_mat: StandardMaterial3D
var _impact_mesh: SphereMesh
var _impact_mat_world: StandardMaterial3D
var _impact_mat_player: StandardMaterial3D


func _ready() -> void:
	data = inventory.get_active_weapon()
	ammo = inventory.get_active_ammo()
	_srv_tokens = Config.FIRE_BURST_TOLERANCE
	_srv_last_ms = Time.get_ticks_msec()
	inventory.active_weapon_changed.connect(_on_active_weapon_changed)
	set_process(player.is_multiplayer_authority())
	_build_effect_resources()


## Changement d'arme (sur tous les peers, quand le serveur change l'emplacement actif).
func _on_active_weapon_changed() -> void:
	var new_data := inventory.get_active_weapon()
	if new_data == null:
		return
	data = new_data
	ammo = inventory.get_active_ammo()
	is_reloading = false
	_reload_left = 0.0
	_fire_cooldown = Config.WEAPON_SWITCH_TIME
	if multiplayer.is_server():
		_srv_reload_end_ms = 0
		_srv_switch_until_ms = Time.get_ticks_msec() + int(Config.WEAPON_SWITCH_TIME * 900.0)
		# Le client peut ne pas voir le changement (même modèle d'arme échangé) :
		# on lui renvoie le bon chargeur.
		_sync_ammo.rpc_id(player.get_peer_id(), ammo)
	_emit_ammo()


# =========================================================================
# Client propriétaire
# =========================================================================

func _process(delta: float) -> void:
	if data == null:
		return
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	var can_act := not health.is_dead and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	is_aiming = can_act and Input.is_action_pressed("aim")
	var target_fov: float = Config.ADS_FOV if is_aiming else Config.DEFAULT_FOV
	camera.fov = lerpf(camera.fov, target_fov, 15.0 * delta)

	if is_reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			is_reloading = false
			ammo = data.magazine_size
			_emit_ammo()
		return
	if not can_act:
		return
	if Input.is_action_just_pressed("reload") and ammo < data.magazine_size:
		_start_reload()
	elif _wants_to_fire() and _fire_cooldown <= 0.0:
		if ammo <= 0:
			_start_reload()
		else:
			_fire()


## Automatique : on tire tant que le clic est maintenu. Semi-auto : un clic = un tir.
func _wants_to_fire() -> bool:
	if data.automatic:
		return Input.is_action_pressed("fire")
	return Input.is_action_just_pressed("fire")


func _fire() -> void:
	ammo -= 1
	_fire_cooldown += data.get_fire_interval()
	request_fire.rpc_id(1, camera.global_position, -camera.global_basis.z, is_aiming)
	_apply_recoil()
	_emit_ammo()


func _start_reload() -> void:
	is_reloading = true
	_reload_left = data.reload_time
	request_reload.rpc_id(1)
	_emit_ammo()


func _apply_recoil() -> void:
	var kick := deg_to_rad(data.recoil_deg) * (0.5 if is_aiming else 1.0)
	head.rotation.x = clampf(head.rotation.x + kick, deg_to_rad(-89), deg_to_rad(89))
	player.rotate_y(randf_range(-0.3, 0.3) * kick)


func _emit_ammo() -> void:
	ammo_changed.emit(ammo, data.magazine_size, is_reloading)


## Le serveur corrige le chargeur du client (refus de tir, réapparition).
@rpc("any_peer", "call_local", "reliable")
func _sync_ammo(value: int) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	ammo = value
	is_reloading = false
	_emit_ammo()


@rpc("any_peer", "call_local", "reliable")
func _confirm_hit(headshot: bool, killed: bool) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	hit_confirmed.emit(headshot, killed)


# =========================================================================
# Serveur
# =========================================================================

@rpc("any_peer", "call_local", "reliable")
func request_reload() -> void:
	if not multiplayer.is_server() or not _sender_is_owner():
		return
	if health.is_dead or _srv_reload_end_ms > 0 or inventory.get_active_ammo() >= data.magazine_size:
		return
	inventory.cancel_use()
	# 10 % de marge : la demande de rechargement et les tirs suivants n'arrivent
	# pas forcément avec le même délai.
	_srv_reload_end_ms = Time.get_ticks_msec() + int(data.reload_time * 900.0)


@rpc("any_peer", "call_local", "reliable")
func request_fire(origin: Vector3, direction: Vector3, aiming: bool) -> void:
	if not multiplayer.is_server():
		return
	if not _sender_is_owner():
		push_warning("[Weapon] Tir refusé : le peer %d tire avec l'arme du joueur %d" % [multiplayer.get_remote_sender_id(), player.get_peer_id()])
		return
	if health.is_dead:
		return
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.01:
		return

	var now := Time.get_ticks_msec()
	# Changement d'arme en cours ?
	if now < _srv_switch_until_ms:
		return
	# Rechargement en cours ?
	if _srv_reload_end_ms > 0:
		if now < _srv_reload_end_ms:
			return
		inventory.set_active_ammo(data.magazine_size)
		_srv_reload_end_ms = 0
	if inventory.get_active_ammo() <= 0:
		_sync_ammo.rpc_id(player.get_peer_id(), 0)
		return

	# Cadence : seau de jetons. On tolère quelques tirs d'avance (gigue réseau)
	# mais sur la durée on ne peut pas dépasser fire_rate_rpm.
	var interval := data.get_fire_interval()
	_srv_tokens = minf(_srv_tokens + (now - _srv_last_ms) / 1000.0 / interval, Config.FIRE_BURST_TOLERANCE)
	_srv_last_ms = now
	if _srv_tokens < 1.0:
		return
	_srv_tokens -= 1.0

	# L'origine doit être proche des yeux du joueur tels que le serveur les voit.
	if origin.distance_to(camera.global_position) > Config.SHOT_ORIGIN_TOLERANCE:
		push_warning("[Weapon] Tir refusé : origine trop loin du joueur %d" % player.get_peer_id())
		return

	inventory.set_active_ammo(inventory.get_active_ammo() - 1)
	inventory.cancel_use()  # tirer interrompt un soin
	# Le flag « visée » vient du client : au pire un tricheur obtient la précision ADS.
	var spread := data.ads_spread_deg if aiming else data.spread_deg
	for i in data.pellets:
		_server_trace(origin, _apply_spread(direction.normalized(), spread))


func _server_trace(origin: Vector3, dir: Vector3) -> void:
	var to := origin + dir * data.range_m
	var query := PhysicsRayQueryParameters3D.create(origin, to)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	var end := to
	var kind := HitKind.NONE
	if not hit.is_empty():
		end = hit["position"]
		kind = HitKind.WORLD
		# Cible touchable (joueur, monstre) : groupe "damageable" avec
		# can_be_hit(), is_headshot(point) et server_receive_hit(dégâts, attaquant).
		var target := hit["collider"] as Node
		if target and target.is_in_group("damageable") and target.can_be_hit():
			kind = HitKind.TARGET
			var headshot: bool = target.is_headshot(end)
			var damage := data.get_damage() * (data.headshot_multiplier if headshot else 1.0)
			var killed: bool = target.server_receive_hit(damage, player.get_peer_id())
			_confirm_hit.rpc_id(player.get_peer_id(), headshot, killed)
	_show_shot.rpc(origin, end, kind)


## Réapparition : à appeler après Inventory.reset_loadout().
func server_refill() -> void:
	_srv_reload_end_ms = 0
	_srv_switch_until_ms = 0
	_srv_tokens = Config.FIRE_BURST_TOLERANCE
	_srv_last_ms = Time.get_ticks_msec()
	_sync_ammo.rpc_id(player.get_peer_id(), inventory.get_active_ammo())


func _sender_is_owner() -> bool:
	return multiplayer.get_remote_sender_id() == player.get_peer_id()


## Direction aléatoire dans un cône de `spread_deg` degrés autour de `dir`.
static func _apply_spread(dir: Vector3, spread_deg: float) -> Vector3:
	if spread_deg <= 0.0:
		return dir
	var axis := dir.cross(Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT).normalized()
	var angle := deg_to_rad(spread_deg) * sqrt(randf())
	return dir.rotated(axis, angle).rotated(dir, randf() * TAU)


# =========================================================================
# Effets visuels (tous les clients)
# =========================================================================

@rpc("any_peer", "call_local", "unreliable")
func _show_shot(origin: Vector3, end: Vector3, kind: int) -> void:
	if multiplayer.get_remote_sender_id() != 1 or Net.is_dedicated_server:
		return
	var world := player.get_parent().get_parent() as Node3D
	if world == null:
		return
	# La traînée part « du canon » (un peu à droite et en dessous des yeux).
	var from := origin + camera.global_basis * Vector3(0.18, -0.15, -0.4)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _tracer_mat)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(end)
	mesh.surface_end()
	var tracer := MeshInstance3D.new()
	tracer.mesh = mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(tracer)
	get_tree().create_timer(0.06).timeout.connect(tracer.queue_free)

	if kind != HitKind.NONE:
		var impact := MeshInstance3D.new()
		impact.mesh = _impact_mesh
		impact.material_override = _impact_mat_player if kind == HitKind.TARGET else _impact_mat_world
		impact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(impact)
		impact.global_position = end
		get_tree().create_timer(0.15).timeout.connect(impact.queue_free)


func _build_effect_resources() -> void:
	_tracer_mat = StandardMaterial3D.new()
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_mat.albedo_color = Color(1.0, 0.9, 0.5)
	_impact_mesh = SphereMesh.new()
	_impact_mesh.radius = 0.06
	_impact_mesh.height = 0.12
	_impact_mat_world = StandardMaterial3D.new()
	_impact_mat_world.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_impact_mat_world.albedo_color = Color(1.0, 0.85, 0.4)
	_impact_mat_player = StandardMaterial3D.new()
	_impact_mat_player.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_impact_mat_player.albedo_color = Color(1.0, 0.15, 0.1)
