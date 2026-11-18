class_name LobbyUi
extends CanvasLayer
## Écran du lobby (étape 9, joueur local), affiché pendant la phase LOBBY du MatchManager.
## Barre du haut : escouade, onglets, pseudo, compte à rebours, bouton PRÊT. Onglets :
## - Décollage : joueurs prêts, résumé de l'équipement ;
## - Équipement (LoadoutPage) : vue d'ensemble (départ + boutique), fiche d'un objet, sélecteur ;
##   voir loadout_page.gd ;
## - Arsenal : catégories à gauche, filtres, cartes (débloquées, puis verrouillées par
##   niveau de faction), fiche détaillée à droite avec les actions ;
## - Factions : faction de prédilection et ce que chaque niveau de réputation débloque ;
## - Escouade : créer, rejoindre, quitter.
## Chaque changement est envoyé au serveur (ProfileManager.request_set_loadout), qui vérifie tout.

const SEND_DELAY := 0.3
const BG := UiStyle.BG_TOP
const BAR := UiStyle.BAR
const ACCENT := UiStyle.ACCENT
const GOLD := UiStyle.GOLD
const RED := UiStyle.RED
const DIM := UiStyle.DIM

enum Page { LAUNCH, LOADOUT, ARSENAL, FACTIONS, SQUAD }
enum Cat { PRIMARY, SECONDARY, GADGET, ABILITY, KIT }
const CAT_NAMES := ["Armes principales", "Armes secondaires", "Gadgets", "Capacités", "Kits"]
const TYPE_NAMES := ["Pistolet-mitrailleur", "Fusil d'assaut", "Fusil de combat", "Fusil de précision",
		"Fusil à pompe", "Mitrailleuse", "Pistolet", "Lance-missiles", "Arme lourde", "Gadget"]

var _player: Player
var _world: Node

# --- État de l'équipement (envoyé au serveur) ---
var _preferred: int = 0
var _kit_id: String = String(Config.DEFAULT_KIT)
var _kit_mods: Dictionary = {}       # id de kit -> id de mod
var _weapon_mods: Dictionary = {}    # id d'arme -> id de mod
var _start_weapon: String = String(Config.BASE_WEAPON)
var _shop_weapons: Array = []
var _shop_gadgets: Array = []
var _send_left: float = -1.0

# --- Barre du haut ---
var _pages: Array[Control] = []
var _nav: Array[Button] = []
var _page: int = Page.LAUNCH
var _squad_chip: Label
var _countdown: Label
var _ready_button: Button
var _status: Label

# --- Décollage ---
var _launch_clock: Label
var _launch_ready: Label
var _launch_players: VBoxContainer
var _launch_summary: VBoxContainer
var _launch_button: Button

# --- Équipement ---
var _loadout_page: LoadoutPage
var _selected_case: int = -1

# --- Équipement (LoadoutPage : vue d'ensemble, fiche, sélecteur) ---

func _new_loadout_page() -> Control:
	_loadout_page = LoadoutPage.new()
	_loadout_page.setup(self)
	return _loadout_page


# --- Arsenal ---
var _catalog: Array[Dictionary] = []         # { id, cat, name, faction, level, price, weapon, kit }
var _cat: int = Cat.PRIMARY
var _cat_buttons: Array[Button] = []
var _sort_opt: OptionButton
var _faction_opt: OptionButton
var _grid_box: VBoxContainer
var _grid_cards: Array[Dictionary] = []      # { entry, card }
var _pick_hint: Label
var _sel: Dictionary = {}                    # entrée sélectionnée
var _detail_box: VBoxContainer
var _detail_key: String = ""

# --- Factions, escouade ---
var _faction_cards: Array[Dictionary] = []   # { id, card }
var _progress_columns: Array[Dictionary] = []
var _players_box: VBoxContainer
var _squads_box: VBoxContainer


var _ready_players: Dictionary = {}
var _refresh_left: float = 0.0
var _squads_key: String = ""
var _launch_key: String = ""


func setup(player: Player) -> void:
	_player = player
	_world = player.get_parent().get_parent()
	layer = 9  # au-dessus du HUD et de la carte, sous la boutique et les menus (admin)
	visible = false
	var default_shop := ProfileManager.default_shop()
	_shop_weapons = _padded(default_shop["weapons"], Config.SHOP_WEAPON_SLOTS)
	_shop_gadgets = _padded(default_shop["gadgets"], Config.SHOP_GADGET_SLOTS)
	_build_catalog()
	_build()
	_show_page(Page.LAUNCH)
	Events.match_clock_synced.connect(_on_clock)
	Events.lobby_synced.connect(func(ready: Dictionary) -> void: _ready_players = ready)
	Events.local_loadout_received.connect(_apply_saved)
	Events.match_clock_requested.emit()
	# Sur l'hôte, le profil peut être arrivé avant la création de cet écran.
	var profiles := _world.get_node_or_null("ProfileManager") as ProfileManager
	if profiles and not profiles.local_loadout.is_empty():
		_apply_saved(profiles.local_loadout)


