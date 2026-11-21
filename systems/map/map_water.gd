class_name MapWater
extends RefCounted
## Mares du marais : surface d'eau à MapBiomes.WATER_LEVEL, posée seulement sur les cases
## (CELL m) du marais dont le sol passe sous la surface. Pas de collision : l'eau est peu
## profonde (< 1 m), on marche au fond. Visuel seulement (absent en serveur dédié).
## calculer() est un calcul pur (thread), creer() fait le nœud.

const CELL := 4.0
const COLOR := Color(0.16, 0.3, 0.28, 0.72)


## Triangles de la surface (sommets de 3 en 3), vide s'il n'y a pas de mare.
static func calculer() -> PackedVector3Array:
	var half := Config.MAP_HALF_SIZE
	var y := MapBiomes.WATER_LEVEL
	var vertices := PackedVector3Array()
	var z := -half
	while z < half:
		var x := -half
		while x < half:
			if _cell_has_water(x, z):
				var a := Vector3(x, y, z)
				var b := Vector3(x + CELL, y, z)
				var c := Vector3(x, y, z + CELL)
				var d := Vector3(x + CELL, y, z + CELL)
				vertices.append_array([a, b, c, b, d, c])
			x += CELL
		z += CELL
	return vertices


static func creer(vertices: PackedVector3Array) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Eau"
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vertices.is_empty():
		return mesh_instance
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material()
	return mesh_instance


## Eau si un coin de la case est sous la surface, dans le marais.
static func _cell_has_water(x: float, z: float) -> bool:
	for corner: Vector2 in [Vector2(x, z), Vector2(x + CELL, z), Vector2(x, z + CELL), Vector2(x + CELL, z + CELL)]:
		if MapBiomes.is_water(corner.x, corner.y, MapTerrain.height_at(corner.x, corner.y)):
			return true
	return false


static func _material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.metallic = 0.3
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
