class_name QuestDelayed
extends Node
## Quêtes tirées au départ mais qui apparaissent plus tard (serveur seulement) :
## spawn_delay > 0 : à ce temps de partie (aucune quête n'en a pour l'instant).
## Une réinitialisation de partie annule les apparitions en attente (clear).

const ANNOUNCE_COLOR := Color(0.8, 0.55, 1.0)

var world: World
var spawn_callable: Callable  ## reçoit {kind, data, pos} et crée la quête

var _pending: Array[Dictionary] = []


func clear() -> void:
	_pending.clear()


## Garde la quête en attente si elle est différée ; renvoie faux si elle doit apparaître tout de suite.
func queue_if_delayed(quest: Dictionary) -> bool:
	if quest.get("spawn_delay", 0.0) <= 0.0:
		return false
	_pending.append(quest)
	return true


func _physics_process(_delta: float) -> void:
	if _pending.is_empty() or world == null or world.match_manager == null:
		return
	for quest in _pending.duplicate():
		if world.match_manager.elapsed >= quest["spawn_delay"]:
			_pending.erase(quest)
			spawn_callable.call({"kind": quest["kind"], "data": quest["data"], "pos": quest["pos"]})
			print("[Quête] %s apparaît en %s" % [quest["name"], quest["pos"]])
			Events.announce_requested.emit("%s est apparu sur la carte !" % quest["name"], ANNOUNCE_COLOR)