func _on_clock(_elapsed: float, phase: int) -> void:
	var lobby := phase == MatchManager.Phase.LOBBY
	if lobby == visible:
		return
	visible = lobby
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if lobby else Input.MOUSE_MODE_CAPTURED
	if lobby:
		_set_ready(false, false)
		_show_page(Page.LAUNCH)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton:  # pas de tir ; les touches (menus) passent
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _send_left >= 0.0:
		_send_left -= delta
		if _send_left < 0.0:
			_send()
	if not visible:
		return
	var total := _player.get_parent().get_child_count()
	var ready := _ready_count()
	_countdown.text = "PRÊTS  %d / %d" % [ready, total]
	_launch_clock.text = "%d / %d" % [ready, total]
	_launch_ready.text = "Tout le monde est prêt : départ !" if ready >= total else "En attente de %d joueur%s" % [total - ready, "s" if total - ready > 1 else ""]
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.5
		_refresh()


func _me() -> int:
	return _player.get_peer_id()


func _ready_count() -> int:
	var n := 0
	for peer: int in _ready_players:
		if _ready_players[peer]:
			n += 1
	return n


func _set_ready(on: bool, send: bool) -> void:
	for button in [_ready_button, _launch_button]:
		(button as Button).set_pressed_no_signal(on)
		(button as Button).text = "PRÊT ✔" if on else "PRÊT"
	if send:
		var match_manager := _world.get_node_or_null("MatchManager") as MatchManager
		if match_manager:
			match_manager.request_lobby_ready.rpc_id(1, on)


# =========================================================================
# État : chargement, envoi
# =========================================================================

## Équipement sauvegardé (envoyé par le serveur à l'arrivée).
func _apply_saved(loadout: Dictionary) -> void:
	_preferred = int(loadout.get("preferred", 0))
	_kit_id = String(loadout.get("kit", Config.DEFAULT_KIT))
	_kit_mods = loadout.get("kit_mods", {}).duplicate()
	_weapon_mods = loadout.get("weapon_mods", {}).duplicate()
	_start_weapon = String(loadout.get("start_weapon", Config.BASE_WEAPON))
	var shop: Dictionary = loadout.get("shop", ProfileManager.default_shop())
	_shop_weapons = _padded(shop.get("weapons", []), Config.SHOP_WEAPON_SLOTS)
	_shop_gadgets = _padded(shop.get("gadgets", []), Config.SHOP_GADGET_SLOTS)
	_refresh()


func _padded(list: Array, size: int) -> Array:
	var out: Array = []
	for i in size:
		out.append(String(list[i]) if i < list.size() else "")
	return out


func _changed() -> void:
	_send_left = SEND_DELAY
	_detail_key = ""
	_refresh()


func _send() -> void:
	var profiles := _world.get_node_or_null("ProfileManager") as ProfileManager
	if profiles == null:
		return
	profiles.request_set_loadout.rpc_id(1, {
		"kit": _kit_id,
		"kit_mod": String(_kit_mods.get(_kit_id, "")),
		"weapon_mods": _weapon_mods,
		"start_weapon": _start_weapon,
		"shop": {"weapons": _shop_weapons, "gadgets": _shop_gadgets},
	}, _preferred)
	_set_status("Équipement enregistré", ACCENT)


func _set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func _unlocked(faction: int, level: int) -> bool:
	return ProfileManager.is_unlocked(_me(), faction, level)


func _lock_text(faction: int, level: int) -> String:
	return "" if _unlocked(faction, level) else "Verrouillé : " + FactionData.lock_text(faction, level)


func _rep_key() -> String:
	var parts: PackedStringArray = []
	for f in FactionData.all():
		parts.append(str(ProfileManager.rep_points(_me(), f.id)))
	return ",".join(parts)


func _kit_data(id: String) -> KitData:
	for e in _catalog:
		if e["cat"] == Cat.KIT and e["id"] == id:
			return e["kit"]
	return null


# =========================================================================
# Catalogue (Arsenal)
# =========================================================================

func _build_catalog() -> void:
	for item in Items.get_items_of_kind(ItemData.Kind.WEAPON):
		var w := item.weapon
		if w == null:
			continue
		var cat := Cat.GADGET if w.gadget != WeaponData.GadgetKind.NONE \
				else (Cat.SECONDARY if w.slot == WeaponData.Slot.SECONDARY else Cat.PRIMARY)
		_catalog.append({"id": String(item.id), "cat": cat, "name": item.display_name, "faction": int(w.faction),
				"level": w.faction_level, "price": item.price, "weapon": w, "kit": null})
	for a in AbilityController.list_abilities():
		_catalog.append({"id": String(a.id), "cat": Cat.ABILITY, "name": a.get_display_name(), "faction": int(a.faction),
				"level": a.faction_level, "price": Config.ABILITY_PRICE, "weapon": null, "kit": null})
	for k in KitController.list_kits():
		_catalog.append({"id": String(k.id), "cat": Cat.KIT, "name": KitController.kit_name(k), "faction": int(k.faction),
				"level": k.faction_level, "price": 0, "weapon": null, "kit": k})


func _entry(id: String) -> Dictionary:
	for e in _catalog:
		if e["id"] == id:
			return e
	return {}


