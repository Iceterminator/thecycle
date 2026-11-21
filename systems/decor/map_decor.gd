class_name MapDecor
extends RefCounted
## Décor de la carte : arbres, rochers, buissons et herbe (modèles : DecorModels), semés au hasard
## avec une graine fixe, posés sur le relief (MapTerrain.height_at). Chaque peer construit le même
## décor de son côté : rien ne passe par le réseau.
## Construction asynchrone (NiveauxCarte) : le plan (MapDecorPlan : où poser quoi) est calculé dans
## un thread, puis les nœuds sont créés par tranches (Config.MAP_BUILD_BUDGET_MS par image).
## Arbres et rochers ont une collision ; MonsterNavmesh en tient compte. L'herbe et les petites
## plantes n'en ont pas (MultiMesh). Les nœuds sont posés sous `parent` (Map/Decor).

const MapThread := preload("res://systems/map/map_thread.gd")
const MapDecorPlan := preload("res://systems/decor/map_decor_plan.gd")


## Coroutine : renvoie false si la construction a été annulée (actif.call() faux).
func construire(parent: Node3D, world: Node, actif: Callable) -> bool:
	var tree := parent.get_tree()
	var planificateur := MapDecorPlan.new()
	planificateur.lire_reperes(world)
	await MapThread.tache(tree, planificateur.calculer)
	if not actif.call():
		return false
	DecorModels.precharger(_modeles(planificateur.plan))
	await DecorModels.attendre_precharges(tree)
	var debut := Time.get_ticks_usec()
	for entree: Dictionary in planificateur.plan:
		if not actif.call() or not is_instance_valid(parent):
			return false
		if entree["t"] == &"multi":
			var par_modele: Dictionary = entree["par_modele"]
			for modele: String in par_modele:
				DecorModels.add_multimeshes(parent, modele, par_modele[modele], entree["portee"])
				debut = await MapThread.ceder(tree, debut)
		else:
			_poser(parent, entree)
			debut = await MapThread.ceder(tree, debut)
	return actif.call()


func _poser(parent: Node3D, entree: Dictionary) -> void:
	var inst := DecorModels.scene(entree["m"]).instantiate() as Node3D
	inst.position = entree["p"]
	inst.rotation.y = entree["r"]
	inst.scale = Vector3.ONE * float(entree["s"])
	parent.add_child(inst)
	if entree["t"] == &"solide":
		DecorModels.add_collision(inst, entree["arbre"])
		DecorModels.set_range_end(inst, entree["portee"])
	else:
		DecorModels.no_shadow(inst)  # forêt hors carte : loin des ombres, coûteuse avec le feuillage


## Modèles utilisés par le plan (sans doublon).
func _modeles(plan: Array) -> Array:
	var liste: Array = []
	for entree: Dictionary in plan:
		var noms: Array = entree["par_modele"].keys() if entree["t"] == &"multi" else [entree["m"]]
		for nom: String in noms:
			if not liste.has(nom):
				liste.append(nom)
	return liste
