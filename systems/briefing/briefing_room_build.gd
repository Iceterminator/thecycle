extends RefCounted
## Construction de la salle de briefing (BriefingRoom) : coque, baie vitrée côté carte, bandes
## lumineuses, plafonniers, lumières. Boîtes simples avec collision (le joueur s'y déplace).
## Coordonnées locales : sol à y = 0, baie vitrée vers +z (la carte).

const HULL := Color(0.16, 0.18, 0.22)
const FLOOR := Color(0.1, 0.11, 0.14)
const TRIM := Color(0.08, 0.09, 0.11)
const GLOW := Color(0.35, 0.85, 1.0)
const PANEL_LIGHT := Color(0.85, 0.92, 1.0)


static func build(room: Node3D, size: Vector3) -> void:
	var w := size.x
	var d := size.z
	var h := size.y
	var hull := material(HULL, 0.6, 0.45)
	var trim := material(TRIM, 0.7, 0.35)
	box(room, Vector3(w + 1.0, 0.5, d + 1.0), Vector3(0, -0.25, 0), material(FLOOR, 0.5, 0.3))
	box(room, Vector3(w + 1.0, 0.4, d + 1.0), Vector3(0, h + 0.2, 0), hull)
	box(room, Vector3(w + 1.0, h, 0.4), Vector3(0, h / 2.0, -d / 2.0 - 0.2), hull)
	for side in [-1.0, 1.0]:
		box(room, Vector3(0.4, h, d + 1.0), Vector3(side * (w / 2.0 + 0.2), h / 2.0, 0), hull)
	# Baie vitrée (vers la carte) : allège, linteau, vitre (avec collision), montants.
	box(room, Vector3(w + 1.0, 1.0, 0.4), Vector3(0, 0.5, d / 2.0 + 0.2), hull)
	box(room, Vector3(w + 1.0, 1.0, 0.4), Vector3(0, h - 0.5, d / 2.0 + 0.2), hull)
	box(room, Vector3(w, h - 2.0, 0.08), Vector3(0, h / 2.0, d / 2.0 + 0.2), glass())
	for x in [-w / 4.0, 0.0, w / 4.0]:
		box(room, Vector3(0.3, h - 2.0, 0.5), Vector3(x, h / 2.0, d / 2.0 + 0.2), trim)
	# Bandes lumineuses au pied des murs et plafonniers (sans collision).
	var glow := material(GLOW, 0.0, 0.5, GLOW, 3.0)
	box(room, Vector3(w, 0.08, 0.08), Vector3(0, 0.15, -d / 2.0 + 0.05), glow, false)
	for side in [-1.0, 1.0]:
		box(room, Vector3(0.08, 0.08, d), Vector3(side * (w / 2.0 - 0.05), 0.15, 0), glow, false)
		box(room, Vector3(0.08, 0.08, d), Vector3(side * (w / 2.0 - 0.05), h - 1.1, 0), glow, false)
	var panel := material(PANEL_LIGHT, 0.0, 0.5, PANEL_LIGHT, 2.0)
	for x in [-w / 3.0, 0.0, w / 3.0]:
		box(room, Vector3(5.0, 0.05, 2.5), Vector3(x, h - 0.03, -d / 6.0), panel, false)
	# Réacteurs sous la coque (vus depuis la carte).
	var engine := material(Color(1.0, 0.55, 0.25), 0.0, 0.5, Color(1.0, 0.5, 0.2), 4.0)
	for x in [-w / 3.0, w / 3.0]:
		box(room, Vector3(3.0, 0.6, 3.0), Vector3(x, -0.8, 0), engine, false)
	if DisplayServer.get_name() == "headless":
		return
	for x in [-w / 3.0, 0.0, w / 3.0]:
		var light := OmniLight3D.new()
		light.light_color = PANEL_LIGHT
		light.light_energy = 1.1
		light.omni_range = 14.0
		light.position = Vector3(x, h - 1.0, -d / 6.0)
		room.add_child(light)


## Boîte visible ; avec une collision (couche monde) si `collide`.
static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, collide: bool = true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		parent.add_child(body)
	return mi


static func material(color: Color, metallic: float, roughness: float, emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	return mat


static func glass() -> StandardMaterial3D:
	var mat := material(Color(0.6, 0.8, 1.0, 0.1), 0.3, 0.05)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