## Refait la grille (catégorie, tri ou filtre changés).
func _rebuild_grid() -> void:
	for child in _grid_box.get_children():
		child.queue_free()
	_grid_cards.clear()
	var faction_filter := _faction_opt.selected - 1  # -1 = toutes
	var entries: Array[Dictionary] = []
	for e in _catalog:
		if e["cat"] == _cat and (faction_filter < 0 or e["faction"] == faction_filter):
			entries.append(e)
	entries.sort_custom(_sort_entries)
	# Débloqués d'abord, puis les verrouillés regroupés par niveau de faction.
	var unlocked: Array[Dictionary] = []
	var locked := {}
	for e in entries:
		if _unlocked(e["faction"], e["level"]):
			unlocked.append(e)
		else:
			if not locked.has(e["level"]):
				locked[e["level"]] = []
			locked[e["level"]].append(e)
	_grid_section("DÉBLOQUÉS (%d)" % unlocked.size(), unlocked)
	var levels: Array = locked.keys()
	levels.sort()
	for level: int in levels:
		var list: Array[Dictionary] = []
		list.assign(locked[level])
		_grid_section("VERROUILLÉS — NIVEAU DE FACTION %d" % level, list)
	if _sel.is_empty() or _sel["cat"] != _cat:
		_sel = unlocked[0] if not unlocked.is_empty() else (entries[0] if not entries.is_empty() else {})
	_detail_key = ""
	_refresh_arsenal()


func _grid_section(title: String, entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return
	var header := _label(title, 15, DIM)
	_grid_box.add_child(header)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.15)
	line.custom_minimum_size = Vector2(0, 1)
	_grid_box.add_child(line)
	var flow := _flow()
	_grid_box.add_child(flow)
	for e in entries:
		var card := UiCard.make(Vector2(196, 122))
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var sub := ""
		match int(e["cat"]):
			Cat.ABILITY:
				sub = "Capacité — %d s" % roundi(AbilityController.get_ability(e["id"]).cooldown_s)
			Cat.KIT:
				var k: KitData = e["kit"]
				sub = "PV %d · Bouclier %d" % [k.health if k.health > 0 else Config.KIT_DEFAULT_HEALTH, k.shield if k.shield > 0 else Config.KIT_DEFAULT_SHIELD]
			Cat.GADGET:
				sub = ""
		card.set_content(e["name"], sub, "", FactionData.color_of(e["faction"]))
		card.set_visual(e["id"])
		card.pressed.connect(func() -> void:
			_sel = e
			_detail_key = ""
			_refresh_arsenal())
		flow.add_child(card)
		_grid_cards.append({"entry": e, "card": card})


func _refresh_arsenal() -> void:
	var in_shop: Array = _shop_weapons + _shop_gadgets
	for g in _grid_cards:
		var e: Dictionary = g["entry"]
		var card: UiCard = g["card"]
		var lock := _lock_text(e["faction"], e["level"])
		card.set_state(not _sel.is_empty() and _sel["id"] == e["id"], lock != "")
		var tag := ""
		if e["id"] in in_shop:
			tag = "✔ boutique   "
		elif e["id"] == _start_weapon:
			tag = "✔ départ   "
		elif e["id"] == _kit_id:
			tag = "✔ équipé   "
		if lock != "":
			card.set_info(FactionData.lock_text(e["faction"], e["level"]), RED)
		elif e["cat"] == Cat.KIT:
			card.set_info(tag, ACCENT)
		else:
			card.set_info("%s%d ¢" % [tag, e["price"]], GOLD)
	if _selected_case >= 0:
		_pick_hint.text = "Choisir pour : %s %d — sélectionnez un objet puis « Mettre dans la case »" % [
				"Arme" if _selected_case < Config.SHOP_WEAPON_SLOTS else "Gadget / capacité",
				(_selected_case % Config.SHOP_WEAPON_SLOTS) + 1]
	else:
		_pick_hint.text = ""
	var key := JSON.stringify([_sel.get("id", ""), _shop_weapons, _shop_gadgets, _start_weapon, _kit_id, _kit_mods, _weapon_mods, _selected_case, _rep_key()])
	if key != _detail_key:
		_detail_key = key
		_rebuild_detail()


# =========================================================================
# Fiche détaillée
# =========================================================================

