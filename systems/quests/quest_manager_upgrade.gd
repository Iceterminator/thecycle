extends RefCounted
## Montée de niveau des cristaux de QuestManager (événement des 10:00), côté serveur.


## 10:00 : chaque cristal pas encore commencé (IDLE) est remplacé par le niveau au-dessus,
## au même endroit (le spawner le recrée chez tous). Défense en cours, extraction, cristal
## épuisé : inchangés. Le niveau max reste max.
static func upgrade_idle_crystals(manager: QuestManager) -> void:
	var by_level: Dictionary = {}  # niveau -> CrystalData
	for file in ResourceLoader.list_directory(QuestManager.CRYSTALS_DIR):
		var crystal_data: CrystalData = load(QuestManager.CRYSTALS_DIR + file) as CrystalData if file.ends_with(".tres") else null
		if crystal_data:
			by_level[crystal_data.level] = crystal_data
	var upgraded := 0
	for node in manager.spawner.get_node(manager.spawner.spawn_path).get_children():
		var crystal := node as Crystal
		if crystal == null or crystal.is_queued_for_deletion() or crystal.state != Crystal.State.IDLE:
			continue
		var next: CrystalData = by_level.get(crystal.data.level + 1)
		if next == null:
			continue
		var pos := crystal.position
		crystal.queue_free()
		manager._spawn({"kind": &"crystal", "data": next.resource_path, "pos": pos})
		upgraded += 1
	if upgraded > 0:
		Events.announce_requested.emit("Les cristaux restants montent d'un niveau : plus durs, plus de points !", Color(0.3, 0.95, 0.85))
	print("[Quête] %d cristaux montés d'un niveau" % upgraded)
