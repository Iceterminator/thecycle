class_name Score
extends Node
## Score d'un joueur :
## - FAME (variable rank_points, nom gardé pour la synchro de player.tscn) : le score général ;
## - points d'OBJECTIF par objectif (Forage, Relais…) : chaque palier donne de la Fame.
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
## Gain continu actuel par objectif (chemin du track -> points d'objectif / s), pour le HUD.
var objective_rates: Dictionary = {}:
	set(value):
		objective_rates = value
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
	_kit_xp(amount * Config.KIT_XP_PER_FAME)
	Events.rank_points_changed.emit(get_peer_id(), rank_points)


## Serveur : ajoute des points d'objectif ; chaque palier franchi donne des points de
## Fame (voir ObjectiveTrack) et prévient le joueur.
func add_objective_points(track: ObjectiveTrack, amount: int) -> void:
	if not multiplayer.is_server() or track == null or amount <= 0:
		return
	var key := track.resource_path
	var before: int = objective_points.get(key, 0)
	_kit_xp(amount * Config.KIT_XP_PER_OBJECTIVE_POINT)
	var after := before + amount
	var d := objective_points.duplicate()
	d[key] = after
	objective_points = d
	for tier in range(track.tiers_reached(before), track.tiers_reached(after)):
		var reward := track.reward(tier)
		add_rank_points(reward)
		notify.rpc_id(get_peer_id(), "%s : palier %d atteint (+%d Fame)" % [track.display_name, tier + 1, reward], track.color)


## Serveur : gain continu en cours pour un objectif (0 = aucun). Arrondi au dixième pour
## ne pas resynchroniser à chaque frame.
func set_objective_rate(track: ObjectiveTrack, rate: float) -> void:
	if track == null:
		return
	var key := track.resource_path
	var rounded := snappedf(rate, 0.1)
	if is_equal_approx(objective_rates.get(key, 0.0), rounded):
		return
	var d := objective_rates.duplicate()
	if rounded <= 0.0:
		d.erase(key)
	else:
		d[key] = rounded
	objective_rates = d


@rpc("authority", "call_local", "reliable")
func notify(text: String, color: Color) -> void:
	Events.announcement.emit(text, color)


## Serveur : active (texte non vide) ou retire une balise pour une raison donnée.
func set_beacon(reason: StringName, text: String) -> void:
	if text == "":
		_beacons.erase(reason)
	else:
		_beacons[reason] = text
	beacon = "  ".join(PackedStringArray(_beacons.values()))


## Serveur : nouvelle partie. Tout le score repart de zéro.
func server_reset() -> void:
	_beacons.clear()
	beacon = ""
	objective_rates = {}
	objective_points = {}
	rank_points = 0
	Events.rank_points_changed.emit(get_peer_id(), rank_points)


## Serveur : l'XP du kit vient aussi de la Fame et des points d'objectif gagnés.
func _kit_xp(amount: float) -> void:
	var kit := get_parent().get_node_or_null("Kit") as KitController
	if kit and amount > 0.0:
		kit.server_add_xp(roundi(amount))