func _rebuild_detail() -> void:
	for child in _detail_box.get_children():
		child.queue_free()
	if _sel.is_empty():
		return
	var e := _sel
	var id: String = e["id"]
	var faction: int = e["faction"]
	var color := FactionData.color_of(faction)
	var head := HBoxContainer.new()
	_detail_box.add_child(head)
	var title := _label(e["name"], 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title)
	if e["cat"] != Cat.KIT:
		head.add_child(_label("%d ¢" % e["price"], 26, GOLD))
	var kind_text: String = CAT_NAMES[e["cat"]]
	if e["weapon"]:
		kind_text = TYPE_NAMES[clampi(int((e["weapon"] as WeaponData).type), 0, TYPE_NAMES.size() - 1)]
	_detail_box.add_child(_label("%s   ·   %s" % [kind_text, FactionData.name_of(faction) if faction > 0 else "Départ"], 15, color))
	var lock := _lock_text(faction, e["level"])
	if lock != "":
		_detail_box.add_child(_label(lock, 16, RED))
	var visual := ItemVisual.make(id)
	if visual:
		visual.custom_minimum_size = Vector2(0, 120 if e["weapon"] else 140)
		ItemVisual.set_colors(visual, lock != "")
		_detail_box.add_child(visual)
	match int(e["cat"]):
		Cat.PRIMARY, Cat.SECONDARY:
			_detail_weapon(e["weapon"])
		Cat.GADGET:
			var w: WeaponData = e["weapon"]
			_detail_text(w.role if w.role != "" else w.behavior)
			_detail_numbers([["Charges", str(w.magazine)], ["Usage", "limité" if w.consumable else "rechargeable"]])
		Cat.ABILITY:
			var a := AbilityController.get_ability(id)
			_detail_text(a.behavior)
			var numbers: Array = [["Recharge", "%d s" % roundi(a.cooldown_s)]]
			if a.duration_s > 0.0:
				numbers.append(["Durée", "%d s" % roundi(a.duration_s)])
			if a.damage > 0.0:
				numbers.append(["Dégâts", str(roundi(a.damage))])
			if a.radius_m > 0.0:
				numbers.append(["Rayon", "%d m" % roundi(a.radius_m)])
			_detail_numbers(numbers)
		Cat.KIT:
			var k: KitData = e["kit"]
			_detail_text(k.playstyle)
			_detail_numbers([["PV", str(roundi(k.health if k.health > 0 else Config.KIT_DEFAULT_HEALTH))],
					["Bouclier", str(roundi(k.shield if k.shield > 0 else Config.KIT_DEFAULT_SHIELD))],
					["Vitesse", "%.1f m/s" % (k.move_speed_mps if k.move_speed_mps > 0 else Config.KIT_DEFAULT_SPEED)]])
	_detail_box.add_child(HSeparator.new())
	_detail_actions(e, lock == "")


func _detail_weapon(w: WeaponData) -> void:
	_detail_text(w.role)
	_detail_numbers([["Dégâts", str(roundi(w.damage))], ["Chargeur", str(w.magazine)]])
	var range_m := w.falloff_end_m if w.falloff_end_m > 0.0 else (w.max_range_m if w.max_range_m > 0.0 else 100.0)
	_detail_stat("Cadence de tir", clampf(w.rpm / 1000.0, 0.03, 1.0))
	_detail_stat("Vitesse de rechargement", clampf(1.0 - (w.reload_s - 1.0) / 5.0, 0.05, 1.0))
	_detail_stat("Portée", clampf(range_m / 150.0, 0.05, 1.0))
	_detail_stat("Stabilité", clampf(1.0 - w.recoil_deg / 3.0, 0.05, 1.0))


func _detail_text(text: String) -> void:
	if text == "":
		return
	var label := _label(text, 14, Color(1, 1, 1, 0.75))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_box.add_child(label)


func _detail_numbers(numbers: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	_detail_box.add_child(row)
	for pair: Array in numbers:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -4)
		col.add_child(_label(pair[0], 14, DIM))
		col.add_child(_label(pair[1], 30))
		row.add_child(col)


func _detail_stat(name: String, ratio: float) -> void:
	_detail_box.add_child(_label(name, 14, DIM))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = ratio
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	_detail_box.add_child(bar)


func _detail_actions(e: Dictionary, unlocked: bool) -> void:
	var id: String = e["id"]
	var cat: int = e["cat"]
	if cat == Cat.KIT:
		var equipped := id == _kit_id
		_detail_box.add_child(_action("Kit équipé ✔" if equipped else "Équiper ce kit", unlocked and not equipped, func() -> void:
			_kit_id = id
			_changed()))
		var k: KitData = e["kit"]
		if not k.mods.is_empty():
			_detail_box.add_child(_label("MODS DU KIT" + ("" if equipped else " — équipez le kit pour en choisir un"), 14, DIM))
			for m: Dictionary in k.mods:
				var mod_id := String(m["id"])
				var mod_ok := KitController.mod_unlocked(_me(), k, mod_id)
				var current := String(_kit_mods.get(id, "")) == mod_id
				var text := "%s%s" % [String(m.get("effect", mod_id)), "" if mod_ok else "   [%s]" % FactionData.lock_text(int(k.faction), int(m.get("unlock_level", 0)))]
				var button := _action(("✔ " if current else "") + text, mod_ok and equipped, func() -> void:
					_kit_mods[id] = "" if current else mod_id
					_changed())
				_detail_box.add_child(button)
		return
	var is_weapon := cat in [Cat.PRIMARY, Cat.SECONDARY]
	var list: Array = _shop_weapons if is_weapon else _shop_gadgets
	if id in list:
		_detail_box.add_child(_action("Retirer de la boutique", true, func() -> void:
			list[list.find(id)] = ""
			_changed()))
	else:
		var target := _target_case(is_weapon)
		var text := "Mettre dans la boutique (case %d)" % (target + 1) if target >= 0 else "Boutique pleine : choisissez une case (Équipement)"
		_detail_box.add_child(_action(text, unlocked and target >= 0, func() -> void:
			list[target] = id
			var from_loadout := _selected_case >= 0
			_selected_case = -1
			_changed()
			if from_loadout:
				_show_page(Page.LOADOUT)))
	if cat == Cat.SECONDARY:
		var is_start := id == _start_weapon
		_detail_box.add_child(_action("Arme de départ ✔" if is_start else "Choisir comme arme de départ", unlocked and not is_start, func() -> void:
			_start_weapon = id
			_changed()))
	if is_weapon:
		_detail_box.add_child(_label("MOD D'ARME", 14, DIM))
		_detail_box.add_child(_weapon_mod_option(id))


