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

enum View { OVERVIEW, DETAIL, PICKER }

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
	_preview_name = _label("", 34)
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_preview_name)
	_preview_sub = _label("", 16, DIM)
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
	_clear(_button_bar)
	match _view:
		View.OVERVIEW:
			_build_overview()
		View.DETAIL:
			_build_detail()
		View.PICKER:
			_build_picker()


func show_overview() -> void:
	_view = View.OVERVIEW
	_key = ""
	refresh()


func _open(view: int, slot: String) -> void:
	_view = view
	_slot = slot
	_picked = _slot_id(slot)
	_faction_opt = null
	_key = ""
	refresh()


# =========================================================================
# Emplacements
# =========================================================================

func _slot_id(slot: String) -> String:
	match slot:
		"start":
			return lobby._start_weapon
		"kit":
			return lobby._kit_id
	var index := int(slot.substr(1))
	return String(lobby._shop_weapons[index] if slot.begins_with("w") else lobby._shop_gadgets[index])


func _slot_title(slot: String) -> String:
	match slot:
		"start":
			return "arme de départ"
		"kit":
			return "combinaison"
	return "arme" if slot.begins_with("w") else "gadget ou capacité"


## Catégories du catalogue acceptées par l'emplacement.
func _slot_cats(slot: String) -> Array:
	match slot:
		"start":
			return [LobbyUi.Cat.SECONDARY]
		"kit":
			return [LobbyUi.Cat.KIT]
	return [LobbyUi.Cat.PRIMARY, LobbyUi.Cat.SECONDARY] if slot.begins_with("w") else [LobbyUi.Cat.GADGET, LobbyUi.Cat.ABILITY]


func _equip(slot: String, id: String) -> void:
	match slot:
		"start":
			lobby._start_weapon = id
		"kit":
			lobby._kit_id = id
		_:
			var list: Array = lobby._shop_weapons if slot.begins_with("w") else lobby._shop_gadgets
			var index := int(slot.substr(1))
			var already := list.find(id)
			if already >= 0:
				list[already] = list[index]  # déjà dans une autre case : on échange
			list[index] = id
	lobby._changed()


# =========================================================================
# 1. Vue d'ensemble
# =========================================================================

func _build_overview() -> void:
	_clear(_panel_box)
	_preview(lobby._kit_id)
	_panel_box.add_child(_label("ÉQUIPEMENT DE DÉPART", 26))
	var start_row := HBoxContainer.new()
	start_row.add_theme_constant_override("separation", 16)
	_panel_box.add_child(start_row)
	start_row.add_child(_column("ARME DE DÉPART", [_tile("start")]))
	start_row.add_child(_column("COMBINAISON", [_tile("kit")]))
	_panel_box.add_child(_label("BOUTIQUE EN PARTIE", 26))
	var shop_row := HBoxContainer.new()
	shop_row.add_theme_constant_override("separation", 16)
	_panel_box.add_child(shop_row)
	var weapons: Array[Control] = []
	var gadgets: Array[Control] = []
	for i in Config.SHOP_WEAPON_SLOTS:
		weapons.append(_tile("w%d" % i))
	for i in Config.SHOP_GADGET_SLOTS:
		gadgets.append(_tile("g%d" % i))
	shop_row.add_child(_column("ARMES", weapons))
	shop_row.add_child(_column("GADGETS ET CAPACITÉS", gadgets))
	_panel_box.add_child(_label("Clic : fiche de l'objet   ·   ⇄ : changer   ·   + : remplir la case", 14, DIM))


