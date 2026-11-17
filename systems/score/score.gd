class_name Score
extends Node
## Score d'un joueur : points de quête (plus tard : Fame, classement — étape 5).
## SEUL LE SERVEUR le modifie ; ScoreSync (autorité 1, voir player.gd::_enter_tree)
## l'envoie à tous les clients (pour le futur classement en direct).

signal changed

var quest_points: int = 0:
	set(value):
		quest_points = value
		changed.emit()


func get_peer_id() -> int:
	return get_parent().name.to_int()


## Serveur uniquement.
func add_quest_points(amount: int) -> void:
	if not multiplayer.is_server() or amount == 0:
		return
	quest_points += amount
	Events.quest_points_changed.emit(get_peer_id(), quest_points)