## Case visée : celle choisie dans l'onglet Équipement, sinon la première vide du bon type.
func _target_case(is_weapon: bool) -> int:
	if _selected_case >= 0 and (_selected_case < Config.SHOP_WEAPON_SLOTS) == is_weapon:
		return _selected_case if is_weapon else _selected_case - Config.SHOP_WEAPON_SLOTS
	var list: Array = _shop_weapons if is_weapon else _shop_gadgets
	return list.find("")


func _weapon_mod_option(weapon_id: String) -> OptionButton:
	var mods := WeaponModData.all()
	var opt := OptionButton.new()
	opt.add_item("Aucun mod")
	var current := String(_weapon_mods.get(weapon_id, ""))
	for i in mods.size():
		var m := mods[i]
		var lock := _lock_text(m.faction, m.faction_level)
		opt.add_item(m.display_name + ("   [%s]" % FactionData.lock_text(m.faction, m.faction_level) if lock != "" else ""))
		opt.set_item_disabled(i + 1, lock != "")
		opt.set_item_tooltip(i + 1, m.description)
		if String(m.id) == current:
			opt.select(i + 1)
	opt.item_selected.connect(func(index: int) -> void:
		if index <= 0:
			_weapon_mods.erase(weapon_id)
		else:
			_weapon_mods[weapon_id] = String(mods[index - 1].id)
		_changed())
	return opt


