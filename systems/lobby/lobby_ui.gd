class_name LobbyUi
extends CanvasLayer
## Écran du lobby (étape 9, joueur local), affiché pendant la phase LOBBY du MatchManager.
## En haut : compte à rebours et bouton PRÊT. Quatre onglets :
## - Équipement : faction de prédilection, kit, mod de kit, arme de départ (secondaire),
##   mods d'arme — en cartes cliquables ;
## - Boutique : les 8 cases (4 armes, 4 gadgets / capacités) ; on clique une case puis un
##   objet du catalogue ;
## - Progression : réputation de chaque faction et ce que chaque niveau débloque ;
## - Escouade : joueurs, prêts, escouades (créer, rejoindre, quitter).
## Chaque changement est envoyé au serveur (ProfileManager.request_set_loadout), qui vérifie
## tout (verrous) ; les objets verrouillés sont grisés avec leur niveau requis.

const SEND_DELAY := 0.3

var _player: Player
var _world: Node
var _countdown: Label
var _ready_button: Button
var _status: Label
var _tabs: TabContainer

# --- État de l'équipement (envoyé au serveur) ---
var _preferred: int = 0
var _kit_id: String = String(Config.DEFAULT_KIT)
var _kit_mods: Dictionary = {}       # id de kit -> id de mod
var _weapon_mods: Dictionary = {}    # id d'arme -> id de mod
var _start_weapon: String = String(Config.BASE_WEAPON)
var _shop_weapons: Array = []
var _shop_gadgets: Array = []
var _send_left: float = -1.0

# --- Cartes ---
var _faction_cards: Array[Dictionary] = []   # { id, card }
var _kit_cards: Array[Dictionary] = []       # { kit, card }
var _kit_mod_row: HFlowContainer
var _start_cards: Array[Dictionary] = []     # { id, card }
var _weapon_mods_box: VBoxContainer
var _case_cards: Array[UiCard] = []          # 0-3 armes, 4-7 gadgets / capacités
var _catalog_cards: Array[Dictionary] = []   # { id, kind, card }
var _catalog_title: Label
var _selected_case: int = 0
var _progress_columns: Array[Dictionary] = [] # { faction, level, bar, points, rows: [{ level, label, mark }] }
var _players_box: VBoxContainer
var _squads_box: VBoxContainer

var _lobby_left: float = 0.0
var _ready_players: Dictionary = {}
var _refresh_left: float = 0.0
var _mods_key: String = ""
var _kit_mods_key: String = ""
var _squads_key: String = ""


func setup(player: Player) -> void:
	_player = player
	_world = player.get_parent().get_parent()
	layer = 9  # au-dessus du HUD et de la carte, sous la boutique et les menus (admin)
	visible = false
	var default_shop := ProfileManager.default_shop()
	_shop_weapons = _padded(default_shop["weapons"], Config.SHOP_WEAPON_SLOTS)
	_shop_gadgets = _padded(default_shop["gadgets"], Config.SHOP_GADGET_SLOTS)
	_build()
	Events.match_clock_synced.connect(_on_clock)
	Events.lobby_synced.connect(func(ready: Dictionary, left: float) -> void:
		_ready_players = ready
		_lobby_left = left)
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
		_ready_button.set_pressed_no_signal(false)
		_ready_button.text = "PRÊT"
		_refresh()


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
	_lobby_left = maxf(_lobby_left - delta, 0.0)
	var ready_count := 0
	for peer: int in _ready_players:
		if _ready_players[peer]:
			ready_count += 1
	_countdown.text = "LOBBY — départ dans %d s   ·   %d / %d prêts" % [ceili(_lobby_left), ready_count, _player.get_parent().get_child_count()]
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.5
		_refresh()


func _me() -> int:
	return _player.get_peer_id()


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
	_set_status("Équipement enregistré", Color(0.55, 1.0, 0.6))


