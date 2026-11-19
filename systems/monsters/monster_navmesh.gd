extends RefCounted
## Génération du navmesh des monstres (serveur), appelée par MonsterManager.


## Navmesh généré sur le serveur à partir du relief (MapTerrainMesh) et des COLLISIONS des CSG
## (pas de leurs maillages de rendu : un serveur dédié n'a pas de rendu).
static func bake(nav_region: NavigationRegion3D, map: Node3D) -> void:
	var started := Time.get_ticks_msec()
	var source := NavigationMeshSourceGeometryData3D.new()
	var navmesh := nav_region.navigation_mesh
	# Décor (arbres, rochers de MapDecor) : ses collisions bloquent aussi les monstres.
	# En premier : parse_source_geometry_data remet `source` à zéro.
	var decor := map.get_node_or_null("Decor")
	if decor:
		navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		NavigationServer3D.parse_source_geometry_data(navmesh, source, decor)
	if map.get_node_or_null("Terrain"):
		source.add_faces(MapTerrainMesh.playable_faces(), Transform3D.IDENTITY)
	for node in map.find_children("*", "CSGShape3D"):
		var csg := node as CSGShape3D
		if not csg.is_root_shape() or not csg.use_collision:
			continue
		var shape := csg.bake_collision_shape() as ConcavePolygonShape3D
		if shape:
			source.add_faces(shape.get_faces(), csg.global_transform)
	NavigationServer3D.bake_from_source_geometry_data(navmesh, source)
	NavigationServer3D.region_set_navigation_mesh(nav_region.get_rid(), navmesh)
	print("[Monstres] Navmesh généré : %d polygones en %d ms" % [navmesh.get_polygon_count(), Time.get_ticks_msec() - started])
