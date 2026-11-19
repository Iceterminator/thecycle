class_name MapRelief
extends RefCounted
## Texture de relief des cartes (écran de largage, Tab, minimap), générée une seule fois par
## processus à partir de MapTerrain.height_at : teinte selon l'altitude, ombrage (lumière
## nord-ouest) et courbes de niveau légères. Jamais construite en serveur dédié (aucune carte dessinée).

const SIZE := 256
const CONTOUR_STEP := 2.0  ## équidistance des courbes de niveau (m)
const LOW_COLOR := Color(0.12, 0.17, 0.13)
const HIGH_COLOR := Color(0.5, 0.5, 0.38)
const LIGHT := Vector3(-0.6, 0.8, -0.6)  ## vers la lumière (nord-ouest, en haut)
const SHADE_GAIN := 1.6
const CONTOUR_DARKEN := 0.88

static var _texture: ImageTexture


## Texture couvrant la carte entière (de -MAP_HALF_SIZE à +MAP_HALF_SIZE), ou null sans affichage.
static func texture() -> ImageTexture:
	if _texture == null and not Net.is_dedicated_server and DisplayServer.get_name() != "headless":
		_texture = ImageTexture.create_from_image(_build())
	return _texture


static func _build() -> Image:
	var half := Config.MAP_HALF_SIZE
	var cell := half * 2.0 / SIZE
	var stride := SIZE + 2  # marge d'un pixel pour les différences finies
	var heights := PackedFloat32Array()
	heights.resize(stride * stride)
	var low := INF
	var high := -INF
	for j in stride:
		for i in stride:
			var h := MapTerrain.height_at(-half + (i - 0.5) * cell, -half + (j - 0.5) * cell)
			heights[j * stride + i] = h
			low = minf(low, h)
			high = maxf(high, h)
	var light := LIGHT.normalized()
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for j in SIZE:
		for i in SIZE:
			var k := (j + 1) * stride + (i + 1)
			var h := heights[k]
			var gx := (heights[k + 1] - heights[k - 1]) / (2.0 * cell)
			var gz := (heights[k + stride] - heights[k - stride]) / (2.0 * cell)
			var shade := Vector3(-gx, 1.0, -gz).normalized().dot(light)
			var color := LOW_COLOR.lerp(HIGH_COLOR, inverse_lerp(low, high, h))
			color = color * clampf(1.0 + (shade - light.y) * SHADE_GAIN, 0.4, 1.5)
			var level := floori(h / CONTOUR_STEP)
			if floori(heights[k + 1] / CONTOUR_STEP) != level or floori(heights[k + stride] / CONTOUR_STEP) != level:
				color = color * CONTOUR_DARKEN
			image.set_pixel(i, j, Color(color.r, color.g, color.b))
	return image