func _set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func _lock_text(faction: int, level: int) -> String:
	return "" if ProfileManager.is_unlocked(_me(), faction, level) else "Verrouillé : " + FactionData.lock_text(faction, level)


func _rep_key() -> String:
	var parts: PackedStringArray = []
	for f in FactionData.all():
		parts.append(str(ProfileManager.rep_points(_me(), f.id)))
	return ",".join(parts)


# =========================================================================
# Mise à jour de l'affichage
# =========================================================================

func _refresh() -> void:
	if _countdown == null:
		return
	_refresh_equipment()
	_refresh_shop()
	_refresh_progress()
	_refresh_squads()


func _refresh_equipment() -> void:
	for e in _faction_cards:
		(e["card"] as UiCard).set_state(int(e["id"]) == _preferred, false)
	for e in _kit_cards:
		var k: KitData = e["kit"]
		var card: UiCard = e["card"]
		var lock := _lock_text(int(k.faction), k.faction_level)
		card.set_state(String(k.id) == _kit_id, lock != "")
		card.set_info(lock if lock != "" else ("Équipé" if String(k.id) == _kit_id else "Choisir"),
				Color(1, 0.5, 0.45) if lock != "" else Color(1, 0.85, 0.4))
	_rebuild_kit_mods()
	for e in _start_cards:
		var item := Items.get_item(StringName(e["id"]))
		var card: UiCard = e["card"]
		var lock := _lock_text(int(item.weapon.faction), item.weapon.faction_level)
		card.set_state(e["id"] == _start_weapon, lock != "")
		card.set_info(lock if lock != "" else ("Arme de départ" if e["id"] == _start_weapon else "Choisir"),
				Color(1, 0.5, 0.45) if lock != "" else Color(1, 0.85, 0.4))
	_rebuild_weapon_mods()


## Mods du kit choisi (cartes), refaits quand le kit, le mod ou la réputation changent.
func _rebuild_kit_mods() -> void:
	var kit := _kit_data(_kit_id)
	var current := String(_kit_mods.get(_kit_id, ""))
	var key := "%s|%s|%s" % [_kit_id, current, _rep_key()]
	if key == _kit_mods_key:
		return
	_kit_mods_key = key
	_clear(_kit_mod_row)
	var none := UiCard.make(Vector2(170, 76))
	none.set_content("Aucun mod", "", "", Color(0.6, 0.6, 0.6))
	none.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	none.set_state(current == "", false)
	none.pressed.connect(func() -> void:
		_kit_mods[_kit_id] = ""
		_changed())
	_kit_mod_row.add_child(none)
	if kit == null:
		return
	for m: Dictionary in kit.mods:
		var id := String(m["id"])
		var level := int(m.get("unlock_level", 0))
		var unlocked := KitController.mod_unlocked(_me(), kit, id)
		var card := UiCard.make(Vector2(250, 76))
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.set_content(String(m.get("effect", id)), "", "" if unlocked else "Verrouillé : " + FactionData.lock_text(int(kit.faction), level),
				FactionData.color_of(int(kit.faction)))
		card.set_info("" if unlocked else "Verrouillé : " + FactionData.lock_text(int(kit.faction), level), Color(1, 0.5, 0.45))
		card.tooltip_text = String(m.get("effect", id))
		card.set_state(id == current, not unlocked)
		card.disabled = not unlocked
		card.pressed.connect(func() -> void:
			_kit_mods[_kit_id] = id
			_changed())
		_kit_mod_row.add_child(card)


