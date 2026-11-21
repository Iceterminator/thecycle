class_name SurgeCrystals
extends Node
## Serveur : surtension locale (Surge Crystals d'origine). `surge_lead` s avant le début d'une Grande Marée,
## annonce à tous puis `surge_count` cristaux sur des emplacements de quête libres (loin des joueurs si possible),
## pendant `surge_lifetime` s. Ramasser un cristal (E) donne `surge_points` points de l'objectif « surtension ».
## Les cristaux sont des objets au sol (Pickup, créés par le LootManager) ; ils sont retirés à la fin du délai.
## Créé par le QuestManager. Réglages : data/rules/match.tres, data/items/surge_crystal.tres.

const ITEM := &"surge_crystal"
const COLOR := Color(0.4, 0.95, 1.0)

var world: World
var spots_root: Node3D  ## QuestSpots
var quest_root: Node  ## quêtes déjà posées (emplacements pris)
var players_root: Node3D

var _last_elapsed: float = 0.0
var _generation: int = 0  ## nouvelle partie : un délai en cours est abandonné


func _ready() -> void:
	Events.match_reset_requested.connect(_reset)
	Events.carte_liberee.connect(_reset)


func _reset() -> void:
	_generation += 1
	_last_elapsed = 0.0


func _physics_process(_delta: float) -> void:
	if world == null or world.match_manager == null:
		return
	var elapsed := world.match_manager.elapsed
	var storm := world.get_node_or_null("StormManager") as StormManager
	if storm and is_instance_valid(spots_root):
		for phase in storm.phases:
			var start := phase.start_time - Config.match_rules.surge_lead
			if _last_elapsed < start and elapsed >= start and elapsed < phase.start_time:
				_start()
	_last_elapsed = elapsed


func _start() -> void:
	var rules := Config.match_rules
	var spots := QuestFreeSpots.pick(spots_root, quest_root, players_root, rules.surge_count, rules.surge_min_player_distance)
	if spots.is_empty():
		return
	Events.announce_requested.emit("Surtension détectée ! %d cristaux apparaissent : ramassez-les avant %d s" % [spots.size(), int(rules.surge_lifetime)], COLOR)
	for pos in spots:
		Events.loot_drop_requested.emit(ITEM, rules.surge_points, -1, pos, false)
	var generation := _generation
	await get_tree().create_timer(rules.surge_lifetime).timeout
	if generation == _generation:
		_remove_crystals()


## Les cristaux restés au sol disparaissent.
func _remove_crystals() -> void:
	var loot := world.get_node_or_null("Loot")
	if loot == null:
		return
	for node in loot.get_children():
		var pickup := node as Pickup
		if pickup and pickup.item and pickup.item.id == ITEM:
			pickup.queue_free()
