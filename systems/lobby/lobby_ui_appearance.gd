extends RefCounted
## Choix de l'apparence du personnage (onglet Factions du lobby) : Automatique + data/appearances/.
## Le choix part avec l'équipement (LobbyUi._appearance -> request_set_loadout), vérifié par le serveur.

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const COLOR := Color(0.75, 0.85, 1.0)

var cards: Array[Dictionary] = []   # { id, card }


func build(lobby: LobbyUi) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(W.label("APPARENCE — visible par les autres joueurs et sur vos bras", 16, UiStyle.DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_add_card(lobby, row, "", "Automatique")
	for a in AppearanceData.all():
		_add_card(lobby, row, AppearanceData.id_of(a), a.display_name)
	return box


func _add_card(lobby: LobbyUi, row: HBoxContainer, id: String, title: String) -> void:
	var card := UiCard.make(Vector2(180, 60))
	card.set_content(title, "", "", COLOR)
	card.pressed.connect(func() -> void:
		lobby._appearance = id
		lobby._changed())
	row.add_child(card)
	cards.append({"id": id, "card": card})


func refresh(lobby: LobbyUi) -> void:
	for e in cards:
		(e["card"] as UiCard).set_state(String(e["id"]) == lobby._appearance, false)
