extends RefCounted
## Accès partagés de LobbyUi (fonctions statiques) : verrouillage par faction, recherche dans le
## catalogue, état « prêt » des boutons. LobbyUi garde les façades appelées par les onglets.


static func unlocked(ui: LobbyUi, faction: int, level: int) -> bool:
	return ProfileManager.is_unlocked(ui._me(), faction, level)


static func rep_key(ui: LobbyUi) -> String:
	var parts: PackedStringArray = []
	for f in FactionData.all():
		parts.append(str(ProfileManager.rep_points(ui._me(), f.id)))
	return ",".join(parts)


static func kit_data(catalog: Array[Dictionary], id: String) -> KitData:
	for e in catalog:
		if e["cat"] == LobbyUi.Cat.KIT and e["id"] == id:
			return e["kit"]
	return null


static func entry(catalog: Array[Dictionary], id: String) -> Dictionary:
	for e in catalog:
		if e["id"] == id:
			return e
	return {}


static func ready_count(ready_players: Dictionary) -> int:
	var n := 0
	for peer: int in ready_players:
		if ready_players[peer]:
			n += 1
	return n


## Bouton PRÊT (partie normale) ; `send` : prévient le serveur (MatchManager).
static func set_ready(ui: LobbyUi, on: bool, send: bool) -> void:
	_boutons(ui, on)
	if send:
		var match_manager := ui._world.get_node_or_null("MatchManager") as MatchManager
		if match_manager:
			match_manager.request_lobby_ready.rpc_id(1, on)


## Bouton SALLE DE TEST : tout le serveur part dans la salle de test (seulement au lobby).
static func salle_test(ui: LobbyUi) -> void:
	var niveaux := ui._world.get_node_or_null("Niveaux") as Niveaux
	if niveaux and MatchManager.is_lobby():
		niveaux.request_salle_test.rpc_id(1)


static func _boutons(ui: LobbyUi, on: bool) -> void:
	ui._launch.ready_button.set_pressed_no_signal(on)
	ui._launch.ready_button.text = "PRÊT ✔" if on else "PRÊT"


## Barre du haut et compte à rebours, chaque frame ; rafraîchit l'onglet toutes les 0,5 s.
static func update_clock(ui: LobbyUi, delta: float) -> void:
	var total: int = ui._player.get_parent().get_child_count()
	var ready := ready_count(ui._ready_players)
	ui._top.countdown.text = "PRÊTS  %d / %d" % [ready, total]
	ui._launch.update_clock(ready, total)
	ui._refresh_left -= delta
	if ui._refresh_left <= 0.0:
		ui._refresh_left = 0.5
		ui._refresh()


## Affiche l'onglet `page` (Page.*) et réinitialise les clés de rafraîchissement.
static func show_page(ui: LobbyUi, page: int) -> void:
	ui._page = page
	for i in ui._pages.size():
		ui._pages[i].visible = i == page
	ui._top.style_nav(page)
	if page == LobbyUi.Page.ARSENAL:
		ui._arsenal.rebuild_grid(ui)
	if page == LobbyUi.Page.LOADOUT and ui._loadout_page:
		ui._loadout_page.show_overview()
	ui._launch.key = ""
	ui._squad.key = ""
	ui._refresh()


## Lobby affiché au LOBBY, et pendant le BRIEFING pour ceux qui ne sont pas encore dans la salle
## (« prêt » = embarquer). Souris libre dans le lobby ; « prêt » remis à zéro en y revenant.
static func on_clock(ui: LobbyUi, phase: int) -> void:
	ui._phase = phase
	var in_room: bool = ui._ready_players.get(ui._me(), false)
	var lobby := phase == MatchManager.Phase.LOBBY or (phase == MatchManager.Phase.BRIEFING and not in_room)
	if lobby == ui.visible:
		return
	ui.visible = lobby
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if lobby else Input.MOUSE_MODE_CAPTURED
	if lobby:
		set_ready(ui, false, false)
		ui._show_page(LobbyUi.Page.LAUNCH)