func _column(title: String, tiles: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(_label(title, 16, DIM))
	for tile: Control in tiles:
		col.add_child(tile)
	return col


## Case d'emplacement : nom, prix, visuel, mod éventuel, bouton ⇄.
func _tile(slot: String) -> Control:
	var id := _slot_id(slot)
	var card := UiCard.make(Vector2(330, 120))
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if id == "":
		card.set_content("+", "Case vide", "", Color(0.4, 0.4, 0.4))
		card.pressed.connect(func() -> void: _open(View.PICKER, slot))
		return card
	var e := lobby._entry(id)
	var sub := ""
	if e.get("cat") in [LobbyUi.Cat.PRIMARY, LobbyUi.Cat.SECONDARY]:
		var mod := WeaponModData.get_mod(String(lobby._weapon_mods.get(id, "")))
		sub = "Mod : " + mod.display_name if mod else ""
	elif e.get("cat") == LobbyUi.Cat.KIT:
		sub = "Mod : %s" % _kit_mod_text(id) if String(lobby._kit_mods.get(id, "")) != "" else ""
	var price := "" if slot in ["start", "kit"] else "%d ¢" % Shop.entry_price(id)
	card.set_content(String(e.get("name", id)), sub, "", FactionData.color_of(int(e.get("faction", 0))))
	card.set_visual(id)
	if price != "":
		var price_label := _label(price, 15, GOLD)
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(price_label)
		price_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		price_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		price_label.offset_right = -12
		price_label.offset_top = 10
	card.pressed.connect(func() -> void: _open(View.DETAIL, slot))
	card.mouse_entered.connect(func() -> void: _preview(id))
	card.mouse_exited.connect(func() -> void: _preview(lobby._kit_id))
	var swap := Button.new()
	swap.text = "⇄"
	swap.tooltip_text = "Changer"
	swap.focus_mode = Control.FOCUS_NONE
	swap.add_theme_font_size_override("font_size", 18)
	swap.add_theme_stylebox_override("normal", _round(Color(ACCENT, 0.2), ACCENT))
	swap.add_theme_stylebox_override("hover", _round(Color(ACCENT, 0.45), ACCENT))
	swap.add_theme_stylebox_override("pressed", _round(ACCENT, ACCENT))
	swap.pressed.connect(func() -> void: _open(View.PICKER, slot))
	card.add_child(swap)
	swap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	swap.offset_left = -42
	swap.offset_top = -40
	swap.offset_right = -8
	swap.offset_bottom = -8
	return card


func _kit_mod_text(kit_id: String) -> String:
	var kit := lobby._kit_data(kit_id)
	var mod_id := String(lobby._kit_mods.get(kit_id, ""))
	if kit:
		for m: Dictionary in kit.mods:
			if String(m["id"]) == mod_id:
				return String(m.get("effect", mod_id))
	return mod_id


# =========================================================================
# 2. Fiche d'un objet
# =========================================================================

func _build_detail() -> void:
	_clear(_panel_box)
	var id := _slot_id(_slot)
	if id == "":
		show_overview()
		return
	_preview(id)
	var e := lobby._entry(id)
	_panel_box.add_child(_label(String(e.get("name", id)), 40))
	_panel_box.add_child(_label(_type_line(e), 17, FactionData.color_of(int(e.get("faction", 0))).lightened(0.2)))
	var text := _description(e)
	if text != "":
		var label := _label(text, 15, Color(1, 1, 1, 0.8))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_panel_box.add_child(label)
	# Mods.
	match int(e.get("cat", -1)):
		LobbyUi.Cat.PRIMARY, LobbyUi.Cat.SECONDARY:
			_panel_box.add_child(_label("MOD D'ARME", 16, DIM))
			_panel_box.add_child(lobby._weapon_mod_option(id))
		LobbyUi.Cat.KIT:
			var kit: KitData = e["kit"]
			if not kit.mods.is_empty():
				_panel_box.add_child(_label("MOD DE LA COMBINAISON", 16, DIM))
				var current := String(lobby._kit_mods.get(id, ""))
				for m: Dictionary in kit.mods:
					var mod_id := String(m["id"])
					var ok := KitController.mod_unlocked(lobby._me(), kit, mod_id)
					var label := String(m.get("effect", mod_id)) + ("" if ok else "   [%s]" % FactionData.lock_text(int(kit.faction), int(m.get("unlock_level", 0))))
					_panel_box.add_child(lobby._action(("✔ " if current == mod_id else "") + label, ok, func() -> void:
						lobby._kit_mods[id] = "" if current == mod_id else mod_id
						lobby._changed()))
	_panel_box.add_child(HSeparator.new())
	_panel_box.add_child(_label("STATISTIQUES", 16, DIM))
	_panel_box.add_child(_stats(e))
	var buttons := _button_bar
	buttons.add_child(_big_button("FERMER", false, show_overview))
	buttons.add_child(_big_button("CHANGER ⇄", true, func() -> void: _open(View.PICKER, _slot)))


# =========================================================================
# 3. Sélecteur
# =========================================================================

func _build_picker() -> void:
	_clear(_panel_box)
	var head := HBoxContainer.new()
	_panel_box.add_child(head)
	head.add_child(_label("Choisissez votre ", 28))
	var what := _label(_slot_title(_slot), 32, ACCENT)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(what)
	var faction := _faction_opt.selected if _faction_opt else 0
	_faction_opt = OptionButton.new()
	_faction_opt.add_item("Toutes les factions")
	_faction_opt.add_item("Départ")
	for f in FactionData.all():
		_faction_opt.add_item(FactionData.name_of(f.id))
	_faction_opt.select(faction)
	_faction_opt.item_selected.connect(func(_i: int) -> void: refresh())
	head.add_child(_faction_opt)

	var entries: Array[Dictionary] = []
	var cats := _slot_cats(_slot)
	for e in lobby._catalog:
		if e["cat"] in cats and (faction == 0 or int(e["faction"]) == faction - 1):
			entries.append(e)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ua := lobby._unlocked(a["faction"], a["level"])
		var ub := lobby._unlocked(b["faction"], b["level"])
		if ua != ub:
			return ua
		if a["faction"] != b["faction"]:
			return a["faction"] < b["faction"]
		if a["level"] != b["level"]:
			return a["level"] < b["level"]
		return String(a["name"]) < String(b["name"]))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_panel_box.add_child(grid)
	var current := _slot_id(_slot)
	for e in entries:
		var id: String = e["id"]
		var lock := lobby._lock_text(e["faction"], e["level"])
		var card := UiCard.make(Vector2(350, 118))
		var tag := "✔ équipé" if id == current else ""
		card.set_content(String(e["name"]), _type_line(e), lock.trim_prefix("Verrouillé : ") if lock != "" else tag, FactionData.color_of(int(e["faction"])))
		if lock != "":
			card.set_info(lock.trim_prefix("Verrouillé : "), RED)
		card.set_visual(id)
		card.set_state(id == _picked, lock != "")
		card.pressed.connect(func() -> void:
			_picked = id
			refresh())
		card.mouse_entered.connect(func() -> void: _preview(id))
		card.mouse_exited.connect(func() -> void: _preview(_picked if _picked != "" else current))
		grid.add_child(card)
	if _picked != "":
		_preview(_picked)
	var buttons := _button_bar
	buttons.add_child(_big_button("FERMER", false, show_overview))
	var picked := lobby._entry(_picked)
	var can_equip := not picked.is_empty() and _picked != current and lobby._unlocked(picked["faction"], picked["level"])
	var equip := _big_button("ÉQUIPER", true, func() -> void:
		_equip(_slot, _picked)
		show_overview())
	equip.disabled = not can_equip
	buttons.add_child(equip)


