extends RefCounted
## Galerie de la salle de test (visuel local, pas sur un serveur dédié) : une dalle par texture du sol
## (assets/textures/sol/, avec relief), puis une colonne par biome (data/biomes/) avec tous ses
## modèles de décor rangés par catégorie, chacun avec son nom.

const Plan := preload("res://systems/salle_test/salle_test_plan.gd")
const SOL_DIR := "res://assets/textures/sol/"
const BIOMES_DIR := "res://data/biomes/"
const DALLE := 6.0
## Catégories de BiomeData : [propriété, titre, écart entre modèles (m), profondeur de la rangée (m)].
const CATEGORIES := [
	["trees", "Arbres", 8.0, 12.0], ["big_trees", "Grands arbres (hors carte)", 9.0, 15.0],
	["rocks", "Rochers", 5.0, 7.0], ["bushes", "Buissons", 3.5, 5.0], ["grass", "Herbe", 3.0, 4.0],
	["small", "Petites plantes", 3.0, 4.0], ["water_plants", "Plantes d'eau", 3.0, 4.0],
]


static func build(salle: Node3D) -> void:
	var g := Plan.GALERIE
	var x := g.position.x + 2.0
	for file in ResourceLoader.list_directory(SOL_DIR):
		if not file.ends_with("_diff.png"):
			continue
		var nom := file.trim_suffix("_diff.png")
		_dalle(salle, nom, Vector3(x + DALLE / 2.0, 0.05, g.position.y + 2.0 + DALLE / 2.0))
		x += DALLE + 2.0
	var biomes := ResourceLoader.list_directory(BIOMES_DIR)
	var colonne := g.size.x / maxi(biomes.size(), 1)
	var i := 0
	for file in biomes:
		var biome := load(BIOMES_DIR + file) as BiomeData if file.ends_with(".tres") else null
		if biome:
			_colonne(salle, biome, g.position.x + i * colonne + 2.0, g.position.y + DALLE + 6.0)
			i += 1


## Dalle d'une texture du sol, répétée 2 fois, avec son nom.
static func _dalle(salle: Node3D, nom: String, pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(SOL_DIR + nom + "_diff.png")
	var nor := SOL_DIR + nom + "_nor_gl.png"
	if ResourceLoader.exists(nor):
		mat.normal_enabled = true
		mat.normal_texture = load(nor)
	mat.uv1_scale = Vector3(2, 2, 2)
	mat.roughness = 0.9
	var mesh := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(DALLE, DALLE)
	mesh.mesh = plan
	mesh.material_override = mat
	mesh.position = pos
	salle.add_child(mesh)
	_nom(salle, nom, pos + Vector3(-DALLE / 2.0, 1.0, -DALLE / 2.0 - 0.3), 64)


## Colonne d'un biome : titre, puis une rangée par catégorie de modèles.
static func _colonne(salle: Node3D, biome: BiomeData, x0: float, z0: float) -> void:
	_nom(salle, biome.display_name.to_upper(), Vector3(x0, 3.0, z0), 120)
	var z := z0 + 3.0
	for cat: Array in CATEGORIES:
		var modeles: Dictionary = biome.get(cat[0])
		if modeles.is_empty():
			continue
		_nom(salle, cat[1], Vector3(x0, 1.2, z), 56)
		var x := x0 + 1.5
		for chemin: String in modeles:
			_modele(salle, chemin, float(modeles[chemin]), Vector3(x, 0.0, z + cat[3] / 2.0))
			x += cat[2]
		z += cat[3] + 1.5


static func _modele(salle: Node3D, chemin: String, echelle: float, pos: Vector3) -> void:
	if not ResourceLoader.exists(chemin if chemin.begins_with("res://") else DecorModels.DIR + chemin + ".gltf"):
		_nom(salle, "manquant : " + chemin.get_file(), pos + Vector3(0, 0.5, 0), 28)
		return
	var inst := DecorModels.scene(chemin).instantiate() as Node3D
	inst.position = pos
	inst.scale = Vector3.ONE * echelle
	salle.add_child(inst)
	_nom(salle, chemin.get_file().get_basename(), pos + Vector3(-0.8, 0.6, 1.2), 40)


static func _nom(salle: Node3D, texte: String, pos: Vector3, taille: int) -> void:
	var label := Label3D.new()
	label.text = texte
	label.font_size = taille
	label.outline_size = 8
	label.pixel_size = 0.01
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position = pos
	salle.add_child(label)