## Un mod par arme : l'arme de départ et les armes de la boutique.
func _rebuild_weapon_mods() -> void:
	var weapons: Array = [_start_weapon]
	for id: String in _shop_weapons:
		if id != "" and not id in weapons:
			weapons.append(id)
	var key := JSON.stringify([weapons, _weapon_mods, _rep_key()])
	if key == _mods_key:
		return
	_mods_key = key
	_clear(_weapon_mods_box)
	var mods := WeaponModData.all()
	for weapon_id: String in weapons:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := _label(Shop.entry_name(weapon_id), 16)
		name_label.custom_minimum_size = Vector2(260, 0)
		row.add_child(name_label)
		var opt := OptionButton.new()
		opt.custom_minimum_size = Vector2(420, 0)
		opt.add_item("Aucun mod")
		var current := String(_weapon_mods.get(weapon_id, ""))
		for i in mods.size():
			var m := mods[i]
			var lock := _lock_text(m.faction, m.faction_level)
			opt.add_item(m.display_name + ("   [%s]" % lock.trim_prefix("Verrouillé : ") if lock != "" else ""))
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
		row.add_child(opt)
		_weapon_mods_box.add_child(row)


func _refresh_shop() -> void:
	for i in _case_cards.size():
		var id: String = _shop_weapons[i] if i < Config.SHOP_WEAPON_SLOTS else _shop_gadgets[i - Config.SHOP_WEAPON_SLOTS]
		var card := _case_cards[i]
		var label := "Arme %d" % (i + 1) if i < Config.SHOP_WEAPON_SLOTS else "Gadget / capacité %d" % (i - Config.SHOP_WEAPON_SLOTS + 1)
		if id == "":
			card.set_content("— vide —", label, "Cliquer, puis choisir", Color(0.4, 0.4, 0.4))
			card.tooltip_text = ""
		else:
			card.set_content(Shop.entry_name(id), label, "%d cr." % Shop.entry_price(id), FactionData.color_of(Shop.entry_lock(id)[0]))
			card.tooltip_text = Shop.entry_description(id)
		card.set_state(i == _selected_case, false)
	var weapon_case := _selected_case < Config.SHOP_WEAPON_SLOTS
	_catalog_title.text = "CATALOGUE — %s (clic : mettre dans la case sélectionnée)" % ("armes" if weapon_case else "gadgets et capacités")
	var in_shop: Array = _shop_weapons + _shop_gadgets
	for e in _catalog_cards:
		var card: UiCard = e["card"]
		var kind: int = e["kind"]
		card.visible = (kind == Shop.Entry.WEAPON) == weapon_case
		if not card.visible:
			continue
		var lock := Shop.entry_lock(e["id"])
		var lock_text := _lock_text(lock[0], lock[1])
		card.set_state(e["id"] in in_shop, lock_text != "")
		if lock_text != "":
			card.set_info(lock_text, Color(1, 0.5, 0.45))
		else:
			card.set_info("%d cr.%s" % [Shop.entry_price(e["id"]), "   ✔ en boutique" if e["id"] in in_shop else ""])


func _put_in_case(id: String) -> void:
	var lock := Shop.entry_lock(id)
	if not ProfileManager.is_unlocked(_me(), lock[0], lock[1]):
		_set_status("%s : verrouillé (%s)" % [Shop.entry_name(id), FactionData.lock_text(lock[0], lock[1])], Color(1, 0.5, 0.45))
		return
	var weapon_case := _selected_case < Config.SHOP_WEAPON_SLOTS
	var list: Array = _shop_weapons if weapon_case else _shop_gadgets
	var index := _selected_case if weapon_case else _selected_case - Config.SHOP_WEAPON_SLOTS
	var already := list.find(id)
	if already >= 0:
		list[already] = list[index]  # déjà dans une autre case : on échange
	list[index] = id
	# Case suivante sélectionnée, pour remplir vite.
	var size := Config.SHOP_WEAPON_SLOTS if weapon_case else Config.SHOP_GADGET_SLOTS
	if index + 1 < size:
		_selected_case += 1
	_changed()


func _clear_case() -> void:
	if _selected_case < Config.SHOP_WEAPON_SLOTS:
		_shop_weapons[_selected_case] = ""
	else:
		_shop_gadgets[_selected_case - Config.SHOP_WEAPON_SLOTS] = ""
	_changed()


