class_name AbilityObject
extends StaticBody3D
## Objet posé par une capacité (étape 8c). Créé par le serveur (AbilityManager ->
## AbilitySpawner, spawn_function) et recréé à l'identique chez tous à partir des mêmes
## données ; les clients ne font que l'afficher (âge compté localement depuis l'apparition).
##
## kind (données « kind ») :
## - grenade : vole en arc (start, vel, land_time) puis devient un champ à l'atterrissage :
##   dégâts aux autres (damage_per_s) et / ou soin du propriétaire (heal_per_s), rayon radius_m ;
## - turret : tourelle (health PV, touchable) qui tire sur les ennemis à portée ;
## - barrier : mur. Mur cinétique : bloque tout (le propriétaire tire à travers) ;
##   Paravent : bloque les tirs de tous mais se traverse ;
## - strike : marqueur visible de tous, puis missiles (ou un seul impact) après delay_s ;
## - portal : entrée devant soi, sortie plus loin ; qui entre ressort de l'autre côté ;
## - ward : balise (touchable) qui révèle au propriétaire les joueurs proches sur sa carte.

const Server := preload("res://systems/abilities/ability_object_server.gd")
const Visuals := preload("res://systems/abilities/ability_object_visuals.gd")

const TICK := Server.TICK                      ## champs : dégâts / soins tous les TICK s
const MISSILE_RADIUS := Server.MISSILE_RADIUS  ## rayon d'explosion d'un missile de frappe (m)
const PORTAL_RADIUS := Server.PORTAL_RADIUS

var kind: String = ""
var ability: AbilityData
var owner_id: int = 0
var spawn_data: Dictionary = {}
var age: float = 0.0
## Synchronisé (tourelle, balise).
var health: float = 0.0:
	set(value):
		health = value
		if _bar:
			_bar.text = "%d PV" % ceili(health)

# --- Visuels (remplis par Visuals) ---
var _ball: MeshInstance3D
var _field: MeshInstance3D
var _bar: Label3D
# --- Serveur ---
var _server: Server


## Appelé par la spawn_function, sur tous les peers, avant l'entrée dans l'arbre.
func setup(data: Dictionary) -> void:
	spawn_data = data
	kind = data["kind"]
	owner_id = data["owner"]
	ability = AbilityController.get_ability(data.get("ability", ""))
	collision_layer = 0
	collision_mask = 0
	match kind:
		"beacon":
			# Balise de rappel (gadget) : chiffres dans les données, pas d'AbilityData.
			health = float(data["health"])  # WeaponData.beacon_health (Weapon)
			Visuals.add_box_shape(self, Vector3(0.6, 1.0, 0.6), 1)
			Visuals.build_sync(self)
		"turret", "ward":
			health = ability.health if ability.health > 0.0 else Config.combat.ward_health
			Visuals.add_box_shape(self, Vector3(1.2, 1.6, 1.2) if kind == "turret" else Vector3(0.5, 1.4, 0.5), 1)
			Visuals.build_sync(self)
		"barrier":
			var w := ability.width_m
			var h := ability.height_m
			# Paravent : couche à part, que les corps ne touchent pas mais que les tirs touchent.
			Visuals.add_box_shape(self, Vector3(w, h, 0.3), Config.SHOT_ONLY_LAYER if ability.id == &"safeguard" else 1)
	Visuals.build(self)


func _ready() -> void:
	if kind == "turret" or kind == "ward" or kind == "beacon":
		add_to_group("damageable")
	if kind == "beacon":
		add_to_group("recall_beacon")  # retrouvée par l'arme (gadget) de son propriétaire
	if kind == "barrier" and ability.id == &"kinetic_barrier":
		add_to_group("owner_shots_pass")  # le propriétaire tire à travers (voir Weapon)
	set_physics_process(multiplayer.is_server())
	if multiplayer.is_server():
		_server = Server.new(self)
		if kind == "strike":
			_server.plan_missiles()


