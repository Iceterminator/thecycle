extends RefCounted
## Aides à la construction asynchrone de la carte : calculs purs dans le WorkerThreadPool (on
## attend leur fin image par image, sans bloquer) et budget de temps par image pour créer les nœuds.
## Les fonctions « await » sont des coroutines : les appeler avec `await`.


## Lance `calcul` (sans argument) dans un thread et attend sa fin sans bloquer.
static func tache(tree: SceneTree, calcul: Callable) -> void:
	var id := WorkerThreadPool.add_task(calcul)
	while not WorkerThreadPool.is_task_completed(id):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(id)


## Lance `calcul(index)` pour index de 0 à nombre - 1, répartis sur les threads, et attend la fin.
static func groupe(tree: SceneTree, calcul: Callable, nombre: int) -> void:
	var id := WorkerThreadPool.add_group_task(calcul, nombre)
	while not WorkerThreadPool.is_group_task_completed(id):
		await tree.process_frame
	WorkerThreadPool.wait_for_group_task_completion(id)


## Si le budget de l'image (Config.MAP_BUILD_BUDGET_MS) est écoulé depuis `debut_usec`, passe à
## l'image suivante. Renvoie le nouveau début de tranche : `debut = await MapThread.ceder(tree, debut)`.
static func ceder(tree: SceneTree, debut_usec: int) -> int:
	if Time.get_ticks_usec() - debut_usec < Config.MAP_BUILD_BUDGET_MS * 1000:
		return debut_usec
	await tree.process_frame
	return Time.get_ticks_usec()