func _refresh_progress() -> void:
	for col in _progress_columns:
		var faction: int = col["faction"]
		var points := ProfileManager.rep_points(_me(), faction)
		var level := ProfileManager.rep_level_of_points(points)
		var maxed := level >= Config.REP_LEVELS.size()
		var previous: int = Config.REP_LEVELS[level - 1] if level > 0 else 0
		var next: int = previous if maxed else Config.REP_LEVELS[level]
		(col["level"] as Label).text = "Niveau %d" % level
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
		var label := _label("%s  %s%s" % ["✔" if _ready_players.get(id, false) else "○", ProfileManager.name_of(id),
				"   (escouade %d)" % squad if squad != 0 else ""], 18, Color(1, 0.9, 0.3) if id == _me() else Color.WHITE)
		_players_box.add_child(label)
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
				"Votre escouade" if squad == mine else ("Complète" if full else "Rejoindre"))
		card.set_state(squad == mine, full and squad != mine)
		card.disabled = squad == mine or full
		card.pressed.connect(func() -> void: manager.request_join.rpc_id(1, squad))
		_squads_box.add_child(card)
	var button := Button.new()
	button.custom_minimum_size = Vector2(260, 40)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if mine == 0:
		button.text = "Créer une escouade"
		button.pressed.connect(func() -> void: manager.request_create.rpc_id(1))
	else:
		button.text = "Quitter l'escouade"
		button.pressed.connect(func() -> void: manager.request_leave.rpc_id(1))
	_squads_box.add_child(button)


# =========================================================================
# Construction
# =========================================================================

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.06, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	root.add_child(header)
	_countdown = _label("", 26)
	_countdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_countdown)
	_status = _label("", 16)
	header.add_child(_status)
	_ready_button = Button.new()
	_ready_button.toggle_mode = true
	_ready_button.text = "PRÊT"
	_ready_button.custom_minimum_size = Vector2(200, 48)
	_ready_button.add_theme_font_size_override("font_size", 22)
	_ready_button.toggled.connect(func(on: bool) -> void:
		_ready_button.text = "PRÊT ✔" if on else "PRÊT"
		var match_manager := _world.get_node_or_null("MatchManager") as MatchManager
		if match_manager:
			match_manager.request_lobby_ready.rpc_id(1, on))
	header.add_child(_ready_button)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 18)
	root.add_child(_tabs)
	_build_equipment_tab()
	_build_shop_tab()
	_build_progress_tab()
	_build_squad_tab()


func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	scroll.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	return box


