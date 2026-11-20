class_name MapTerrain
extends StaticBody3D
## Relief de la carte : collines et crêtes, calculés par une fonction déterministe
## (bruit à graine fixe) : tous les peers obtiennent exactement la même hauteur, rien ne
## passe par le réseau. Nœud « Map/Terrain » de world.tscn.
## - height_at(x, z) : hauteur du sol (0.0 tant qu'aucun terrain n'est en place, ex. world_test).
## - Zones plates autour de chaque Marker3D du monde et de l'évac (centre, hauteur 0).
## - _enter_tree : enregistre les zones plates puis pose les Marker3D au sol, AVANT que
##   MapDecor, MonsterManager, QuestManager… ne lisent leurs positions.
## - Collision : HeightMapShape3D à 1 m, construite par construire() (Niveaux), pas au chargement. Rendu : MapTerrainMesh (absent en serveur dédié).
## - Biomes (MapBiomes) : le relief de base est adapté à chaque biome ; mares du marais (MapWater).

const SEED := 20261119
const COLLISION_MARGIN := 6      ## la collision déborde de la carte (m)
const RISE_START := 25.0         ## les bords remontent à partir de cette distance du mur (m)
const RISE_INSIDE := 4.0         ## hauteur gagnée jusqu'au mur
const RISE_OUTSIDE := 0.12       ## pente des collines au-delà des murs
const EVAC_FLAT := 22.0
const EVAC_BLEND := 10.0
const POINT_FLAT := 10.0
const POINT_BLEND := 14.0
const SMALL_FLAT := 4.0          ## petits repères (LumicepSpots) : zone plate réduite
const SMALL_BLEND := 6.0
const SMALL_GROUPS: Array[String] = ["LumicepSpots"]
const MIN_HEIGHT := -5.0

static var _configured: bool = false
static var _hills: FastNoiseLite
static var _ridges: FastNoiseLite
static var _flat_zones: Array[Vector4] = []   ## x, z, rayon plein, largeur du fondu
static var _flat_heights: PackedFloat32Array = PackedFloat32Array()
## Hauteurs déjà calculées (grille de 1 m, remplie par construire()) : height_at y lit au lieu de
## recalculer le bruit (monstres loin des joueurs, loot, décor : appelé des milliers de fois).
static var _grille: PackedFloat32Array = PackedFloat32Array()
static var _grille_n: int = 0
static var _grille_half: int = 0


## Hauteur du sol en (x, z).
static func height_at(x: float, z: float) -> float:
	if not _configured:
		return 0.0
	if _grille_n > 0:
		var gx := x + _grille_half
		var gz := z + _grille_half
		if gx >= 0.0 and gz >= 0.0 and gx < _grille_n - 1 and gz < _grille_n - 1:
			var i := int(gx)
			var j := int(gz)
			var fx := gx - i
			var fz := gz - j
			var k := j * _grille_n + i
			return lerpf(lerpf(_grille[k], _grille[k + 1], fx), lerpf(_grille[k + _grille_n], _grille[k + _grille_n + 1], fx), fz)
	return _exact_height(x, z)


static func _exact_height(x: float, z: float) -> float:
	var h := _raw_height(x, z)
	for i in _flat_zones.size():
		var zone := _flat_zones[i]
		var d := Vector2(x - zone.x, z - zone.y).length()
		if d < zone.z + zone.w:
			h = lerpf(h, _flat_heights[i], 1.0 - smoothstep(zone.z, zone.z + zone.w, d))
	return h


## Gradient du sol (tan de l'angle de pente : 0.7 environ = 35°).
static func slope_at(x: float, z: float) -> float:
	var dx := height_at(x + 1.0, z) - height_at(x - 1.0, z)
	var dz := height_at(x, z + 1.0) - height_at(x, z - 1.0)
	return Vector2(dx, dz).length() / 2.0


static func normal_at(x: float, z: float) -> Vector3:
	var dx := height_at(x + 1.0, z) - height_at(x - 1.0, z)
	var dz := height_at(x, z + 1.0) - height_at(x, z - 1.0)
	return Vector3(-dx, 2.0, -dz).normalized()


static func _raw_height(x: float, z: float) -> float:
	var ridge := 1.0 - absf(_ridges.get_noise_2d(x, z))
	var h := MapBiomes.shape_height(x, z, _hills.get_noise_2d(x, z) * 5.0 + ridge * ridge * 16.0 - 6.0)
	var d := maxf(absf(x), absf(z)) - (Config.MAP_HALF_SIZE - RISE_START)
	if d > 0.0:
		h += RISE_INSIDE * pow(minf(d, RISE_START) / RISE_START, 2.0) + RISE_OUTSIDE * maxf(d - RISE_START, 0.0)
	var floor_start := MIN_HEIGHT + 2.0
	return h if h > floor_start else floor_start + (h - floor_start) * 0.3


static func _add_flat_zone(x: float, z: float, full: float, blend: float, target: float) -> void:
	_flat_zones.append(Vector4(x, z, full, blend))
	_flat_heights.append(target)


func _enter_tree() -> void:
	_hills = FastNoiseLite.new()
	_hills.seed = SEED
	_hills.frequency = 0.009
	_hills.fractal_octaves = 3
	_ridges = FastNoiseLite.new()
	_ridges.seed = SEED + 1
	_ridges.frequency = 0.004
	_ridges.fractal_octaves = 2
	_flat_zones.clear()
	_flat_heights.clear()
	_configured = true
	var markers := get_parent().get_parent().find_children("*", "Marker3D", true, false)
	for node in markers:
		var m := node as Marker3D
		var small := SMALL_GROUPS.has(String(m.get_parent().name)) or String(m.name).begins_with("Lumicepe")
		_add_flat_zone(m.position.x, m.position.z, SMALL_FLAT if small else POINT_FLAT,
				SMALL_BLEND if small else POINT_BLEND, _raw_height(m.position.x, m.position.z))
	_add_flat_zone(0.0, 0.0, EVAC_FLAT, EVAC_BLEND, 0.0)  # en dernier : l'évac reste à 0 exactement
	for node in markers:
		var m := node as Marker3D
		m.position.y += height_at(m.position.x, m.position.z)


## Construit la collision et le rendu (Niveaux, au début d'une partie). Le relief (height_at) est
## disponible dès _enter_tree, même sans carte construite.
func construire() -> void:
	collision_layer = 1
	collision_mask = 0
	var half := int(Config.MAP_HALF_SIZE) + COLLISION_MARGIN
	var count := half * 2 + 1
	var data := PackedFloat32Array()
	data.resize(count * count)
	for j in count:
		for i in count:
			data[j * count + i] = _exact_height(i - half, j - half)
	_grille = data
	_grille_n = count
	_grille_half = half
	var shape := HeightMapShape3D.new()
	shape.map_width = count
	shape.map_depth = count
	shape.map_data = data
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	if DisplayServer.get_name() != "headless":
		var visual := MeshInstance3D.new()
		visual.mesh = MapTerrainMesh.build_visual()
		visual.material_override = MapTerrainMesh.make_material()
		add_child(visual)
		add_child(MapWater.build())


## Supprime la collision et le rendu (retour au lobby, salle de test).
func detruire() -> void:
	for child in get_children():
		child.queue_free()
