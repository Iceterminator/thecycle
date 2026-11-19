extends RefCounted
## Écran 3 de l'onglet Équipement : sélecteur « Choisissez votre … » (filtre de faction, cartes).

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const Slots := preload("res://systems/lobby/loadout_page_slots.gd")
const Info := preload("res://systems/lobby/loadout_page_info.gd")
const ACCENT := UiStyle.ACCENT
const RED := UiStyle.RED


static func build(page: LoadoutPage) -> void:
	var lobby := page.lobby
	var box := page._panel_box
	W.clear(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(W.label("Choisissez votre ", 28))
	var what := W.label(Slots.slot_title(page._slot), 32, ACCENT)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(what)
	var faction := page._faction_opt.selected if page._faction_opt else 0
	page._faction_opt = OptionButton.new()
	page._faction_opt.add_item("Toutes les factions")
	page._faction_opt.add_item("Départ")
	for f in FactionData.all():
		page._faction_opt.add_item(FactionData.name_of(f.id))
	page._faction_opt.select(faction)
	page._faction_opt.item_selected.connect(func(_i: int) -> void: page.refresh())
	head.add_child(page._faction_opt)

	var entries: Array[Dictionary] = []
	var cats := Slots.slot_cats(page._slot)
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
	box.add_child(grid)
	var current := Slots.slot_id(lobby, page._slot)
	for e in entries:
		grid.add_child(_card(page, e, current))
	if page._picked != "":
		page._preview(page._picked)
	var buttons := page._button_bar
	buttons.add_child(W.big_button("FERMER", false, page.show_overview))
	var picked := lobby._entry(page._picked)
	var can_equip := not picked.is_empty() and page._picked != current and lobby._unlocked(picked["faction"], picked["level"])
	var equip := W.big_button("ÉQUIPER", true, func() -> void:
		Slots.equip(lobby, page._slot, page._picked)
		page.show_overview())
	equip.disabled = not can_equip
	buttons.add_child(equip)


static func _card(page: LoadoutPage, e: Dictionary, current: String) -> UiCard:
	var id: String = e["id"]
	var lock := page.lobby._lock_text(e["faction"], e["level"])
	var card := UiCard.make(Vector2(350, 118))
	var tag := "✔ équipé" if id == current else ""
	card.set_content(String(e["name"]), Info.type_line(e), lock.trim_prefix("Verrouillé : ") if lock != "" else tag, FactionData.color_of(int(e["faction"])))
	if lock != "":
		card.set_info(lock.trim_prefix("Verrouillé : "), RED)
	card.set_visual(id)
	card.set_state(id == page._picked, lock != "")
	card.pressed.connect(func() -> void:
		page._picked = id
		page.refresh())
	card.mouse_entered.connect(func() -> void: page._preview(id))
	card.mouse_exited.connect(func() -> void: page._preview(page._picked if page._picked != "" else current))
	return card
