extends RefCounted
## Fenêtre « mode de jeu » ouverte par PRÊT au lobby : partie normale (salle de briefing puis
## largage) ou salle de test (armes, capacités, monstres figés, galerie ; tout le serveur y va).

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")


## `partie` : prêt pour une partie normale ; `salle_test` : demande la salle de test au serveur.
static func ouvrir(ui: LobbyUi, partie: Callable, salle_test: Callable) -> void:
	if ui.has_node("ModeDeJeu"):
		return
	var fond := ColorRect.new()
	fond.name = "ModeDeJeu"
	fond.color = Color(0, 0, 0, 0.6)
	fond.theme = UiStyle.theme()
	ui.add_child(fond)
	fond.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	fond.add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panneau := W.panel(Vector2(520, 0))
	centre.add_child(panneau)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panneau.add_child(box)
	box.add_child(W.label("MODE DE JEU", 26, UiStyle.ACCENT))
	var fermer := func(suite: Callable) -> void:
		fond.queue_free()
		suite.call()
	box.add_child(W.big_button("PARTIE NORMALE", true, fermer.bind(partie)))
	box.add_child(W.label("Salle de briefing, puis largage sur la carte.", 15, UiStyle.DIM))
	box.add_child(W.big_button("SALLE DE TEST", false, fermer.bind(salle_test)))
	box.add_child(W.label("Toutes les armes, gadgets et capacités au sol, monstres figés, galerie des textures et du décor. Tout le serveur y part.", 15, UiStyle.DIM))
	box.add_child(W.action("Annuler", true, fermer.bind(func() -> void: pass)))
