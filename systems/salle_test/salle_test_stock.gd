extends Node
## Serveur : entretient la salle de test. Toutes les VERIF s, chaque objet de l'armurerie absent
## (ramassé, disparu) est reposé, et chaque monstre du bestiaire mort réapparaît, figé.
## Passe par les vrais systèmes : Events.loot_drop_requested (LootManager) et
## MonsterManager.server_spawn_fige ; tout est retiré au départ (Events.carte_liberee).

const Plan := preload("res://systems/salle_test/salle_test_plan.gd")
const VERIF := 2.0
const RAYON := 1.0  ## m : un objet / monstre plus loin de sa place compte comme absent

var _objets: Array = []    ## [id, quantité, position monde]
var _monstres: Array = []  ## [chemin MonsterData, niveau, position monde]
var _attente := 0.3


func _ready() -> void:
	var origine := (get_parent() as Node3D).position
	for o: Array in Plan.armurerie():
		_objets.append([o[0], o[1], origine + (o[2] as Vector3)])
	for m: Array in Plan.bestiaire():
		_monstres.append([m[0], m[1], origine + (m[2] as Vector3)])


func _process(delta: float) -> void:
	_attente -= delta
	if _attente > 0.0:
		return
	_attente = VERIF
	var monde := get_parent().get_parent()
	var loot := monde.get_node_or_null("Loot")
	var monstres := monde.get_node_or_null("Monsters")
	var manager := monde.get_node_or_null("MonsterManager")
	if loot:
		for o: Array in _objets:
			if not _objet_present(loot, o[0], o[2]):
				Events.loot_drop_requested.emit(o[0], o[1], -1, o[2], false)
	if monstres and manager:
		for m: Array in _monstres:
			if not _monstre_present(monstres, m[0], m[2]):
				manager.server_spawn_fige(m[0], m[2], m[1])


static func _proche(a: Vector3, b: Vector3) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() < RAYON


func _objet_present(loot: Node, id: StringName, pos: Vector3) -> bool:
	for node in loot.get_children():
		var p := node as Pickup
		if p and p.item.id == id and not p.is_taken() and _proche(p.global_position, pos):
			return true
	return false


func _monstre_present(monstres: Node, chemin: String, pos: Vector3) -> bool:
	for node in monstres.get_children():
		var m := node as Monster
		if m and m.health > 0.0 and m.data.resource_path == chemin and _proche(m.global_position, pos):
			return true
	return false