# =========================================================================
# Aperçu, statistiques, textes
# =========================================================================

func _preview(id: String) -> void:
	for child in _preview_slot.get_children():
		child.queue_free()
	_clear(_preview_stats)
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
	_preview_sub.text = lock if lock != "" else _type_line(e)
	if _view == View.PICKER:
		_preview_stats.add_child(_stats(e))


func _type_line(e: Dictionary) -> String:
	var faction := int(e.get("faction", 0))
	var where := FactionData.name_of(faction) if faction > 0 else "Départ"
	match int(e.get("cat", -1)):
		LobbyUi.Cat.PRIMARY, LobbyUi.Cat.SECONDARY:
			var w: WeaponData = e["weapon"]
			var slot := "Arme secondaire" if e["cat"] == LobbyUi.Cat.SECONDARY else "Arme principale"
			return "%s | %s · %s" % [slot, LobbyUi.TYPE_NAMES[clampi(int(w.type), 0, LobbyUi.TYPE_NAMES.size() - 1)], where]
		LobbyUi.Cat.GADGET:
			return "Gadget · " + where
		LobbyUi.Cat.ABILITY:
			return "Capacité · " + where
		LobbyUi.Cat.KIT:
			return "Combinaison · " + where
	return where


func _description(e: Dictionary) -> String:
	match int(e.get("cat", -1)):
		LobbyUi.Cat.PRIMARY, LobbyUi.Cat.SECONDARY, LobbyUi.Cat.GADGET:
			var w: WeaponData = e["weapon"]
			return w.role if w.role != "" else w.behavior
		LobbyUi.Cat.ABILITY:
			return AbilityController.get_ability(e["id"]).behavior
		LobbyUi.Cat.KIT:
			return (e["kit"] as KitData).playstyle
	return ""


