class_name Weapon
extends Node
## Système de tir générique du joueur, entièrement piloté par un WeaponData (.tres).
## Aucune arme n'a son propre script : fire_mode et projectile_type décident de tout.
##
## Modes de tir : AUTO (maintenir), SEMI (un clic = un tir), BURST (un clic = une rafale
## de burst_count tirs espacés de burst_interval_s ; fire_interval_s sépare deux débuts
## de rafale). CHARGE, CHARGE_BURST et BEAM ne sont pas encore codés (voir WeaponData).
## Types de tir : HITSCAN (raycast immédiat) ou PROJECTILE (balle simulée par le serveur,
## qui avance de projectile_speed_mps à chaque image physique).
##
## Client propriétaire : lit le clic, gère cadence / rafale / chargeur / recul / visée pour
## le ressenti, puis DEMANDE au serveur de tirer (request_fire), une demande par balle.
## Il n'annonce jamais « j'ai touché X ».
## Serveur : revérifie tout (propriétaire, vivant, cadence, munitions, origine), ajoute
## lui-même la dispersion, fait le raycast ou simule le projectile, applique les dégâts
## (baisse avec la distance, point faible).
##
## Le nœud a l'autorité du client (héritée du Player) : les RPC venant du serveur
## sont donc en "any_peer" et vérifient que l'expéditeur est bien 1.

signal ammo_changed(ammo: int, magazine_size: int, reloading: bool)
signal hit_confirmed(headshot: bool, killed: bool)

enum HitKind { NONE, WORLD, TARGET }

const PROJECTILE_VISUAL_LENGTH := 0.6  ## longueur de la traînée d'un projectile (m)

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
var _burst_left: int = 0          # tirs restants dans la rafale en cours
var _burst_timer: float = 0.0     # s avant le prochain tir de la rafale

# --- État serveur (c'est lui qui fait foi ; le chargeur est dans Inventory.slot_ammo) ---
var _srv_reload_end_ms: int = 0
var _srv_switch_until_ms: int = 0
var _srv_tokens: float = 0.0
var _srv_last_ms: int = 0
## Projectiles en vol : { id, pos, dir, speed, travelled, max_dist, data }.
var _srv_projectiles: Array[Dictionary] = []
var _srv_next_projectile_id: int = 0

# --- Effets visuels (clients) ---
var _visual_projectiles: Dictionary[int, Node3D] = {}
var _tracer_mat: StandardMaterial3D
var _projectile_mesh: BoxMesh
var _impact_mesh: SphereMesh
var _impact_mat_world: StandardMaterial3D
var _impact_mat_player: StandardMaterial3D


func _ready() -> void:
	data = inventory.get_active_weapon()
	ammo = inventory.get_active_ammo()
	_srv_tokens = _token_capacity()
	_srv_last_ms = Time.get_ticks_msec()
	inventory.active_weapon_changed.connect(_on_active_weapon_changed)
	set_process(player.is_multiplayer_authority())
	set_physics_process(multiplayer.is_server())
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
	_burst_left = 0
	_fire_cooldown = _equip_time()
	if multiplayer.is_server():
		_srv_reload_end_ms = 0
		_srv_switch_until_ms = Time.get_ticks_msec() + int(_equip_time() * 900.0)
		_srv_tokens = minf(_srv_tokens, _token_capacity())
		# Le client peut ne pas voir le changement (même modèle d'arme échangé) :
		# on lui renvoie le bon chargeur.
		_sync_ammo.rpc_id(player.get_peer_id(), ammo)
	_emit_ammo()


func _equip_time() -> float:
	return data.equip_time_s if data.equip_time_s > 0.0 else Config.WEAPON_SWITCH_TIME


# =========================================================================
# Client propriétaire
# =========================================================================

