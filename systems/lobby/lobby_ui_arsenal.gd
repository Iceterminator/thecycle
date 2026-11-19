extends RefCounted
## Onglet Arsenal du lobby : catégories, filtres, grille de cartes (débloquées, puis verrouillées
## par niveau de faction). La fiche détaillée est dans lobby_ui_arsenal_detail.gd, les widgets
## dans lobby_ui_arsenal_build.gd. L'état de l'équipement reste dans LobbyUi.

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const Build := preload("res://systems/lobby/lobby_ui_arsenal_build.gd")
const Detail := preload("res://systems/lobby/lobby_ui_arsenal_detail.gd")
const ACCENT := UiStyle.ACCENT
const GOLD := UiStyle.GOLD
const RED := UiStyle.RED
const DIM := UiStyle.DIM

var cat: int = LobbyUi.Cat.PRIMARY
var cat_buttons: Array[Button] = []
var sort_opt: OptionButton
var faction_opt: OptionButton
var grid_box: VBoxContainer
var grid_cards: Array[Dictionary] = []      # { entry, card }
var pick_hint: Label
var sel: Dictionary = {}                    # entrée sélectionnée
var detail_box: VBoxContainer
var detail_key: String = ""


func build(lobby: LobbyUi) -> Control:
	return Build.build(lobby, self)


func open(lobby: LobbyUi, new_cat: int) -> void:
	cat = new_cat
	sel = {}
	Build.refresh_cat_buttons(self)
	lobby._show_page(LobbyUi.Page.ARSENAL)


## Refait la grille (catégorie, tri ou filtre changés).
func rebuild_grid(lobby: LobbyUi) -> void:
	for child in grid_box.get_children():
		child.queue_free()
	grid_cards.clear()
	var faction_filter := faction_opt.selected - 1  # -1 = toutes
	var entries: Array[Dictionary] = []
	for e in lobby._catalog:
		if e["cat"] == cat and (faction_filter < 0 or e["faction"] == faction_filter):
			entries.append(e)
	entries.sort_custom(_sort_entries)
	# Débloqués d'abord, puis les verrouillés regroupés par niveau de faction.
	var unlocked: Array[Dictionary] = []
	var locked := {}
	for e in entries:
		if lobby._unlocked(e["faction"], e["level"]):
			unlocked.append(e)
		else:
			if not locked.has(e["level"]):
				locked[e["level"]] = []
			locked[e["level"]].append(e)
	_grid_section(lobby, "DÉBLOQUÉS (%d)" % unlocked.size(), unlocked)
	var levels: Array = locked.keys()
	levels.sort()
	for level: int in levels:
		var list: Array[Dictionary] = []
		list.assign(locked[level])
		_grid_section(lobby, "VERROUILLÉS — NIVEAU DE FACTION %d" % level, list)
	if sel.is_empty() or sel["cat"] != cat:
		sel = unlocked[0] if not unlocked.is_empty() else (entries[0] if not entries.is_empty() else {})
	detail_key = ""
	refresh(lobby)


func _grid_section(lobby: LobbyUi, title: String, entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	grid_box.add_child(W.label(title, 15, DIM))
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.15)
	line.custom_minimum_size = Vector2(0, 1)
	grid_box.add_child(line)
	var flow := W.flow()
	grid_box.add_child(flow)
	for e in entries:
		var card := UiCard.make(Vector2(196, 122))
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var sub := ""
		match int(e["cat"]):
			LobbyUi.Cat.ABILITY:
				sub = "Capacité — %d s" % roundi(AbilityController.get_ability(e["id"]).cooldown_s)
			LobbyUi.Cat.KIT:
				var k: KitData = e["kit"]
				sub = "PV %d · Bouclier %d" % [k.health if k.health > 0 else Config.combat.kit_default_health, k.shield if k.shield > 0 else Config.combat.kit_default_shield]
			LobbyUi.Cat.GADGET:
				sub = ""
		card.set_content(e["name"], sub, "", FactionData.color_of(e["faction"]))
		card.set_visual(e["id"])
		card.pressed.connect(func() -> void:
			sel = e
			detail_key = ""
			refresh(lobby))
		flow.add_child(card)
		grid_cards.append({"entry": e, "card": card})


func refresh(lobby: LobbyUi) -> void:
	var in_shop: Array = lobby._shop_weapons + lobby._shop_gadgets
	for g in grid_cards:
		var e: Dictionary = g["entry"]
		var card: UiCard = g["card"]
		var lock := lobby._lock_text(e["faction"], e["level"])
		card.set_state(not sel.is_empty() and sel["id"] == e["id"], lock != "")
		var tag := ""
		if e["id"] in in_shop:
			tag = "✔ boutique   "
		elif e["id"] == lobby._start_weapon:
			tag = "✔ départ   "
		elif e["id"] == lobby._kit_id:
			tag = "✔ équipé   "
		if lock != "":
			card.set_info(FactionData.lock_text(e["faction"], e["level"]), RED)
		elif e["cat"] == LobbyUi.Cat.KIT:
			card.set_info(tag, ACCENT)
		else:
			card.set_info("%s%d ¢" % [tag, e["price"]], GOLD)
	if lobby._selected_case >= 0:
		pick_hint.text = "Choisir pour : %s %d — sélectionnez un objet puis « Mettre dans la case »" % [
				"Arme" if lobby._selected_case < Config.SHOP_WEAPON_SLOTS else "Gadget / capacité",
				(lobby._selected_case % Config.SHOP_WEAPON_SLOTS) + 1]
	else:
		pick_hint.text = ""
	var key := JSON.stringify([sel.get("id", ""), lobby._shop_weapons, lobby._shop_gadgets, lobby._start_weapon, lobby._kit_id, lobby._kit_mods, lobby._weapon_mods, lobby._selected_case, lobby._rep_key()])
	if key != detail_key:
		detail_key = key
		Detail.rebuild(lobby, self)


## Tri de la grille selon le filtre choisi (prix croissant, décroissant, nom).
func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	if sort_opt.selected == 2 or a["price"] == b["price"]:
		return String(a["name"]) < String(b["name"])
	if sort_opt.selected == 1:
		return int(a["price"]) > int(b["price"])
	return int(a["price"]) < int(b["price"])
