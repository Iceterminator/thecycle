extends RefCounted
## Écran 1 de l'onglet Équipement : vue d'ensemble (départ + boutique) et cases d'emplacement.

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const Slots := preload("res://systems/lobby/loadout_page_slots.gd")
const KitMods := preload("res://systems/lobby/lobby_ui_kit_mods.gd")
const ACCENT := UiStyle.ACCENT
const GOLD := UiStyle.GOLD
const DIM := UiStyle.DIM


static func build(page: LoadoutPage) -> void:
	var box := page._panel_box
	W.clear(box)
	page._preview(page.lobby._kit_id)
	box.add_child(W.label("ÉQUIPEMENT DE DÉPART", 26))
	var start_row := HBoxContainer.new()
	start_row.add_theme_constant_override("separation", 16)
	box.add_child(start_row)
	start_row.add_child(_column("ARME DE DÉPART", [_tile(page, "start")]))
	start_row.add_child(_column("COMBINAISON", [_tile(page, "kit")]))
	box.add_child(W.label("BOUTIQUE EN PARTIE", 26))
	var shop_row := HBoxContainer.new()
	shop_row.add_theme_constant_override("separation", 16)
	box.add_child(shop_row)
	var weapons: Array[Control] = []
	var gadgets: Array[Control] = []
	for i in Config.SHOP_WEAPON_SLOTS:
		weapons.append(_tile(page, "w%d" % i))
	for i in Config.SHOP_GADGET_SLOTS:
		gadgets.append(_tile(page, "g%d" % i))
	shop_row.add_child(_column("ARMES", weapons))
	shop_row.add_child(_column("GADGETS ET CAPACITÉS", gadgets))
	box.add_child(W.label("Clic : fiche de l'objet   ·   ⇄ : changer   ·   + : remplir la case", 14, DIM))


static func _column(title: String, tiles: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(W.label(title, 16, DIM))
	for tile: Control in tiles:
		col.add_child(tile)
	return col


## Case d'emplacement : nom, prix, visuel, mod éventuel, bouton ⇄.
static func _tile(page: LoadoutPage, slot: String) -> Control:
	var lobby := page.lobby
	var id := Slots.slot_id(lobby, slot)
	var card := UiCard.make(Vector2(330, 120))
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if id == "":
		card.set_content("+", "Case vide", "", Color(0.4, 0.4, 0.4))
		card.pressed.connect(func() -> void: page._open(LoadoutPage.View.PICKER, slot))
		return card
	var e := lobby._entry(id)
	var sub := ""
	if e.get("cat") in [LobbyUi.Cat.PRIMARY, LobbyUi.Cat.SECONDARY]:
		var names: Array[String] = []
		var chosen: Dictionary = lobby._weapon_mods.get(id, {})
		for slot_key: String in chosen:
			var mod := WeaponModData.get_mod(String(chosen[slot_key]))
			if mod:
				names.append(mod.display_name)
		sub = "Mods : " + ", ".join(names) if not names.is_empty() else ""
	elif e.get("cat") == LobbyUi.Cat.KIT:
		var mods_text := KitMods.summary(lobby, id)
		sub = "Mods : " + mods_text if mods_text != "" else ""
	var price := "" if slot in ["start", "kit"] else "%d ¢" % Shop.entry_price(id)
	card.set_content(String(e.get("name", id)), sub, "", FactionData.color_of(int(e.get("faction", 0))))
	card.set_visual(id)
	if price != "":
		var price_label := W.label(price, 15, GOLD)
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(price_label)
		price_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		price_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		price_label.offset_right = -12
		price_label.offset_top = 10
	card.pressed.connect(func() -> void: page._open(LoadoutPage.View.DETAIL, slot))
	card.mouse_entered.connect(func() -> void: page._preview(id))
	card.mouse_exited.connect(func() -> void: page._preview(lobby._kit_id))
	var swap := Button.new()
	swap.text = "⇄"
	swap.tooltip_text = "Changer"
	swap.focus_mode = Control.FOCUS_NONE
	swap.add_theme_font_size_override("font_size", 18)
	swap.add_theme_stylebox_override("normal", W.round_box(Color(ACCENT, 0.2), ACCENT))
	swap.add_theme_stylebox_override("hover", W.round_box(Color(ACCENT, 0.45), ACCENT))
	swap.add_theme_stylebox_override("pressed", W.round_box(ACCENT, ACCENT))
	swap.pressed.connect(func() -> void: page._open(LoadoutPage.View.PICKER, slot))
	card.add_child(swap)
	swap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	swap.offset_left = -42
	swap.offset_top = -40
	swap.offset_right = -8
	swap.offset_bottom = -8
	return card
