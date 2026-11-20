class_name MapTerrainMesh
extends RefCounted
## Maillages du relief (MapTerrain) : rendu (grille de 2 m dans la carte, 6 m au-delà des
## murs, couleurs de sommet selon pente et altitude) et triangles de la zone jouable pour le
## navmesh. Les triangles sont dans le sens horaire vu de dessus (face avant vers le haut).

const INNER_STEP := 2.0
const OUTER_STEP := 6.0
const OUTSIDE_EXTENT := 60.0     ## le terrain se prolonge au-delà des murs (horizon)
const MUD := Color("#3a3424")  ## fond des mares du marais


static func make_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	return mat


## Coordonnées d'un axe : grossier dehors, fin dans la carte.
static func _axis() -> PackedFloat32Array:
	var half := Config.MAP_HALF_SIZE
	var axis := PackedFloat32Array()
	var v := -half - OUTSIDE_EXTENT
	while v < -half - 0.01:
		axis.append(v)
		v += OUTER_STEP
	v = -half
	while v < half + 0.01:
		axis.append(v)
		v += INNER_STEP
	v = half + OUTER_STEP
	while v < half + OUTSIDE_EXTENT + 0.01:
		axis.append(v)
		v += OUTER_STEP
	return axis


static func build_visual() -> ArrayMesh:
	var axis := _axis()
	var n := axis.size()
	var patches := FastNoiseLite.new()
	patches.seed = MapTerrain.SEED + 2
	patches.frequency = 0.02
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for j in n:
		for i in n:
			var x := axis[i]
			var z := axis[j]
			var h := MapTerrain.height_at(x, z)
			var normal := MapTerrain.normal_at(x, z)
			vertices.append(Vector3(x, h, z))
			normals.append(normal)
			colors.append(_color(x, z, h, normal, patches.get_noise_2d(x, z)))
	var indices := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			indices.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Couleurs du biome (mélangées aux frontières), puis terre / roche / sommet / vase sous l'eau.
static func _color(x: float, z: float, h: float, normal: Vector3, patch: float) -> Color:
	var w := MapBiomes.weights_at(x, z)
	var grass := MapBiomes.blend_color(w, func(b: BiomeData) -> Color: return b.grass_color)
	var dirt := MapBiomes.blend_color(w, func(b: BiomeData) -> Color: return b.dirt_color)
	var c := grass.lerp(dirt, smoothstep(-0.1, 0.5, patch))
	c = c.lerp(MapBiomes.blend_color(w, func(b: BiomeData) -> Color: return b.rock_color), smoothstep(0.82, 0.68, normal.y))
	c = c.lerp(MapBiomes.blend_color(w, func(b: BiomeData) -> Color: return b.peak_color), smoothstep(12.0, 19.0, h) * 0.6)
	return c.lerp(MUD, smoothstep(MapBiomes.WATER_LEVEL + 0.4, MapBiomes.WATER_LEVEL - 0.2, h) * w[MapBiomes.MARAIS])


## Triangles de la zone jouable (pas de 2 m), pour le navmesh du serveur.
static func playable_faces() -> PackedVector3Array:
	var half := int(Config.MAP_HALF_SIZE)
	var step := int(INNER_STEP)
	var faces := PackedVector3Array()
	for z in range(-half, half, step):
		for x in range(-half, half, step):
			var a := Vector3(x, MapTerrain.height_at(x, z), z)
			var b := Vector3(x + step, MapTerrain.height_at(x + step, z), z)
			var c := Vector3(x, MapTerrain.height_at(x, z + step), z + step)
			var d := Vector3(x + step, MapTerrain.height_at(x + step, z + step), z + step)
			faces.append_array([a, b, c, b, d, c])
	return faces
