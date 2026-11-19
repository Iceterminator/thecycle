class_name UiStyle
extends RefCounted
## Direction artistique « Nuit polaire » des menus et du HUD : fond bleu nuit en dégradé,
## panneaux bleu acier translucides, accent cuivre / ambre, cartes à coins coupés,
## police Barlow Condensed (libre, licence OFL : assets/fonts/barlow_condensed/OFL.txt).
## Tout le code d'interface prend ses couleurs ici ; `apply_fonts()` est appelé au démarrage
## (scenes/main/main.gd) et `theme()` donne le thème des boutons, listes et barres de défilement.

# --- Palette ---
const BG_TOP := Color(0.04, 0.07, 0.12)
const BG_BOTTOM := Color(0.07, 0.12, 0.19)
const BAR := Color(0.05, 0.09, 0.14, 0.98)          ## barre d'onglets
const PANEL := Color(0.09, 0.15, 0.23, 0.88)        ## panneaux bleu acier
const PANEL_BORDER := Color(0.36, 0.56, 0.76, 0.45)
const CARD := Color(0.11, 0.19, 0.29, 0.92)
const CARD_HOVER := Color(0.15, 0.25, 0.37, 0.95)
const CARD_SELECTED := Color(0.2, 0.17, 0.12, 0.96)
const CARD_LOCKED := Color(0.2, 0.07, 0.08, 0.9)
const ACCENT := Color(1.0, 0.62, 0.26)              ## cuivre : sélection, onglet actif, bouton principal
const GOLD := Color(1.0, 0.84, 0.42)                ## prix, Fame, crédits
const ICE := Color(0.62, 0.85, 1.0)                 ## titres secondaires, chiffres
const TEXT := Color(0.94, 0.97, 1.0)
const DIM := Color(0.7, 0.8, 0.92, 0.6)
const RED := Color(1.0, 0.45, 0.42)
const LOCKED := Color(0.85, 0.28, 0.28)
const CHAMFER := 10                                  ## coins coupés (haut gauche, bas droite)

const FONT_DIR := "res://assets/fonts/barlow_condensed/"

const ThemeBuilder := preload("res://systems/ui/ui_style_theme.gd")

static var _theme: Theme


static func font(weight: String = "Medium") -> Font:
	var path := FONT_DIR + "BarlowCondensed-%s.ttf" % weight
	return load(path) as Font if ResourceLoader.exists(path) else ThemeDB.fallback_font


## Police par défaut de toute l'interface (y compris les Label créés sans thème).
static func apply_fonts() -> void:
	ThemeDB.fallback_font = font("Medium")
	ThemeDB.fallback_font_size = 18


## Fond des cartes et panneaux : coins coupés en haut à gauche et en bas à droite.
static func chamfer_box(bg: Color, border: Color, width: int = 1, cut: int = CHAMFER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.corner_radius_top_left = cut
	s.corner_radius_bottom_right = cut
	s.corner_detail = 1  # coin coupé droit, pas arrondi
	s.anti_aliasing = true
	return s


static func panel_box() -> StyleBoxFlat:
	var s := chamfer_box(PANEL, PANEL_BORDER, 1, 18)
	s.border_width_top = 2
	s.set_content_margin_all(20)
	return s


## Thème commun : boutons, listes déroulantes, menus, barres de défilement, info-bulles.
static func theme() -> Theme:
	if _theme == null:
		_theme = ThemeBuilder.build()
	return _theme


## Fond dégradé bleu nuit (plein écran) pour les menus.
static func make_background() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, BG_TOP)
	gradient.set_color(1, BG_BOTTOM)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.2, 0.0)
	texture.fill_to = Vector2(0.8, 1.0)
	texture.width = 64
	texture.height = 64
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return rect


const LOBBY_IMAGE := "res://assets/ui/lobby_background.webp"


## Fond du lobby : l'illustration (couvre l'écran sans se déformer) sous un voile bleu nuit
## plus sombre en haut et en bas, pour que les panneaux et les textes restent lisibles.
## Sans image, le dégradé seul.
static func make_lobby_background() -> Control:
	var root := make_background()
	if not ResourceLoader.exists(LOBBY_IMAGE):
		return root
	var image := TextureRect.new()
	image.texture = load(LOBBY_IMAGE) as Texture2D
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.75, 1.0])
	gradient.colors = PackedColorArray([Color(BG_TOP, 0.85), Color(BG_TOP, 0.35), Color(BG_TOP, 0.3), Color(BG_TOP, 0.8)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 8
	texture.height = 128
	var veil := TextureRect.new()
	veil.texture = texture
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return root
