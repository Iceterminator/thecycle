class_name Score
extends Node
## Score d'un joueur :
## - points de CLASSEMENT (rank_points) : le score général ;
## - points d'OBJECTIF par objectif (Forage, Relais…) : chaque palier donne du classement.
## SEUL LE SERVEUR le modifie ; ScoreSync (autorité 1, voir player.gd::_enter_tree)
## l'envoie à tous les clients.
## `beacon` : texte affiché au-dessus du joueur pour TOUS les autres, à travers le décor
## (porteur du Cœur stellaire, prime sur la tête…).

signal changed

var rank_points: int = 0:
	set(value):
		rank_points = value
		changed.emit()
## Points d'objectif par objectif : chemin du ObjectiveTrack (.tres) -> points cumulés.
## Toujours réassigner le dictionnaire entier pour la synchro.
var objective_points: Dictionary = {}:
	set(value):
		objective_points = value
		changed.emit()
var beacon: String = "":
	set(value):
		beacon = value
		changed.emit()

var _beacons: Dictionary = {}  # serveur : raison -> texte


func get_peer_id() -> int:
	return get_parent().name.to_int()


## Serveur uniquement.
func add_rank_points(amount: int) -> void:
	if not multiplayer.is_server() or amount == 0:
		return
	rank_points += amount
	Events.rank_points_changed.emit(get_peer_id(), rank_points)


## Serveur : ajoute des points d'objectif ; chaque palier franchi donne des points de
## classement (voir ObjectiveTrack) et prévient le joueur.
func add_objective_points(track: ObjectiveTrack, amount: int) -> void:
	if not multiplayer.is_server() or track == null or amount <= 0:
		return
	var key := track.resource_path
	var before: int = objective_points.get(key, 0)
	var after := before + amount
	var d := objective_points.duplicate()
	d[key] = after
	objective_points = d
	for tier in range(track.tiers_reached(before), track.tiers_reached(after)):
		var reward := track.reward(tier)
		add_rank_points(reward)
		_notify_tier.rpc_id(get_peer_id(), "%s : palier %d atteint (+%d pts de classement)" % [track.display_name, tier + 1, reward], track.color)


@rpc("authority", "call_local", "reliable")
func _notify_tier(text: String, color: Color) -> void:
	Events.announcement.emit(text, color)


## Serveur : active (texte non vide) ou retire une balise pour une raison donnée.
func set_beacon(reason: StringName, text: String) -> void:
	if text == "":
		_beacons.erase(reason)
	else:
		_beacons[reason] = text
	beacon = "  ".join(PackedStringArray(_beacons.values()))
