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
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("Medium")
	t.default_font_size = 18
	# Boutons secondaires (les boutons principaux sont colorés à la main).
	var normal := chamfer_box(Color(0.12, 0.2, 0.3, 0.9), PANEL_BORDER, 1, 6)
	var hover := chamfer_box(Color(0.16, 0.27, 0.39, 0.95), ICE.darkened(0.2), 1, 6)
	var pressed := chamfer_box(Color(0.24, 0.19, 0.12, 0.95), ACCENT, 2, 6)
	var disabled := chamfer_box(Color(0.08, 0.11, 0.15, 0.8), Color(1, 1, 1, 0.08), 1, 6)
	for box: StyleBoxFlat in [normal, hover, pressed, disabled]:
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 4
		box.content_margin_bottom = 4
	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, ACCENT)
		t.set_color("font_disabled_color", type, Color(1, 1, 1, 0.3))
	# Menus déroulants.
	var popup := chamfer_box(Color(0.07, 0.12, 0.19, 0.98), PANEL_BORDER, 1, 6)
	popup.set_content_margin_all(6)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", chamfer_box(Color(ACCENT, 0.25), Color(0, 0, 0, 0), 0, 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", Color(1, 1, 1, 0.3))
	# Barres de défilement fines.
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(ICE, 0.35)
	grabber.set_corner_radius_all(3)
	var grabber_hot := grabber.duplicate() as StyleBoxFlat
	grabber_hot.bg_color = Color(ACCENT, 0.8)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.05)
	track.set_corner_radius_all(3)
	track.content_margin_left = 3
	track.content_margin_right = 3
	for type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("grabber", type, grabber)
		t.set_stylebox("grabber_highlight", type, grabber_hot)
		t.set_stylebox("grabber_pressed", type, grabber_hot)
		t.set_stylebox("scroll", type, track)
	# Info-bulles.
	var tip := chamfer_box(Color(0.05, 0.09, 0.14, 0.97), PANEL_BORDER, 1, 4)
	tip.set_content_margin_all(8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_color("font_color", "Label", TEXT)
	t.set_constant("separation", "HSeparator", 12)
	var sep := StyleBoxLine.new()
	sep.color = Color(ICE, 0.18)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	_theme = t
	return t


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