func _process(delta: float) -> void:
	if data == null:
		return
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	var can_act := not health.is_dead and not player.is_evacuated and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	is_aiming = can_act and Input.is_action_pressed("aim")
	var target_fov: float = data.get_ads_fov(Config.ADS_FOV, Config.DEFAULT_FOV) if is_aiming else Config.DEFAULT_FOV
	# ads_time_s : temps pour faire l'essentiel du passage en visée.
	camera.fov = lerpf(camera.fov, target_fov, clampf(4.0 / maxf(data.ads_time_s, 0.05) * delta, 0.0, 1.0))

	if is_reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			is_reloading = false
			ammo = data.magazine
			_emit_ammo()
		return
	if not can_act:
		_burst_left = 0
		return

	# Rafale en cours : elle part jusqu'au bout même si on relâche le clic.
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			if ammo <= 0:
				_burst_left = 0
			else:
				_fire_one()
				_burst_left -= 1
				_burst_timer += data.burst_interval_s
		return

	if Input.is_action_just_pressed("reload") and ammo < data.magazine:
		_start_reload()
	elif _wants_to_fire() and _fire_cooldown <= 0.0:
		if ammo <= 0:
			_start_reload()
		else:
			_pull_trigger()


func _wants_to_fire() -> bool:
	if data.get_effective_fire_mode() == WeaponData.FireMode.AUTO:
		return Input.is_action_pressed("fire")
	return Input.is_action_just_pressed("fire")


## Un appui de gâchette : un tir, ou le début d'une rafale.
func _pull_trigger() -> void:
	_fire_cooldown += data.get_fire_interval()
	_fire_one()
	if data.get_effective_fire_mode() == WeaponData.FireMode.BURST:
		_burst_left = data.burst_count - 1
		_burst_timer = data.burst_interval_s


func _fire_one() -> void:
	ammo -= 1
	request_fire.rpc_id(1, camera.global_position, -camera.global_basis.z, is_aiming)
	_apply_recoil()
	_emit_ammo()


func _start_reload() -> void:
	is_reloading = true
	_burst_left = 0
	_reload_left = data.reload_s
	request_reload.rpc_id(1)
	_emit_ammo()


func _apply_recoil() -> void:
	var kick := deg_to_rad(data.recoil_deg * data.recoil_multiplier) * (0.5 if is_aiming else 1.0)
	head.rotation.x = clampf(head.rotation.x + kick, deg_to_rad(-89), deg_to_rad(89))
	player.rotate_y(randf_range(-0.3, 0.3) * kick)


func _emit_ammo() -> void:
	ammo_changed.emit(ammo, data.magazine, is_reloading)


## Le serveur corrige le chargeur du client (refus de tir, réapparition).
@rpc("any_peer", "call_local", "reliable")
func _sync_ammo(value: int) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	ammo = value
	is_reloading = false
	_burst_left = 0
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
	if health.is_dead or _srv_reload_end_ms > 0 or inventory.get_active_ammo() >= data.magazine:
		return
	inventory.cancel_use()
	# 10 % de marge : la demande de rechargement et les tirs suivants n'arrivent
	# pas forcément avec le même délai.
	_srv_reload_end_ms = Time.get_ticks_msec() + int(data.reload_s * 900.0)