func _build_equipment_tab() -> void:
	var box := _tab("Équipement")
	box.add_child(_section("FACTION DE PRÉDILECTION — +%d %% de réputation avec elle" % roundi(Config.PREFERRED_FACTION_BONUS * 100.0)))
	var factions := _flow()
	box.add_child(factions)
	var none := UiCard.make(Vector2(200, 64))
	none.set_content("Aucune", "", "", Color(0.5, 0.5, 0.5))
	none.pressed.connect(func() -> void:
		_preferred = 0
		_changed())
	factions.add_child(none)
	_faction_cards.append({"id": 0, "card": none})
	for f in FactionData.all():
		var card := UiCard.make(Vector2(200, 64))
		card.set_content(FactionData.name_of(f.id), str(f.style), "", f.color)
		var fid := f.id
		card.pressed.connect(func() -> void:
			_preferred = fid
			_changed())
		factions.add_child(card)
		_faction_cards.append({"id": fid, "card": card})

	box.add_child(_section("KIT"))
	var kits := _flow()
	box.add_child(kits)
	for k in KitController.list_kits():
		var card := UiCard.make(Vector2(240, 104))
		var hp := k.health if k.health > 0.0 else Config.KIT_DEFAULT_HEALTH
		var sh := k.shield if k.shield > 0.0 else Config.KIT_DEFAULT_SHIELD
		var sp := k.move_speed_mps if k.move_speed_mps > 0.0 else Config.KIT_DEFAULT_SPEED
		card.set_content(KitController.kit_name(k), "PV %d · Bouclier %d · %.1f m/s" % [hp, sh, sp], "", FactionData.color_of(int(k.faction)))
		card.tooltip_text = k.playstyle
		var kid := String(k.id)
		var kf := int(k.faction)
		var kl := k.faction_level
		card.pressed.connect(func() -> void:
			if not ProfileManager.is_unlocked(_me(), kf, kl):
				_set_status("Kit verrouillé : " + FactionData.lock_text(kf, kl), Color(1, 0.5, 0.45))
				return
			_kit_id = kid
			_changed())
		kits.add_child(card)
		_kit_cards.append({"kit": k, "card": card})

	box.add_child(_section("MOD DU KIT (débloqué au niveau du kit +2, +4, +6, +8)"))
	_kit_mod_row = _flow()
	box.add_child(_kit_mod_row)

	box.add_child(_section("ARME DE DÉPART — une arme secondaire, jamais perdue"))
	var starts := _flow()
	box.add_child(starts)
	for item in _secondary_weapons():
		var card := UiCard.make(Vector2(240, 96))
		var w := item.weapon
		card.set_content(item.display_name, Shop.entry_description(String(item.id)), "", FactionData.color_of(int(w.faction)))
		var wid := String(item.id)
		card.pressed.connect(func() -> void:
			if not ProfileManager.is_unlocked(_me(), int(w.faction), w.faction_level):
				_set_status("Arme verrouillée : " + FactionData.lock_text(int(w.faction), w.faction_level), Color(1, 0.5, 0.45))
				return
			_start_weapon = wid
			_changed())
		starts.add_child(card)
		_start_cards.append({"id": wid, "card": card})

	box.add_child(_section("MODS D'ARME — un par arme (arme de départ et armes de la boutique)"))
	_weapon_mods_box = VBoxContainer.new()
	box.add_child(_weapon_mods_box)


func _build_shop_tab() -> void:
	var box := _tab("Boutique")
	box.add_child(_section("VOTRE BOUTIQUE EN PARTIE — 4 armes et 4 gadgets / capacités, répartis comme vous voulez. Cliquez une case, puis un objet du catalogue."))
	for row_index in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var count := Config.SHOP_WEAPON_SLOTS if row_index == 0 else Config.SHOP_GADGET_SLOTS
		for i in count:
			var case_index := i if row_index == 0 else Config.SHOP_WEAPON_SLOTS + i
			var card := UiCard.make(Vector2(220, 84))
			card.pressed.connect(func() -> void:
				_selected_case = case_index
				_refresh_shop())
			row.add_child(card)
			_case_cards.append(card)
	var clear := Button.new()
	clear.text = "Vider la case sélectionnée"
	clear.custom_minimum_size = Vector2(260, 34)
	clear.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	clear.pressed.connect(_clear_case)
	box.add_child(clear)
	box.add_child(HSeparator.new())
	_catalog_title = _section("")
	box.add_child(_catalog_title)
	var grid := _flow()
	box.add_child(grid)
	var entries: Array[Dictionary] = []
	for item in Items.get_items_of_kind(ItemData.Kind.WEAPON):
		if item.weapon:
			entries.append({"id": String(item.id), "kind": Shop.entry_kind(String(item.id))})
	for a in AbilityController.list_abilities():
		entries.append({"id": String(a.id), "kind": Shop.Entry.ABILITY})
	entries.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var lx := Shop.entry_lock(x["id"])
		var ly := Shop.entry_lock(y["id"])
		if lx[0] != ly[0]:
			return lx[0] < ly[0]
		if lx[1] != ly[1]:
			return lx[1] < ly[1]
		return Shop.entry_name(x["id"]) < Shop.entry_name(y["id"]))
	for e in entries:
		var id: String = e["id"]
		var kind: int = e["kind"]
		var card := UiCard.make(Vector2(230, 92))
		var sub := "Gadget" if kind == Shop.Entry.GADGET else ("Capacité" if kind == Shop.Entry.ABILITY else Shop.entry_description(id))
		card.set_content(Shop.entry_name(id), sub, "", FactionData.color_of(Shop.entry_lock(id)[0]))
		card.tooltip_text = Shop.entry_description(id)
		card.pressed.connect(func() -> void: _put_in_case(id))
		grid.add_child(card)
		_catalog_cards.append({"id": id, "kind": kind, "card": card})


