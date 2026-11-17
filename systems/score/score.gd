class_name Score
extends Node
## Score d'un joueur : points de quête (plus tard : Fame, classement — étape 5).
## SEUL LE SERVEUR le modifie ; ScoreSync (autorité 1, voir player.gd::_enter_tree)
## l'envoie à tous les clients.
## `beacon` : texte affiché au-dessus du joueur pour TOUS les autres, à travers le décor
## (porteur du Cœur stellaire, prime sur la tête…).

signal changed

var quest_points: int = 0:
	set(value):
		quest_points = value
		changed.emit()
var beacon: String = "":
	set(value):
		beacon = value
		changed.emit()

var _beacons: Dictionary = {}  # serveur : raison -> texte


func get_peer_id() -> int:
	return get_parent().name.to_int()


## Serveur uniquement.
func add_quest_points(amount: int) -> void:
	if not multiplayer.is_server() or amount == 0:
		return
	quest_points += amount
	Events.quest_points_changed.emit(get_peer_id(), quest_points)


## Serveur : active (texte non vide) ou retire une balise pour une raison donnée.
func set_beacon(reason: StringName, text: String) -> void:
	if text == "":
		_beacons.erase(reason)
	else:
		_beacons[reason] = text
	beacon = "  ".join(PackedStringArray(_beacons.values()))
