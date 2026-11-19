class_name QuestDelayed
extends Node
## Quêtes tirées au départ mais qui apparaissent plus tard (serveur seulement) :
## - spawn_delay > 0 : à ce temps de partie (Cœur stellaire) ;
## - with_storm : au début de la Grande Marée (collecteur d'éclats d'orage), avec les éclats.
## Une réinitialisation de partie annule les apparitions en attente (clear).

const ANNOUNCE_COLOR := Color(0.8, 0.55, 1.0)

var world: World
var spawn_callable: Callable  ## reçoit {kind, data, pos} et crée la quête

var _pending: Array[Dictionary] = []


func _ready() -> void:
	Events.storm_started.connect(_on_storm_started)


func clear() -> void:
	_pending.clear()


## Garde la quête en attente si elle est différée ; renvoie faux si elle doit apparaître tout de suite.
func queue_if_delayed(quest: Dictionary) -> bool:
	if quest.get("spawn_delay", 0.0) <= 0.0 and not quest.get("with_storm", false):
		return false
	_pending.append(quest)
	return true


func _physics_process(_delta: float) -> void:
	if _pending.is_empty() or world == null or world.match_manager == null:
		return
	for quest in _pending.duplicate():
		if not quest["with_storm"] and world.match_manager.elapsed >= quest["spawn_delay"]:
			_pending.erase(quest)
			_release(quest)
			Events.announce_requested.emit("%s est apparu sur la carte !" % quest["name"], ANNOUNCE_COLOR)


func _release(quest: Dictionary) -> void:
	spawn_callable.call({"kind": quest["kind"], "data": quest["data"], "pos": quest["pos"]})
	print("[Quête] %s apparaît en %s" % [quest["name"], quest["pos"]])


## Début de la Grande Marée : collecteurs d'éclats tirés + éclats d'orage au hasard sur la carte.
func _on_storm_started(shard_count: int) -> void:
	var item: ItemData = null
	for quest in _pending.duplicate():
		if quest["with_storm"]:
			_pending.erase(quest)
			_release(quest)
			item = (load(quest["data"]) as ContractData).resource_item
	if item == null:
		return
	var half := Config.MAP_HALF_SIZE - 10.0
	for i in shard_count:
		var pos := Vector3(randf_range(-half, half), 0.0, randf_range(-half, half))
		pos.y = MapTerrain.height_at(pos.x, pos.z)
		Events.loot_drop_requested.emit(item.id, 1, -1, pos, false)
	Events.announce_requested.emit("%d × %s tombés sur la carte ! Déposez-les au collecteur d'éclats d'orage" % [shard_count, item.display_name], ANNOUNCE_COLOR)
