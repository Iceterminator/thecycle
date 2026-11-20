extends RefCounted
## Onglet Décollage du lobby : horloge, joueurs prêts, résumé de l'équipement.

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const ACCENT := UiStyle.ACCENT
const GOLD := UiStyle.GOLD
const DIM := UiStyle.DIM

var clock: Label
var ready_label: Label
var players_box: VBoxContainer
var summary_box: VBoxContainer
var ready_button: Button
var key: String = ""


func build(lobby: LobbyUi) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	left.add_child(W.label("DÉCOLLAGE", 18, DIM))
	clock = W.label("00:00", 72)
	left.add_child(clock)
	ready_label = W.label("", 20, ACCENT)
	left.add_child(ready_label)
	ready_button = W.ready_toggle(Vector2(320, 64), 28, func(on: bool) -> void: lobby._set_ready(on, true))
	ready_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(ready_button)
	left.add_child(W.label("PRÊT : vous embarquez dans la salle de briefing. La partie part %d s après le premier prêt, ou plus tôt au vote." % roundi(Config.match_rules.briefing_time), 14, DIM))
	left.add_child(HSeparator.new())
	left.add_child(W.label("PROSPECTEURS", 16, DIM))
	players_box = VBoxContainer.new()
	left.add_child(players_box)
	var right := W.panel(Vector2(560, 0))
	row.add_child(right)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	right.add_child(box)
	box.add_child(W.label("VOTRE ÉQUIPEMENT", 18, ACCENT))
	summary_box = VBoxContainer.new()
	summary_box.add_theme_constant_override("separation", 4)
	box.add_child(summary_box)
	box.add_child(W.action("Modifier l'équipement →", true, func() -> void: lobby._show_page(LobbyUi.Page.LOADOUT)))
	return row


## Texte du compte à rebours (appelé à chaque frame par le lobby).
func update_clock(ready: int, total: int) -> void:
	clock.text = "%d / %d" % [ready, total]
	ready_label.text = "Tout le monde est prêt : départ !" if ready >= total else "En attente de %d joueur%s" % [total - ready, "s" if total - ready > 1 else ""]


func refresh(lobby: LobbyUi) -> void:
	var names: PackedStringArray = []
	for node in lobby._player.get_parent().get_children():
		var p := node as Player
		if p:
			names.append("%d:%s:%s:%d" % [p.get_peer_id(), ProfileManager.name_of(p.get_peer_id()), lobby._ready_players.get(p.get_peer_id(), false), SquadManager.squad_of(p.get_peer_id())])
	var new_key := JSON.stringify([names, lobby._kit_id, lobby._start_weapon, lobby._shop_weapons, lobby._shop_gadgets, lobby._preferred])
	if new_key == key:
		return
	key = new_key
	W.clear(players_box)
	for node in lobby._player.get_parent().get_children():
		var p := node as Player
		if p == null:
			continue
		var id := p.get_peer_id()
		var squad := SquadManager.squad_of(id)
		var ready: bool = lobby._ready_players.get(id, false)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(W.label("✔" if ready else "○", 20, ACCENT if ready else DIM))
		row.add_child(W.label(ProfileManager.name_of(id), 20, GOLD if id == lobby._me() else Color.WHITE))
		if squad != 0:
			row.add_child(W.label("escouade %d" % squad, 15, DIM))
		players_box.add_child(row)
	W.clear(summary_box)
	var kit := lobby._kit_data(lobby._kit_id)
	summary_box.add_child(W.label("KIT", 14, DIM))
	summary_box.add_child(W.label(KitController.kit_name(kit) if kit else lobby._kit_id, 22))
	summary_box.add_child(W.label("ARME DE DÉPART", 14, DIM))
	summary_box.add_child(_summary_weapon(lobby._start_weapon))
	summary_box.add_child(W.label("BOUTIQUE EN PARTIE", 14, DIM))
	for id: String in lobby._shop_weapons + lobby._shop_gadgets:
		if id != "":
			summary_box.add_child(_summary_weapon(id))
	summary_box.add_child(W.label("FACTION DE PRÉDILECTION : %s" % (FactionData.name_of(lobby._preferred) if lobby._preferred > 0 else "aucune"), 14, DIM))


func _summary_weapon(id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var visual := ItemVisual.make(id)
	if visual:
		visual.custom_minimum_size = Vector2(64, 26)
		row.add_child(visual)
	row.add_child(W.label(Shop.entry_name(id), 17))
	return row
