extends RefCounted
## Onglet Escouade du lobby : joueurs présents, escouades existantes, créer / rejoindre / quitter.

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const GOLD := UiStyle.GOLD
const DIM := UiStyle.DIM

var players_box: VBoxContainer
var squads_box: VBoxContainer
var key: String = ""


func build() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(W.label("PROSPECTEURS", 16, DIM))
	players_box = VBoxContainer.new()
	box.add_child(players_box)
	box.add_child(HSeparator.new())
	box.add_child(W.label("ESCOUADES (jusqu'à %d) — larguées ensemble, pas de tirs entre coéquipiers" % Config.SQUAD_MAX, 16, DIM))
	squads_box = VBoxContainer.new()
	squads_box.add_theme_constant_override("separation", 8)
	box.add_child(squads_box)
	return box


func refresh(lobby: LobbyUi) -> void:
	# Refait seulement si quelque chose a changé (sinon un clic en cours serait perdu).
	var player_names: PackedStringArray = []
	for node in lobby._player.get_parent().get_children():
		if node is Player:
			player_names.append(ProfileManager.name_of((node as Player).get_peer_id()))
	var new_key := JSON.stringify([player_names, lobby._ready_players, SquadManager.all_squads()])
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
		players_box.add_child(W.label("%s  %s%s" % ["✔" if lobby._ready_players.get(id, false) else "○", ProfileManager.name_of(id),
				"   (escouade %d)" % squad if squad != 0 else ""], 18, GOLD if id == lobby._me() else Color.WHITE))
	W.clear(squads_box)
	var manager := lobby._world.get_node_or_null("SquadManager") as SquadManager
	if manager == null:
		return
	var mine := SquadManager.squad_of(lobby._me())
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
		squads_box.add_child(card)
	if mine == 0:
		squads_box.add_child(W.action("Créer une escouade", true, func() -> void: manager.request_create.rpc_id(1)))
	else:
		squads_box.add_child(W.action("Quitter l'escouade", true, func() -> void: manager.request_leave.rpc_id(1)))