## Une demande = une balle (une rafale de 3 envoie 3 demandes).
@rpc("any_peer", "call_local", "reliable")
func request_fire(origin: Vector3, direction: Vector3, aiming: bool) -> void:
	if not multiplayer.is_server():
		return
	if not _sender_is_owner():
		push_warning("[Weapon] Tir refusé : le peer %d tire avec l'arme du joueur %d" % [multiplayer.get_remote_sender_id(), player.get_peer_id()])
		return
	if health.is_dead or player.is_evacuated:
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
		inventory.set_active_ammo(data.magazine)
		_srv_reload_end_ms = 0
	if inventory.get_active_ammo() <= 0:
		_sync_ammo.rpc_id(player.get_peer_id(), 0)
		return

	# Cadence : seau de jetons. Il se remplit au rythme moyen de l'arme (une rafale
	# compte pour burst_count tirs par fire_interval_s) ; on tolère quelques tirs d'avance
	# (gigue réseau, rafale entière) mais sur la durée on ne peut pas tirer plus vite.
	_srv_tokens = minf(_srv_tokens + (now - _srv_last_ms) / 1000.0 / _server_shot_interval(), _token_capacity())
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
	var aim_spread := data.ads_spread_deg if aiming else data.hip_spread_deg * data.hipfire_spread_multiplier
	var aim_dir := _apply_spread(direction.normalized(), aim_spread)
	for i in maxi(data.pellets, 1):
		# Fusil à pompe : chaque plomb part dans le cône spread_deg autour de la visée.
		var dir := _apply_spread(aim_dir, data.spread_deg) if data.pellets > 1 else aim_dir
		if data.is_projectile():
			_server_launch_projectile(origin, dir)
		else:
			_server_trace(origin, dir)


func _server_shot_interval() -> float:
	return data.get_fire_interval() / data.get_shots_per_cycle()


func _token_capacity() -> float:
	if data == null:
		return Config.FIRE_BURST_TOLERANCE
	return maxf(Config.FIRE_BURST_TOLERANCE, data.get_shots_per_cycle() + 1.0)


func _server_trace(origin: Vector3, dir: Vector3) -> void:
	var to := origin + dir * data.get_max_range()
	var hit := _server_raycast(origin, to)
	var end := to
	var kind := HitKind.NONE
	if not hit.is_empty():
		end = hit["position"]
		kind = _server_hit(hit["collider"] as Node, end, origin.distance_to(end), data)
	_show_shot.rpc(origin, end, kind)


func _server_launch_projectile(origin: Vector3, dir: Vector3) -> void:
	_srv_next_projectile_id += 1
	_srv_projectiles.append({
		"id": _srv_next_projectile_id,
		"pos": origin,
		"dir": dir,
		"speed": data.projectile_speed_mps,
		"travelled": 0.0,
		"max_dist": data.get_max_range(),
		"data": data,  # l'arme peut changer pendant le vol
	})
	_show_projectile.rpc(_srv_next_projectile_id, origin, dir, data.projectile_speed_mps, data.get_max_range())


## Fait avancer les projectiles (serveur uniquement) : un raycast par image sur le
## segment parcouru, en ligne droite (pas de chute pour l'instant).
func _physics_process(delta: float) -> void:
	if _srv_projectiles.is_empty():
		return
	for i in range(_srv_projectiles.size() - 1, -1, -1):
		var p := _srv_projectiles[i]
		var step := minf(p["speed"] * delta, p["max_dist"] - p["travelled"])
		var from: Vector3 = p["pos"]
		var to: Vector3 = from + p["dir"] * step
		var hit := _server_raycast(from, to)
		if not hit.is_empty():
			var point: Vector3 = hit["position"]
			var distance: float = p["travelled"] + from.distance_to(point)
			var kind := _server_hit(hit["collider"] as Node, point, distance, p["data"])
			_show_projectile_end.rpc(p["id"], point, kind)
			_srv_projectiles.remove_at(i)
			continue
		p["pos"] = to
		p["travelled"] += step
		if p["travelled"] >= p["max_dist"]:
			_show_projectile_end.rpc(p["id"], to, HitKind.NONE)
			_srv_projectiles.remove_at(i)


func _server_raycast(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query)


## Applique un impact. Cible touchable (joueur, monstre) : groupe "damageable" avec
## can_be_hit(), is_headshot(point) et server_receive_hit(dégâts, attaquant).
func _server_hit(target: Node, point: Vector3, distance: float, wdata: WeaponData) -> HitKind:
	if target == null or not target.is_in_group("damageable") or not target.can_be_hit():
		return HitKind.WORLD
	var headshot: bool = target.is_headshot(point)
	var damage := wdata.get_hit_damage() * wdata.get_falloff_multiplier(distance)
	if headshot:
		damage *= wdata.weakspot_multiplier
	var killed: bool = target.server_receive_hit(damage, player.get_peer_id())
	_confirm_hit.rpc_id(player.get_peer_id(), headshot, killed)
	return HitKind.TARGET