func _action(text: String, enabled: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.custom_minimum_size = Vector2(0, 40)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_stylebox_override("normal", _box_style(Color(0.13, 0.21, 0.31), Color(ACCENT, 0.55), 1))
	button.add_theme_stylebox_override("hover", _box_style(Color(0.17, 0.27, 0.39), ACCENT, 1))
	button.add_theme_stylebox_override("pressed", _box_style(Color(0.26, 0.2, 0.13), ACCENT, 2))
	button.add_theme_stylebox_override("disabled", _box_style(Color(0.08, 0.11, 0.15), Color(1, 1, 1, 0.1), 1))
	button.pressed.connect(callback)
	return button


# =========================================================================
# Mise à jour des onglets
# =========================================================================

func _refresh() -> void:
	if _countdown == null:
		return
	var squad := SquadManager.squad_of(_me())
	_squad_chip.text = "ESCOUADE %d/%d" % [SquadManager.members_of(squad).size() if squad != 0 else 1, Config.SQUAD_MAX]
	match _page:
		Page.LAUNCH:
			_refresh_launch()
		Page.LOADOUT:
			_loadout_page.refresh()
		Page.ARSENAL:
			_refresh_arsenal()
		Page.FACTIONS:
			_refresh_factions()
		Page.SQUAD:
			_refresh_squads()


func _refresh_launch() -> void:
	var names: PackedStringArray = []
	for node in _player.get_parent().get_children():
		var p := node as Player
		if p:
			names.append("%d:%s:%s:%d" % [p.get_peer_id(), ProfileManager.name_of(p.get_peer_id()), _ready_players.get(p.get_peer_id(), false), SquadManager.squad_of(p.get_peer_id())])
	var key := JSON.stringify([names, _kit_id, _start_weapon, _shop_weapons, _shop_gadgets, _preferred])
	if key == _launch_key:
		return
	_launch_key = key
	_clear(_launch_players)
	for node in _player.get_parent().get_children():
		var p := node as Player
		if p == null:
			continue
		var id := p.get_peer_id()
		var squad := SquadManager.squad_of(id)
		var ready: bool = _ready_players.get(id, false)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(_label("✔" if ready else "○", 20, ACCENT if ready else DIM))
		row.add_child(_label(ProfileManager.name_of(id), 20, GOLD if id == _me() else Color.WHITE))
		if squad != 0:
			row.add_child(_label("escouade %d" % squad, 15, DIM))
		_launch_players.add_child(row)
	_clear(_launch_summary)
	var kit := _kit_data(_kit_id)
	_launch_summary.add_child(_label("KIT", 14, DIM))
	_launch_summary.add_child(_label(KitController.kit_name(kit) if kit else _kit_id, 22))
	_launch_summary.add_child(_label("ARME DE DÉPART", 14, DIM))
	_launch_summary.add_child(_summary_weapon(_start_weapon))
	_launch_summary.add_child(_label("BOUTIQUE EN PARTIE", 14, DIM))
	for id: String in _shop_weapons + _shop_gadgets:
		if id != "":
			_launch_summary.add_child(_summary_weapon(id))
	_launch_summary.add_child(_label("FACTION DE PRÉDILECTION : %s" % (FactionData.name_of(_preferred) if _preferred > 0 else "aucune"), 14, DIM))


func _summary_weapon(id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var visual := ItemVisual.make(id)
	if visual:
		visual.custom_minimum_size = Vector2(64, 26)
		row.add_child(visual)
	row.add_child(_label(Shop.entry_name(id), 17))
	return row


func _refresh_factions() -> void:
	for e in _faction_cards:
		(e["card"] as UiCard).set_state(int(e["id"]) == _preferred, false)
	for col in _progress_columns:
		var faction: int = col["faction"]
		var points := ProfileManager.rep_points(_me(), faction)
		var level := ProfileManager.rep_level_of_points(points)
		var maxed := level >= Config.REP_LEVELS.size()
		var previous: int = Config.REP_LEVELS[level - 1] if level > 0 else 0
		var next: int = previous if maxed else Config.REP_LEVELS[level]
		(col["level"] as Label).text = "NIVEAU %d" % level
		var bar: ProgressBar = col["bar"]
		bar.max_value = maxf(next - previous, 1)
		bar.value = bar.max_value if maxed else points - previous
		(col["points"] as Label).text = "%d points — niveau maximum" % points if maxed \
				else "%d / %d points → niveau %d" % [points, next, level + 1]
		for row: Dictionary in col["rows"]:
			var unlocked: bool = level >= int(row["level"])
			(row["label"] as Control).modulate = Color(1, 1, 1, 1.0) if unlocked else Color(1, 1, 1, 0.38)
			(row["mark"] as Label).text = "✔" if unlocked else "·"


func _refresh_squads() -> void:
	# Refait seulement si quelque chose a changé (sinon un clic en cours serait perdu).
	var player_names: PackedStringArray = []
	for node in _player.get_parent().get_children():
		if node is Player:
			player_names.append(ProfileManager.name_of((node as Player).get_peer_id()))
	var key := JSON.stringify([player_names, _ready_players, SquadManager.all_squads()])
	if key == _squads_key:
		return
	_squads_key = key
	_clear(_players_box)
	for node in _player.get_parent().get_children():
		var p := node as Player
		if p == null:
			continue
		var id := p.get_peer_id()
		var squad := SquadManager.squad_of(id)
		_players_box.add_child(_label("%s  %s%s" % ["✔" if _ready_players.get(id, false) else "○", ProfileManager.name_of(id),
				"   (escouade %d)" % squad if squad != 0 else ""], 18, GOLD if id == _me() else Color.WHITE))
	_clear(_squads_box)
	var manager := _world.get_node_or_null("SquadManager") as SquadManager
	if manager == null:
		return
	var mine := SquadManager.squad_of(_me())
	var squads := SquadManager.all_squads()
	for squad: int in squads:
		var names: PackedStringArray = []
		for peer: int in squads[squad]:
			names.append(ProfileManager.name_of(peer))
		var card := UiCard.make(Vector2(420, 70))
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var full: bool = squads[squad].size() >= Config.SQUAD_MAX
		card.set_content("Escouade %d (%d / %d)" % [squad, squads[squad].size(), Config.SQUAD_MAX], ", ".join(names),
				"Votre escouade" if squad == mine else ("Complète" if full else "Rejoindre →"))
		card.set_state(squad == mine, full and squad != mine)
		card.disabled = squad == mine or full
		card.pressed.connect(func() -> void: manager.request_join.rpc_id(1, squad))
		_squads_box.add_child(card)
	if mine == 0:
		_squads_box.add_child(_action("Créer une escouade", true, func() -> void: manager.request_create.rpc_id(1)))
	else:
		_squads_box.add_child(_action("Quitter l'escouade", true, func() -> void: manager.request_leave.rpc_id(1)))


# =========================================================================
# Construction
# =========================================================================

func _build() -> void:
	var bg := UiStyle.make_lobby_background()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	root.theme = UiStyle.theme()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_build_top_bar())
	var line := ColorRect.new()
	line.color = ACCENT.darkened(0.4)
	line.custom_minimum_size = Vector2(0, 2)
	root.add_child(line)
	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	root.add_child(margin)
	var stack := Control.new()
	margin.add_child(stack)
	for builder: Callable in [_build_launch, _new_loadout_page, _build_arsenal, _build_factions, _build_squad]:
		var page: Control = builder.call()
		stack.add_child(page)
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_pages.append(page)


func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = BAR
	style.content_margin_left = 18
	style.content_margin_right = 18
	bar.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	_squad_chip = _label("ESCOUADE 1/4", 15, DIM)
	_squad_chip.custom_minimum_size = Vector2(130, 0)
	_squad_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_squad_chip)
	for i in 5:
		var button := Button.new()
		button.text = ["DÉCOLLAGE", "ÉQUIPEMENT", "ARSENAL", "FACTIONS", "ESCOUADE"][i]
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(150, 60)
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_font_override("font", UiStyle.font("SemiBold"))
		var page := i
		button.pressed.connect(func() -> void:
			if page != Page.ARSENAL:
				_selected_case = -1
			_show_page(page))
		row.add_child(button)
		_nav.append(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_status = _label("", 14)
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_status)
	var me := _label(ProfileManager.name_of(_me()), 16, GOLD)
	me.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	me.custom_minimum_size = Vector2(110, 0)
	me.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(me)
	_countdown = _label("", 18)
	_countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown.custom_minimum_size = Vector2(150, 0)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_countdown)
	_ready_button = _ready_toggle(Vector2(150, 44), 20)
	_ready_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_ready_button)
	return bar


