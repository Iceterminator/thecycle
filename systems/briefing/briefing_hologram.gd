class_name BriefingHologram
extends Node3D
## Hologramme de la carte au centre de la salle de briefing : socle, relief en miniature (couleurs
## des biomes, mares), anneau qui tourne, et repères des quêtes de la partie (groupe « map_marker »,
## rafraîchis : les quêtes apparaissent juste après l'ouverture de la salle). Visuel seulement.

const BuildRoom := preload("res://systems/briefing/briefing_room_build.gd")
const SCALE := 0.014           ## 300 m -> 4,2 m
const HEIGHT_GAIN := 1.8       ## relief exagéré
const STEP := 5.0              ## pas de la grille (m de carte)
const BASE_Y := 1.15           ## hauteur du relief au-dessus du sol de la salle
const TINT := Color(0.45, 0.9, 1.0)
const WATER := Color(0.2, 0.55, 1.0)
const MARKER_KINDS := ["crystal", "contract", "evac"]
const REFRESH := 2.0

var _markers: Node3D
var _ring: MeshInstance3D
var _refresh_left: float = 0.5


func _ready() -> void:
	var pedestal := BuildRoom.material(Color(0.07, 0.08, 0.1), 0.7, 0.3)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.4
	cylinder.bottom_radius = 2.7
	cylinder.height = 0.9
	_add_mesh(cylinder, Vector3(0, 0.45, 0), pedestal)
	var halo := TorusMesh.new()
	halo.inner_radius = 2.35
	halo.outer_radius = 2.5
	_add_mesh(halo, Vector3(0, 0.92, 0), BuildRoom.material(TINT, 0.0, 0.5, TINT, 4.0))
	var terrain := MeshInstance3D.new()
	terrain.mesh = _terrain_mesh()
	terrain.material_override = _holo_material()
	terrain.position.y = BASE_Y
	add_child(terrain)
	var ring := TorusMesh.new()
	ring.inner_radius = 2.15
	ring.outer_radius = 2.2
	_ring = _add_mesh(ring, Vector3(0, BASE_Y + 0.4, 0), BuildRoom.material(TINT, 0.0, 0.5, TINT, 2.5))
	var light := OmniLight3D.new()
	light.light_color = TINT
	light.light_energy = 1.5
	light.omni_range = 6.0
	light.position.y = BASE_Y + 1.0
	add_child(light)
	_markers = Node3D.new()
	add_child(_markers)


func _process(delta: float) -> void:
	_ring.rotation.y += delta * 0.6
	_ring.position.y = BASE_Y + 0.4 + sin(Time.get_ticks_msec() / 900.0) * 0.25
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH
		_refresh_markers()


## Position d'un point de la carte dans l'hologramme (local).
func to_holo(pos: Vector3) -> Vector3:
	return Vector3(pos.x * SCALE, BASE_Y + pos.y * SCALE * HEIGHT_GAIN, pos.z * SCALE)


func _refresh_markers() -> void:
	for child in _markers.get_children():
		child.queue_free()
	for node in get_tree().get_nodes_in_group("map_marker"):
		var marker := node as Node3D
		if marker == null or not marker.is_inside_tree() or not marker.has_method("map_info"):
			continue
		var info: Dictionary = marker.map_info()
		if not str(info.get("kind", "")) in MARKER_KINDS:
			continue
		var color: Color = info.get("color", Color.WHITE)
		var top := to_holo(marker.global_position) + Vector3(0, 0.35, 0)
		var mat := BuildRoom.material(color, 0.0, 0.5, color, 3.0)
		var icon: Texture2D = info.get("icon")
		if icon:
			# Logo de la quête, toujours face au joueur.
			var sprite := Sprite3D.new()
			sprite.texture = icon
			sprite.pixel_size = 0.34 / icon.get_width()
			sprite.modulate = color
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.shaded = false
			sprite.position = top + Vector3(0, 0.1, 0)
			_markers.add_child(sprite)
		else:
			var dot := SphereMesh.new()
			dot.radius = 0.06
			dot.height = 0.12
			var pin := MeshInstance3D.new()
			pin.mesh = dot
			pin.material_override = mat
			pin.position = top
			_markers.add_child(pin)
		var stem := BoxMesh.new()
		stem.size = Vector3(0.012, 0.35, 0.012)
		var line := MeshInstance3D.new()
		line.mesh = stem
		line.material_override = mat
		line.position = top - Vector3(0, 0.175, 0)
		_markers.add_child(line)


## Relief en grille (STEP m), couleurs des biomes éclaircies et teintées, eau en bleu.
func _terrain_mesh() -> ArrayMesh:
	var half := Config.MAP_HALF_SIZE
	var n := int(half * 2.0 / STEP) + 1
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for j in n:
		for i in n:
			var x := -half + i * STEP
			var z := -half + j * STEP
			var h := MapTerrain.height_at(x, z)
			var water := MapBiomes.is_water(x, z, h)
			vertices.append(Vector3(x * SCALE, maxf(h, MapBiomes.WATER_LEVEL if water else h) * SCALE * HEIGHT_GAIN, z * SCALE))
			var base := MapBiomes.blend_color(MapBiomes.weights_at(x, z), func(b: BiomeData) -> Color: return b.map_color)
			var c := WATER * 0.7 if water else TINT * 0.35 + base * 0.9
			colors.append(Color(c.r, c.g, c.b, 0.65))
	var indices := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			indices.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _holo_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _add_mesh(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi
