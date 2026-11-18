class_name AbilityManager
extends Node
## Crée les objets des capacités (étape 8c) via son AbilitySpawner (règle 3 : seul le
## serveur crée). Créé en code par World sur tous les peers, avec le conteneur
## « AbilityObjects » et le spawner « AbilitySpawner » (mêmes noms partout).
## - Tous les peers : spawn_function (recrée l'AbilityObject à partir des mêmes données).
## - Serveur : Events.ability_object_requested -> calcule ce qui manque (trajectoire de la
##   grenade), limite le nombre de balises par joueur, crée l'objet ; vide tout à chaque
##   nouvelle partie.

const OBJECT_SCRIPT := preload("res://systems/abilities/ability_object.gd")
const GRENADE_STEP := 0.02         ## pas de simulation de la trajectoire (s)
const GRENADE_MAX_TIME := 4.0

var container: Node3D
var spawner: MultiplayerSpawner
var _next_uid: int = 0
var _wards: Dictionary = {}        # serveur : propriétaire -> [objets balise]


func _ready() -> void:
	var world := get_parent()
	container = Node3D.new()
	container.name = "AbilityObjects"
	world.add_child.call_deferred(container)
	spawner = MultiplayerSpawner.new()
	spawner.name = "AbilitySpawner"
	spawner.spawn_path = NodePath("../AbilityObjects")
	spawner.spawn_function = _spawn_node
	world.add_child.call_deferred(spawner)
	if multiplayer.is_server():
		Events.ability_object_requested.connect(_on_requested)
		Events.match_reset_requested.connect(_on_match_reset)


func _spawn_node(data: Dictionary) -> Node:
	var obj: AbilityObject = OBJECT_SCRIPT.new()
	obj.name = "Ability_%d" % data["uid"]
	obj.setup(data)
	obj.position = data.get("pos", data.get("start", Vector3.ZERO))
	if data.has("dir"):
		var d: Vector3 = data["dir"]
		obj.rotation.y = atan2(-d.x, -d.z)
	return obj


func _on_requested(data: Dictionary) -> void:
	if spawner == null or not spawner.is_inside_tree():
		return
	var ability := AbilityController.get_ability(data.get("ability", ""))
	# Gadgets (grenade à fragmentation, balise de rappel) : chiffres dans les données.
	if ability == null and not data["kind"] in ["frag", "beacon"]:
		return
	if data["kind"] == "grenade" or data["kind"] == "frag":
		_plan_throw(data)
		data.erase("dir")  # l'objet ne doit pas tourner
	_next_uid += 1
	data["uid"] = _next_uid
	var obj := spawner.spawn(data) as AbilityObject
	if data["kind"] == "ward" and obj and ability:
		_limit_wards(int(data["owner"]), obj, maxi(ability.max_active, 1))


## Grenade / sphère lancée : départ devant les yeux, arc jusqu'au premier obstacle.
func _plan_throw(data: Dictionary) -> void:
	var origin: Vector3 = data["origin"]
	var dir: Vector3 = data["dir"]
	var start := origin + dir * 0.6
	var vel := dir * Config.combat.grenade_throw_speed + Vector3.UP * 2.0
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var space := container.get_world_3d().direct_space_state
	var t := 0.0
	var pos := start
	var land := start
	while t < GRENADE_MAX_TIME:
		var next := start + vel * (t + GRENADE_STEP) + Vector3.DOWN * 0.5 * g * pow(t + GRENADE_STEP, 2)
		var query := PhysicsRayQueryParameters3D.create(pos, next, 1)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			land = hit["position"]
			break
		pos = next
		land = next
		t += GRENADE_STEP
	data["start"] = start
	data["vel"] = vel
	data["land_time"] = t
	data["land_pos"] = land
	data.erase("origin")


## Une balise de trop : la plus ancienne disparaît.
func _limit_wards(owner: int, obj: AbilityObject, max_active: int) -> void:
	var list: Array = _wards.get(owner, [])
	list = list.filter(func(o: Variant) -> bool: return is_instance_valid(o))
	list.append(obj)
	while list.size() > max_active:
		var oldest: Node = list.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	_wards[owner] = list


func _on_match_reset() -> void:
	_wards.clear()
	if container:
		for child in container.get_children():
			child.queue_free()