func _ready_toggle(min_size: Vector2, font: int) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.text = "PRÊT"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", font)
	button.add_theme_color_override("font_color", Color(0.05, 0.08, 0.07))
	button.add_theme_color_override("font_pressed_color", Color(0.05, 0.08, 0.07))
	button.add_theme_color_override("font_hover_color", Color(0.05, 0.08, 0.07))
	button.add_theme_font_override("font", UiStyle.font("Bold"))
	var ready_color := Color(0.5, 0.92, 0.6)  # vert : prêt
	button.add_theme_stylebox_override("normal", _box_style(ACCENT, ACCENT, 0))
	button.add_theme_stylebox_override("hover", _box_style(ACCENT.lightened(0.2), ACCENT, 0))
	button.add_theme_stylebox_override("pressed", _box_style(ready_color, ready_color, 0))
	button.add_theme_stylebox_override("hover_pressed", _box_style(ready_color.lightened(0.2), ready_color, 0))
	button.toggled.connect(func(on: bool) -> void: _set_ready(on, true))
	return button


func _show_page(page: int) -> void:
	_page = page
	for i in _pages.size():
		_pages[i].visible = i == page
	for i in _nav.size():
		var active := i == page
		var style := StyleBoxFlat.new()
		style.bg_color = Color(ACCENT, 0.12) if active else Color(0, 0, 0, 0)
		style.border_color = ACCENT
		style.border_width_bottom = 3 if active else 0
		for state in ["normal", "hover", "pressed"]:
			_nav[i].add_theme_stylebox_override(state, style)
		_nav[i].add_theme_color_override("font_color", ACCENT if active else Color(1, 1, 1, 0.75))
		_nav[i].add_theme_color_override("font_hover_color", ACCENT.lightened(0.2))
	if page == Page.ARSENAL:
		_rebuild_grid()
	if page == Page.LOADOUT and _loadout_page:
		_loadout_page.show_overview()
	_launch_key = ""
	_squads_key = ""
	_refresh()


# --- Décollage ---

func _build_launch() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	left.add_child(_label("DÉCOLLAGE", 18, DIM))
	_launch_clock = _label("00:00", 72)
	left.add_child(_launch_clock)
	_launch_ready = _label("", 20, ACCENT)
	left.add_child(_launch_ready)
	_launch_button = _ready_toggle(Vector2(320, 64), 28)
	_launch_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(_launch_button)
	left.add_child(_label("La partie démarre seulement quand tous les prospecteurs sont prêts.", 14, DIM))
	left.add_child(HSeparator.new())
	left.add_child(_label("PROSPECTEURS", 16, DIM))
	_launch_players = VBoxContainer.new()
	left.add_child(_launch_players)
	var right := _panel(Vector2(560, 0))
	row.add_child(right)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	right.add_child(box)
	box.add_child(_label("VOTRE ÉQUIPEMENT", 18, ACCENT))
	_launch_summary = VBoxContainer.new()
	_launch_summary.add_theme_constant_override("separation", 4)
	box.add_child(_launch_summary)
	box.add_child(_action("Modifier l'équipement →", true, func() -> void: _show_page(Page.LOADOUT)))
	return row


# --- Équipement ---

func _open_arsenal(cat: int) -> void:
	_cat = cat
	_sel = {}
	_refresh_cat_buttons()
	_show_page(Page.ARSENAL)


# --- Arsenal ---

func _build_arsenal() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	var cats := VBoxContainer.new()
	cats.custom_minimum_size = Vector2(220, 0)
	cats.add_theme_constant_override("separation", 4)
	row.add_child(cats)
	for i in CAT_NAMES.size():
		var button := Button.new()
		button.text = CAT_NAMES[i]
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 20)
		var cat := i
		button.pressed.connect(func() -> void:
			_cat = cat
			_sel = {}
			_refresh_cat_buttons()
			_rebuild_grid())
		cats.add_child(button)
		_cat_buttons.append(button)
	_refresh_cat_buttons()

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	row.add_child(center)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 10)
	center.add_child(filters)
	_sort_opt = OptionButton.new()
	for text in ["Prix le plus bas", "Prix le plus haut", "Nom"]:
		_sort_opt.add_item(text)
	_sort_opt.item_selected.connect(func(_i: int) -> void: _rebuild_grid())
	filters.add_child(_sort_opt)
	_faction_opt = OptionButton.new()
	_faction_opt.add_item("Toutes les factions")
	_faction_opt.add_item("Départ")
	for f in FactionData.all():
		_faction_opt.add_item(FactionData.name_of(f.id))
	_faction_opt.item_selected.connect(func(_i: int) -> void: _rebuild_grid())
	filters.add_child(_faction_opt)
	_pick_hint = _label("", 15, ACCENT)
	_pick_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_pick_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center.add_child(scroll)
	_grid_box = VBoxContainer.new()
	_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_grid_box)

	var detail := _panel(Vector2(470, 0))
	row.add_child(detail)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail.add_child(detail_scroll)
	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(_detail_box)
	return row


func _refresh_cat_buttons() -> void:
	for i in _cat_buttons.size():
		var active := i == _cat
		var style := StyleBoxFlat.new()
		style.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.14) if active else Color(0, 0, 0, 0)
		style.border_color = ACCENT
		style.border_width_left = 4 if active else 0
		style.content_margin_left = 14
		for state in ["normal", "hover", "pressed"]:
			_cat_buttons[i].add_theme_stylebox_override(state, style)
		_cat_buttons[i].add_theme_color_override("font_color", ACCENT if active else Color(1, 1, 1, 0.8))


