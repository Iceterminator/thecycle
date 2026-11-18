class_name FameManager
extends Node
## Règles de Fame qui ne dépendent d'aucun contrat (serveur) :
## - tuer un joueur rapporte Config.PLAYER_KILL_FAME au tueur ;
## - mourir ne fait rien perdre ; les monstres ne donnent pas de Fame.
## Créé en code par World.

@onready var world: World = get_parent()


func _ready() -> void:
	if multiplayer.is_server():
		Events.player_died.connect(_on_player_died)


func _on_player_died(victim_id: int, killer_id: int) -> void:
	if killer_id <= 0 or killer_id == victim_id:
		return  # monstre, tempête ou suicide
	var killer := world.get_player(killer_id)
	if killer == null:
		return
	killer.score.add_rank_points(Config.PLAYER_KILL_FAME)
	killer.score.notify.rpc_id(killer_id, "%s éliminé : +%d Fame" % [ProfileManager.name_of(victim_id), Config.PLAYER_KILL_FAME], Color(1.0, 0.85, 0.3))