func life() -> float:
	match kind:
		"grenade":
			return float(spawn_data["land_time"]) + maxf(ability.duration_s, 0.1)
		"turret", "barrier", "portal":
			return maxf(ability.duration_s, 1.0)
		"strike":
			return maxf(ability.delay_s, 0.0) + maxf(ability.duration_s, 0.0) + 1.0
		"ward", "beacon":
			return Config.combat.ward_lifetime
		"frag":
			return float(spawn_data["fuse"]) + 0.2
	return 5.0


# =========================================================================
# Interface « damageable » (tourelle, balise)
# =========================================================================

func can_be_hit() -> bool:
	return health > 0.0


func is_headshot(_point: Vector3) -> bool:
	return false


func server_receive_hit(amount: float, attacker_id: int) -> bool:
	if health <= 0.0 or attacker_id == owner_id:
		return false
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		queue_free()
		return true
	return false


# =========================================================================
# Serveur
# =========================================================================

func _physics_process(delta: float) -> void:
	age += delta
	if age >= life():
		queue_free()
		return
	_server.update(delta)


func _land_pos() -> Vector3:
	return spawn_data.get("land_pos", global_position)


# =========================================================================
# Tous les peers : visuels
# =========================================================================

func _process(delta: float) -> void:
	if multiplayer.is_server():
		pass  # l'âge est compté par _physics_process
	else:
		age += delta
	if (kind == "grenade" or kind == "frag") and _ball:
		_ball.global_position = _arc_pos(age) + (Vector3.UP * 0.15 if age >= float(spawn_data["land_time"]) else Vector3.ZERO)
		if _field and age >= float(spawn_data["land_time"]):
			_field.visible = true


## Position sur l'arc du lancer au temps `t`, puis posée au point d'atterrissage.
func _arc_pos(t: float) -> Vector3:
	if t >= float(spawn_data["land_time"]):
		return _land_pos()
	var start: Vector3 = spawn_data["start"]
	var vel: Vector3 = spawn_data["vel"]
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	return start + vel * t + Vector3.DOWN * 0.5 * g * t * t



## Position de l'objet telle que donnée à l'apparition (avant l'entrée dans l'arbre).
func global_position_from_data() -> Vector3:
	return spawn_data.get("pos", spawn_data.get("start", Vector3.ZERO))


@rpc("authority", "call_local", "unreliable")
func _show_tracer(from: Vector3, to: Vector3) -> void:
	if Net.is_dedicated_server:
		return
	var bar := BoxMesh.new()
	bar.size = Vector3(0.05, 0.05, from.distance_to(to))
	var mi := MeshInstance3D.new()
	mi.mesh = bar
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Visuals.color_of(ability)
	mi.material_override = mat
	get_parent().get_parent().add_child(mi)  # dans le monde, pas dans le conteneur du spawner
	mi.global_position = (from + to) / 2.0
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	get_tree().create_timer(0.06).timeout.connect(mi.queue_free)


@rpc("authority", "call_local", "unreliable")
func _show_boom(point: Vector3, radius: float) -> void:
	if Net.is_dedicated_server:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.55, 0.15, 0.7)
	var ball := MeshInstance3D.new()
	ball.mesh = Visuals.sphere(1.0)
	ball.material_override = mat
	get_parent().get_parent().add_child(ball)
	ball.global_position = point
	ball.scale = Vector3.ONE * 0.2
	Events.camera_shake_requested.emit(point, 0.9, radius * 4.0)
	var tween := ball.create_tween().set_parallel()
	tween.tween_property(ball, "scale", Vector3.ONE * radius, 0.25)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(ball.queue_free)


## Balise : positions des joueurs repérés, pour la carte du propriétaire seulement.
@rpc("authority", "call_local", "reliable")
func _scan_ping(positions: Array) -> void:
	if multiplayer.get_unique_id() != owner_id:
		return
	Events.scan_revealed.emit(positions)