# --- Factions ---

func _build_factions() -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	box.add_child(_label("FACTION DE PRÉDILECTION — +%d %% de réputation avec elle" % roundi(Config.PREFERRED_FACTION_BONUS * 100.0), 16, DIM))
	var factions := HBoxContainer.new()
	factions.add_theme_constant_override("separation", 10)
	box.add_child(factions)
	var none := UiCard.make(Vector2(180, 60))
	none.set_content("Aucune", "", "", Color(0.5, 0.5, 0.5))
	none.pressed.connect(func() -> void:
		_preferred = 0
		_changed())
	factions.add_child(none)
	_faction_cards.append({"id": 0, "card": none})
	for f in FactionData.all():
		var card := UiCard.make(Vector2(180, 60))
		card.set_content(FactionData.name_of(f.id), "", "", f.color)
		var fid := f.id
		card.pressed.connect(func() -> void:
			_preferred = fid
			_changed())
		factions.add_child(card)
		_faction_cards.append({"id": fid, "card": card})
	box.add_child(_label("RÉPUTATION — gagnée avec les contrats de chaque faction ; chaque niveau débloque des objets", 16, DIM))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	box.add_child(columns)
	var unlocks := _unlock_table()
	for f in FactionData.all():
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.09, 0.11, 0.95)
		style.border_color = f.color
		style.border_width_top = 4
		style.set_corner_radius_all(6)
		style.set_content_margin_all(14)
		panel.add_theme_stylebox_override("panel", style)
		columns.add_child(panel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		panel.add_child(col)
		col.add_child(_label(FactionData.name_of(f.id), 26, f.color))
		var level_label := _label("", 20)
		col.add_child(level_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 14)
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = f.color
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)
		var back := StyleBoxFlat.new()
		back.bg_color = Color(1, 1, 1, 0.08)
		back.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", back)
		col.add_child(bar)
		var points := _label("", 14, Color(1, 1, 1, 0.7))
		col.add_child(points)
		col.add_child(HSeparator.new())
		var rows: Array[Dictionary] = []
		var faction_unlocks: Dictionary = unlocks.get(f.id, {})
		for level in range(1, Config.REP_LEVELS.size() + 1):
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 8)
			var mark := _label("·", 16)
			mark.custom_minimum_size = Vector2(20, 0)
			line.add_child(mark)
			var names: Array = faction_unlocks.get(level, [])
			var text := _label("Niv. %d (%d pts) : %s" % [level, Config.REP_LEVELS[level - 1], ", ".join(names) if not names.is_empty() else "—"], 14)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.custom_minimum_size = Vector2(200, 0)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.add_child(text)
			col.add_child(line)
			rows.append({"level": level, "label": line, "mark": mark})
		_progress_columns.append({"faction": f.id, "level": level_label, "bar": bar, "points": points, "rows": rows})
	return scroll


## faction -> niveau -> noms des objets débloqués (armes, kits, capacités, mods).
func _unlock_table() -> Dictionary:
	var table := {}
	var entries: Array = []  # [faction, niveau, texte]
	for e in _catalog:
		entries.append([e["faction"], e["level"], ("kit " if e["cat"] == Cat.KIT else "") + String(e["name"])])
		if e["cat"] == Cat.KIT:
			for m: Dictionary in (e["kit"] as KitData).mods:
				entries.append([e["faction"], int(m.get("unlock_level", 0)), "mod " + String(e["name"])])
	for m in WeaponModData.all():
		entries.append([m.faction, m.faction_level, "mod d'arme " + m.display_name])
	for e: Array in entries:
		var faction: int = e[0]
		var level: int = e[1]
		if faction <= 0 or level <= 0:
			continue
		if not table.has(faction):
			table[faction] = {}
		if not table[faction].has(level):
			table[faction][level] = []
		table[faction][level].append(e[2])
	return table


# --- Escouade ---

func _build_squad() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_label("PROSPECTEURS", 16, DIM))
	_players_box = VBoxContainer.new()
	box.add_child(_players_box)
	box.add_child(HSeparator.new())
	box.add_child(_label("ESCOUADES (jusqu'à %d) — larguées ensemble, pas de tirs entre coéquipiers" % Config.SQUAD_MAX, 16, DIM))
	_squads_box = VBoxContainer.new()
	_squads_box.add_theme_constant_override("separation", 8)
	box.add_child(_squads_box)
	return box


# =========================================================================
# Petits outils
# =========================================================================

func _panel(min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	return panel


func _box_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := UiStyle.chamfer_box(bg, border, width, 6)
	s.content_margin_left = 12
	s.content_margin_right = 12
	return s


func _flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	return flow


func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	if size >= 20:
		label.add_theme_font_override("font", UiStyle.font("SemiBold"))
	label.add_theme_color_override("font_color", color)
	return label


func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


## Tri de la grille selon le filtre choisi (prix croissant, décroissant, nom).
func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	if _sort_opt.selected == 2 or a["price"] == b["price"]:
		return String(a["name"]) < String(b["name"])
	if _sort_opt.selected == 1:
		return int(a["price"]) > int(b["price"])
	return int(a["price"]) < int(b["price"])
