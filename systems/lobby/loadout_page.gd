class_name LoadoutPage
extends HBoxContainer
## Onglet Équipement du lobby, en trois écrans qui s'enchaînent :
## 1. Vue d'ensemble : à gauche le grand aperçu (combinaison, ou l'objet survolé) ; à droite
##    « ÉQUIPEMENT DE DÉPART » (arme de départ, combinaison) et « BOUTIQUE EN PARTIE »
##    (4 armes, 4 gadgets / capacités). Chaque case : nom, prix, visuel, bouton ⇄ ;
##    clic = fiche, ⇄ ou case vide = sélecteur.
## 2. Fiche : description, mods (arme ou combinaison), statistiques ; Fermer / Changer.
## 3. Sélecteur « Choisissez votre … » : filtre de faction, cartes (verrouillées grisées),
##    l'objet choisi s'affiche en grand à gauche avec ses stats ; Fermer / ÉQUIPER.
## L'état de l'équipement reste dans LobbyUi (qui l'envoie au serveur) : cette page le lit
## et le modifie, puis appelle lobby._changed().
## Le contenu de chaque écran est construit par loadout_page_overview / _detail / _picker,
## les emplacements par loadout_page_slots, textes et statistiques par loadout_page_info.

enum View { OVERVIEW, DETAIL, PICKER }

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const Slots := preload("res://systems/lobby/loadout_page_slots.gd")
const Info := preload("res://systems/lobby/loadout_page_info.gd")
const Overview := preload("res://systems/lobby/loadout_page_overview.gd")
const Detail := preload("res://systems/lobby/loadout_page_detail.gd")
const Picker := preload("res://systems/lobby/loadout_page_picker.gd")
const ACCENT := UiStyle.ACCENT
const GOLD := UiStyle.GOLD
const RED := UiStyle.RED
const DIM := UiStyle.DIM

var lobby: LobbyUi
var _view: int = View.OVERVIEW
var _slot: String = ""        # "start", "kit", "w0".."w3", "g0".."g3"
var _picked: String = ""      # objet choisi dans le sélecteur
var _key: String = ""

var _preview_slot: Control
var _preview_name: Label
var _preview_sub: Label
var _preview_stats: VBoxContainer
var _panel_box: VBoxContainer
var _faction_opt: OptionButton
var _button_bar: HBoxContainer  ## FERMER / CHANGER / ÉQUIPER, fixés en bas du panneau


func setup(owner_lobby: LobbyUi) -> void:
	lobby = owner_lobby
	add_theme_constant_override("separation", 26)
	# Aperçu à gauche.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	add_child(left)
	_preview_slot = Control.new()
	_preview_slot.custom_minimum_size = Vector2(0, 380)
	_preview_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_preview_slot)
	_preview_name = W.label("", 34)
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_preview_name)
	_preview_sub = W.label("", 16, DIM)
	_preview_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_preview_sub)
	_preview_stats = VBoxContainer.new()
	_preview_stats.add_theme_constant_override("separation", 4)
	left.add_child(_preview_stats)
	# Panneau à droite.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_button_bar = HBoxContainer.new()
	_button_bar.alignment = BoxContainer.ALIGNMENT_END
	_button_bar.add_theme_constant_override("separation", 12)
	column.add_child(_button_bar)
	_panel_box = VBoxContainer.new()
	_panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_box.add_theme_constant_override("separation", 10)
	scroll.add_child(_panel_box)


## Appelé régulièrement par le lobby : refait l'écran seulement si quelque chose a changé.
func refresh() -> void:
	var key := JSON.stringify([_view, _slot, _picked, lobby._kit_id, lobby._start_weapon, lobby._shop_weapons,
			lobby._shop_gadgets, lobby._kit_mods, lobby._weapon_mods, lobby._rep_key(),
			_faction_opt.selected if _faction_opt and _view == View.PICKER else -1])
	if key == _key:
		return
	_key = key
	W.clear(_button_bar)
	match _view:
		View.OVERVIEW:
			Overview.build(self)
		View.DETAIL:
			Detail.build(self)
		View.PICKER:
			Picker.build(self)


func show_overview() -> void:
	_view = View.OVERVIEW
	_key = ""
	refresh()


func _open(view: int, slot: String) -> void:
	_view = view
	_slot = slot
	_picked = Slots.slot_id(lobby, slot)
	_faction_opt = null
	_key = ""
	refresh()


## Aperçu à gauche : visuel, nom, ligne de type, et statistiques dans le sélecteur.
func _preview(id: String) -> void:
	for child in _preview_slot.get_children():
		child.queue_free()
	W.clear(_preview_stats)
	var e := lobby._entry(id)
	if e.is_empty():
		_preview_name.text = ""
		_preview_sub.text = ""
		return
	var visual := ItemVisual.make(id)
	if visual:
		_preview_slot.add_child(visual)
		# Centré, sans prendre toute la zone (les kits seraient énormes).
		visual.anchor_left = 0.12
		visual.anchor_right = 0.88
		visual.anchor_top = 0.08 if e["cat"] != LobbyUi.Cat.KIT else 0.12
		visual.anchor_bottom = 0.92 if e["cat"] != LobbyUi.Cat.KIT else 0.88
		ItemVisual.set_colors(visual, not lobby._unlocked(e["faction"], e["level"]))
	_preview_name.text = String(e["name"])
	var lock := lobby._lock_text(e["faction"], e["level"])
	_preview_sub.text = lock if lock != "" else Info.type_line(e)
	if _view == View.PICKER:
		_preview_stats.add_child(Info.stats(lobby, e))