func _build_progress_tab() -> void:
	var box := _tab("Progression")
	box.add_child(_section("RÉPUTATION — gagnée avec les contrats de chaque faction ; chaque niveau débloque des objets"))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	box.add_child(columns)
	var unlocks := _unlock_table()
	for f in FactionData.all():
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.09, 0.11, 0.95)
		style.border_color = f.color
		style.border_width_top = 4
		style.set_corner_radius_all(6)
		style.set_content_margin_all(14)
		panel.add_theme_stylebox_override("panel", style)
		columns.add_child(panel)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		panel.add_child(col)
		col.add_child(_label(FactionData.name_of(f.id), 24, f.color))
		var level_label := _label("", 20)
		col.add_child(level_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 16)
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
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var mark := _label("·", 16)
			mark.custom_minimum_size = Vector2(20, 0)
			row.add_child(mark)
			var names: Array = faction_unlocks.get(level, [])
			var text := _label("Niv. %d (%d pts) : %s" % [level, Config.REP_LEVELS[level - 1], ", ".join(names) if not names.is_empty() else "—"], 14)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.custom_minimum_size = Vector2(200, 0)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(text)
			col.add_child(row)
			rows.append({"level": level, "label": row, "mark": mark})
		_progress_columns.append({"faction": f.id, "level": level_label, "bar": bar, "points": points, "rows": rows})


## faction -> niveau -> noms des objets débloqués (armes, kits, capacités, mods).
func _unlock_table() -> Dictionary:
	var table := {}
	var entries: Array = []  # [faction, niveau, texte]
	for item in Items.get_items_of_kind(ItemData.Kind.WEAPON):
		if item.weapon:
			entries.append([int(item.weapon.faction), item.weapon.faction_level, item.display_name])
	for k in KitController.list_kits():
		entries.append([int(k.faction), k.faction_level, "kit " + KitController.kit_name(k)])
		for m: Dictionary in k.mods:
			entries.append([int(k.faction), int(m.get("unlock_level", 0)), "mod " + KitController.kit_name(k)])
	for a in AbilityController.list_abilities():
		entries.append([int(a.faction), a.faction_level, a.get_display_name()])
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


func _build_squad_tab() -> void:
	var box := _tab("Escouade")
	box.add_child(_section("JOUEURS"))
	_players_box = VBoxContainer.new()
	box.add_child(_players_box)
	box.add_child(HSeparator.new())
	box.add_child(_section("ESCOUADES (jusqu'à %d) — larguées ensemble, pas de tirs entre coéquipiers" % Config.SQUAD_MAX))
	_squads_box = VBoxContainer.new()
	_squads_box.add_theme_constant_override("separation", 8)
	box.add_child(_squads_box)


# =========================================================================
# Petits outils
# =========================================================================

func _secondary_weapons() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for item in Items.get_items_of_kind(ItemData.Kind.WEAPON):
		if item.weapon and item.weapon.slot == WeaponData.Slot.SECONDARY and item.weapon.gadget == WeaponData.GadgetKind.NONE:
			out.append(item)
	out.sort_custom(func(a: ItemData, b: ItemData) -> bool: return int(a.weapon.faction) < int(b.weapon.faction))
	return out


func _kit_data(id: String) -> KitData:
	for e in _kit_cards:
		if String((e["kit"] as KitData).id) == id:
			return e["kit"]
	return null


func _section(text: String) -> Label:
	var label := _label(text, 16, Color(1, 1, 1, 0.6))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	return flow


func _label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _clear(box: Container) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
