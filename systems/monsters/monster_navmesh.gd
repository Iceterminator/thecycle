extends RefCounted
## Génération du navmesh des monstres (serveur), appelée par MonsterManager. Asynchrone : les
## triangles du relief sont calculés dans un thread et la cuisson est faite par le NavigationServer
## en arrière-plan ; seules l'analyse du décor et des CSG (nœuds) se font sur le fil principal.

const MapThread := preload("res://systems/map/map_thread.gd")


## Navmesh généré sur le serveur à partir du relief (MapTerrainMesh) et des COLLISIONS des CSG
## (pas de leurs maillages de rendu : un serveur dédié n'a pas de rendu).
## Coroutine : renvoie false si annulée (actif.call() faux) avant la fin.
static func bake(nav_region: NavigationRegion3D, map: Node3D, actif: Callable) -> bool:
	var started := Time.get_ticks_msec()
	var tree := nav_region.get_tree()
	var source := NavigationMeshSourceGeometryData3D.new()
	var navmesh := nav_region.navigation_mesh
	# Décor (arbres, rochers de MapDecor) : ses collisions bloquent aussi les monstres.
	# En premier : parse_source_geometry_data remet `source` à zéro.
	var decor := map.get_node_or_null("Decor")
	if decor:
		navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		NavigationServer3D.parse_source_geometry_data(navmesh, source, decor)
	if map.get_node_or_null("Terrain"):
		var relief := {}
		await MapThread.tache(tree, func() -> void: relief["faces"] = MapTerrainMesh.playable_faces())
		if not actif.call():
			return false
		source.add_faces(relief["faces"], Transform3D.IDENTITY)
	for node in map.find_children("*", "CSGShape3D"):
		var csg := node as CSGShape3D
		if not csg.is_root_shape() or not csg.use_collision:
			continue
		var shape := csg.bake_collision_shape() as ConcavePolygonShape3D
		if shape:
			source.add_faces(shape.get_faces(), csg.global_transform)
	var etat := {"fini": false}
	NavigationServer3D.bake_from_source_geometry_data_async(navmesh, source, func() -> void: etat["fini"] = true)
	while not etat["fini"]:
		await tree.process_frame
	if not actif.call():
		return false
	NavigationServer3D.region_set_navigation_mesh(nav_region.get_rid(), navmesh)
	print("[Monstres] Navmesh généré : %d polygones en %d ms" % [navmesh.get_polygon_count(), Time.get_ticks_msec() - started])
	return true