## Réapparition : à appeler après Inventory.reset_loadout().
func server_refill() -> void:
	_srv_reload_end_ms = 0
	_srv_switch_until_ms = 0
	_srv_tokens = _token_capacity()
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

func _effects_parent() -> Node3D:
	if Net.is_dedicated_server:
		return null
	return player.get_parent().get_parent() as Node3D


## Point de départ visuel « du canon » (un peu à droite et en dessous des yeux).
func _muzzle(origin: Vector3) -> Vector3:
	return origin + camera.global_basis * Vector3(0.18, -0.15, -0.4)


@rpc("any_peer", "call_local", "unreliable")
func _show_shot(origin: Vector3, end: Vector3, kind: int) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	var world := _effects_parent()
	if world == null:
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _tracer_mat)
	mesh.surface_add_vertex(_muzzle(origin))
	mesh.surface_add_vertex(end)
	mesh.surface_end()
	var tracer := MeshInstance3D.new()
	tracer.mesh = mesh
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(tracer)
	get_tree().create_timer(0.06).timeout.connect(tracer.queue_free)
	_spawn_impact(world, end, kind)


## Projectile visible : il avance seul à la vitesse donnée ; le serveur annonce sa fin.
@rpc("any_peer", "call_local", "reliable")
func _show_projectile(id: int, origin: Vector3, dir: Vector3, speed: float, max_dist: float) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	var world := _effects_parent()
	if world == null:
		return
	var start := _muzzle(origin)
	var target := origin + dir * max_dist
	var bolt := MeshInstance3D.new()
	bolt.mesh = _projectile_mesh
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(bolt)
	bolt.global_position = start
	bolt.look_at_from_position(start, target, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	_visual_projectiles[id] = bolt
	var tween := bolt.create_tween()
	tween.tween_property(bolt, "global_position", target, start.distance_to(target) / speed)
	tween.finished.connect(_free_visual_projectile.bind(id))


@rpc("any_peer", "call_local", "reliable")
func _show_projectile_end(id: int, point: Vector3, kind: int) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	_free_visual_projectile(id)
	var world := _effects_parent()
	if world:
		_spawn_impact(world, point, kind)


func _free_visual_projectile(id: int) -> void:
	var bolt: Node3D = _visual_projectiles.get(id)
	_visual_projectiles.erase(id)
	if is_instance_valid(bolt):
		bolt.queue_free()


func _spawn_impact(world: Node3D, point: Vector3, kind: int) -> void:
	if kind == HitKind.NONE:
		return
	var impact := MeshInstance3D.new()
	impact.mesh = _impact_mesh
	impact.material_override = _impact_mat_player if kind == HitKind.TARGET else _impact_mat_world
	impact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(impact)
	impact.global_position = point
	get_tree().create_timer(0.15).timeout.connect(impact.queue_free)


func _build_effect_resources() -> void:
	_tracer_mat = StandardMaterial3D.new()
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_mat.albedo_color = Color(1.0, 0.9, 0.5)
	_projectile_mesh = BoxMesh.new()
	_projectile_mesh.size = Vector3(0.04, 0.04, PROJECTILE_VISUAL_LENGTH)
	_projectile_mesh.material = _tracer_mat
	_impact_mesh = SphereMesh.new()
	_impact_mesh.radius = 0.06
	_impact_mesh.height = 0.12
	_impact_mat_world = StandardMaterial3D.new()
	_impact_mat_world.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_impact_mat_world.albedo_color = Color(1.0, 0.85, 0.4)
	_impact_mat_player = StandardMaterial3D.new()
	_impact_mat_player.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_impact_mat_player.albedo_color = Color(1.0, 0.15, 0.1)
