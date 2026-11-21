extends RefCounted
## Nœuds du monde que Niveaux ajoute ou retire selon l'activité : salle de briefing, salle de test,
## contenu de la carte (relief, décor, ambiance). Les nœuds retirés sont renommés avant queue_free
## (le nom est libre tout de suite si la salle est recréée dans la même image).


static func maj_briefing(world: Node, present: bool) -> void:
	var salle := world.get_node_or_null("BriefingRoom")
	if present and salle == null:
		salle = BriefingRoom.new()
		salle.name = "BriefingRoom"
		world.add_child(salle)
	elif not present and salle:
		salle.name = "BriefingRoom_supprimee"
		salle.queue_free()


static func maj_salle_test(world: Node, present: bool) -> void:
	var salle := world.get_node_or_null("SalleTest")
	if present and salle == null:
		salle = SalleTest.new()
		salle.name = "SalleTest"
		world.add_child(salle)
	elif not present and salle:
		salle.name = "SalleTest_supprimee"
		salle.queue_free()


## Retire collision, rendu, décor et ambiance de la carte.
static func liberer_carte(world: Node) -> void:
	var map := world.get_node_or_null("Map")
	if map == null:
		return
	var terrain := map.get_node_or_null("Terrain") as MapTerrain
	if terrain:
		terrain.detruire()
	var decor := map.get_node_or_null("Decor")
	if decor:
		decor.name = "Decor_supprime"
		decor.queue_free()
	var ambiance := map.get_node_or_null("Ambiance")
	if ambiance:
		ambiance.name = "Ambiance_supprimee"
		ambiance.queue_free()
