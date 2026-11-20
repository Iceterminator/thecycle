class_name BriefingRoom
extends Node3D
## Salle de briefing (phase BRIEFING du MatchManager) : vaisseau en orbite basse au nord de la
## carte, baie vitrée tournée vers elle. Au centre, l'hologramme de la carte (BriefingHologram) ;
## sur le mur de gauche, le tableau des quêtes de la partie (BriefingBoard). Les joueurs prêts y
## sont téléportés ; touche E : voter / annuler le vote « départ immédiat ».
## Construite en local sur tous les peers par World (décor : rien ne passe par le réseau).

const BuildRoom := preload("res://systems/briefing/briefing_room_build.gd")
const ORIGIN := Vector3(0, 48, -182)  ## centre du sol (hors des murs de la carte, au nord)
const SIZE := Vector3(26, 7, 18)      ## intérieur : largeur (x), hauteur, profondeur (z)
const SPAWN_COLUMNS := 7

var _world: World


## Point d'arrivée du n-ième joueur entré, au fond de la salle (face à la baie vitrée).
static func spawn_point(index: int) -> Vector3:
	var col := index % SPAWN_COLUMNS
	var row := floori(float(index) / SPAWN_COLUMNS) % 3
	return ORIGIN + Vector3(-9.0 + col * 3.0, 1.0, -6.5 + row * 1.8)


func _ready() -> void:
	_world = get_parent() as World
	position = ORIGIN
	BuildRoom.build(self, SIZE)
	if DisplayServer.get_name() == "headless":
		return
	var holo := BriefingHologram.new()
	holo.name = "Hologramme"
	holo.position = Vector3(0, 0, 0.5)
	add_child(holo)
	var board := BriefingBoard.new()
	board.name = "Tableau"
	board.world = _world
	board.position = Vector3(-SIZE.x / 2.0 + 0.1, 3.2, -1.0)
	board.rotation.y = PI / 2.0
	add_child(board)


## Vote du joueur local (seulement s'il est dans la salle).
func _unhandled_input(event: InputEvent) -> void:
	if not MatchManager.is_briefing() or not event.is_action_pressed("interact") or _world == null:
		return
	var manager := _world.match_manager
	var me := multiplayer.get_unique_id()
	if manager and me in manager.briefing_room:
		manager.request_briefing_vote.rpc_id(1, not me in manager.briefing_votes)
		get_viewport().set_input_as_handled()