## Grands chiffres à gauche, barres à droite (armes) ; chiffres seuls sinon.
func _stats(e: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	var numbers := VBoxContainer.new()
	numbers.add_theme_constant_override("separation", 2)
	row.add_child(numbers)
	match int(e.get("cat", -1)):
		LobbyUi.Cat.PRIMARY, LobbyUi.Cat.SECONDARY:
			var w: WeaponData = e["weapon"]
			_number(numbers, "Dégâts", str(roundi(w.damage)))
			_number(numbers, "Taille du chargeur", str(lobby._player.magazine_for(w)))
			var bars := VBoxContainer.new()
			bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bars.add_theme_constant_override("separation", 4)
			row.add_child(bars)
			var range_m := w.falloff_end_m if w.falloff_end_m > 0.0 else (w.max_range_m if w.max_range_m > 0.0 else 100.0)
			_bar(bars, "Cadence de tir", clampf(w.rpm / 1000.0, 0.03, 1.0))
			_bar(bars, "Vitesse de rechargement", clampf(1.0 - (w.reload_s - 1.0) / 5.0, 0.05, 1.0))
			_bar(bars, "Portée", clampf(range_m / 150.0, 0.05, 1.0))
			_bar(bars, "Stabilité", clampf(1.0 - w.recoil_deg / 3.0, 0.05, 1.0))
		LobbyUi.Cat.GADGET:
			var w: WeaponData = e["weapon"]
			_number(numbers, "Charges", str(w.magazine))
			_number(numbers, "Prix", "%d ¢" % e["price"])
		LobbyUi.Cat.ABILITY:
			var a := AbilityController.get_ability(e["id"])
			_number(numbers, "Recharge", "%d s" % roundi(a.cooldown_s))
			var more := VBoxContainer.new()
			row.add_child(more)
			if a.duration_s > 0.0:
				_number(more, "Durée", "%d s" % roundi(a.duration_s))
			if a.damage > 0.0:
				_number(more, "Dégâts", str(roundi(a.damage)))
			_number(numbers, "Prix", "%d ¢" % e["price"])
		LobbyUi.Cat.KIT:
			var k: KitData = e["kit"]
			_number(numbers, "PV", str(roundi(k.health if k.health > 0 else Config.combat.kit_default_health)))
			var more := VBoxContainer.new()
			row.add_child(more)
			_number(more, "Bouclier", str(roundi(k.shield if k.shield > 0 else Config.combat.kit_default_shield)))
			var speed := VBoxContainer.new()
			row.add_child(speed)
			_number(speed, "Vitesse", "%.1f m/s" % (k.move_speed_mps if k.move_speed_mps > 0 else Config.combat.kit_default_speed))
	return row


func _number(box: VBoxContainer, name: String, value: String) -> void:
	box.add_child(_label(name, 15, DIM))
	box.add_child(_label(value, 36, UiStyle.ICE))


func _bar(box: VBoxContainer, name: String, ratio: float) -> void:
	box.add_child(_label(name, 14, DIM))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220, 6)
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = ratio
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.92, 0.95, 0.97)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	box.add_child(bar)


func _big_button(text: String, primary: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(200, 50)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_font_override("font", UiStyle.font("Bold"))
	var color := ACCENT if primary else Color(1, 1, 1, 0.5)
	button.add_theme_stylebox_override("normal", _round(Color(color, 0.12), color))
	button.add_theme_stylebox_override("hover", _round(Color(color, 0.3), color))
	button.add_theme_stylebox_override("pressed", _round(Color(color, 0.5), color))
	button.add_theme_stylebox_override("disabled", _round(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.15)))
	button.pressed.connect(callback)
	return button


func _round(bg: Color, border: Color) -> StyleBoxFlat:
	var s := UiStyle.chamfer_box(bg, border, 2, 10)
	s.content_margin_left = 14
	s.content_margin_right = 14
	return s


func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	if size >= 20:
		label.add_theme_font_override("font", UiStyle.font("SemiBold"))
	label.add_theme_color_override("font_color", color)
	return label


func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
