class_name MapBiomes
extends RefCounted
## Répartition des 4 biomes de la carte, calculée de façon déterministe (bruit à graine fixe) :
## chaque peer obtient la même chose, rien ne passe par le réseau.
## 4 secteurs autour du centre (Prairies au sud, Dunes à l'est, Cimes au nord, Marais à l'ouest),
## frontières tordues par du bruit et fondues sur une bande ; le centre (évac) reste Prairies.
## - weights_at(x, z) : poids de chaque biome (somme 1) ; biome_at : le biome dominant.
## - shape_height : relief adapté au biome (MapTerrain) ; WATER_LEVEL : surface des mares.

const PLAINE := 0
const DESERT := 1
const NEIGE := 2
const MARAIS := 3
const DATA: Array[BiomeData] = [
	preload("res://data/biomes/plaine.tres"),
	preload("res://data/biomes/desert.tres"),
	preload("res://data/biomes/neige.tres"),
	preload("res://data/biomes/marais.tres"),
]
## Direction du centre de chaque secteur (angle de atan2(z, x)) : +z = sud sur la carte.
const SECTOR_ANGLES: Array[float] = [PI / 2.0, 0.0, -PI / 2.0, PI]
const BLEND := 0.2            ## demi-largeur angulaire du fondu entre secteurs (rad)
const WARP := 0.55            ## torsion des frontières (rad)
const CENTER_FULL := 32.0     ## rayon où le centre est entièrement Prairies (m)
const CENTER_BLEND := 28.0
const WATER_LEVEL := -2.2     ## surface des mares du marais (m)
const SEED := 20261120

static var _warp: FastNoiseLite
static var _dunes: FastNoiseLite


static func _ensure_noise() -> void:
	if _warp != null:
		return
	_warp = FastNoiseLite.new()
	_warp.seed = SEED
	_warp.frequency = 0.006
	_warp.fractal_octaves = 2
	_dunes = FastNoiseLite.new()
	_dunes.seed = SEED + 1
	_dunes.frequency = 0.02


static func weights_at(x: float, z: float) -> PackedFloat32Array:
	_ensure_noise()
	var w := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var angle := atan2(z, x) + _warp.get_noise_2d(x, z) * WARP
	var total := 0.0
	for i in SECTOR_ANGLES.size():
		var d := absf(angle_difference(angle, SECTOR_ANGLES[i]))
		w[i] = clampf((PI / 4.0 + BLEND - d) / (2.0 * BLEND), 0.0, 1.0)
		total += w[i]
	var outer := smoothstep(CENTER_FULL, CENTER_FULL + CENTER_BLEND, Vector2(x, z).length())
	for i in w.size():
		w[i] = w[i] / maxf(total, 0.0001) * outer
	w[PLAINE] += 1.0 - outer
	return w


static func biome_at(x: float, z: float) -> int:
	var w := weights_at(x, z)
	var best := 0
	for i in w.size():
		if w[i] > w[best]:
			best = i
	return best


## Biome tiré au hasard selon les poids (les bandes de transition mélangent les décors).
static func random_biome(x: float, z: float, rng: RandomNumberGenerator) -> int:
	var w := weights_at(x, z)
	var r := rng.randf()
	for i in w.size():
		r -= w[i]
		if r <= 0.0:
			return i
	return PLAINE


## Relief de base (MapTerrain) transformé selon les biomes : dunes, collines enneigées, cuvettes.
static func shape_height(x: float, z: float, base: float) -> float:
	var w := weights_at(x, z)
	var h := 0.0
	for i in w.size():
		if w[i] <= 0.0:
			continue
		var data := DATA[i]
		var hb := base * data.height_scale + data.height_offset
		if data.dunes > 0.0:
			var ripple := sin(x * 0.09 + z * 0.03 + _dunes.get_noise_2d(x, z) * 4.0)
			hb += data.dunes * (ripple * 0.5 + 0.5)
		h += w[i] * hb
	return h


## Couleur mélangée selon les poids ; getter = Callable(BiomeData) -> Color.
static func blend_color(w: PackedFloat32Array, getter: Callable) -> Color:
	var c := Color(0, 0, 0)
	for i in w.size():
		if w[i] > 0.0:
			c += (getter.call(DATA[i]) as Color) * w[i]
	return Color(c.r, c.g, c.b)


## Zone d'eau : marais dominant et sol sous la surface.
static func is_water(x: float, z: float, ground: float) -> bool:
	return ground < WATER_LEVEL and weights_at(x, z)[MARAIS] > 0.5
