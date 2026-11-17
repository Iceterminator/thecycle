extends Node
## Serveur uniquement : fait réapparaître les joueurs morts après Config.RESPAWN_DELAY.
## On garde le même nœud joueur : on le téléporte puis on le remet sur pied.

## Délai entre la téléportation et la remise sur pied : laisse à la nouvelle
## position le temps d'arriver chez les autres, pour que le corps n'apparaisse
## pas une frame à l'endroit de la mort.
const REVIVE_AFTER_TELEPORT := 0.15

@onready var world: World = get_parent()


func _ready() -> void:
	if not multiplayer.is_server():
		return
	Events.player_died.connect(_on_player_died)


func _on_player_died(victim_id: int, _killer_id: int) -> void:
	await get_tree().create_timer(Config.RESPAWN_DELAY).timeout
	var player := world.get_player(victim_id)
	if player == null or not player.health.is_dead:
		return
	var pos := world.pick_spawn_point()
	# Le déplacement est décidé par le client : c'est lui qui se téléporte.
	# On met aussi à jour la copie du serveur pour les raycasts.
	player.global_position = pos
	player.teleport.rpc_id(victim_id, pos)
	await get_tree().create_timer(REVIVE_AFTER_TELEPORT).timeout
	if not is_instance_valid(player):
		return
	player.health.revive()
	player.weapon.server_refill()
	print("[Combat] Joueur %d réapparu en %s" % [victim_id, pos])
