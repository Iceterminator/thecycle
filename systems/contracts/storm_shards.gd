class_name StormShards
extends Node
## Serveur : éclats d'orage portés (Zeal Shard d'origine). Créé par le QuestManager.
## - Début de la Grande Marée : des éclats tombent au hasard sur la carte (certains rouges).
## - Un éclat ramassé (E) rapporte des points d'objectif par seconde tant qu'on le porte ;
##   un seul à la fois (voir carried_item, utilisé par InventoryPickup).
## - Le moindre dégât reçu le fait tomber au sol ; la mort aussi (InventoryDeath).
## - Éclat rouge : Fame en plus si on embarque dans l'évac avec lui.
## Valeurs (points/s, chance de rouge, Fame) : data/items/storm_shard*.tres.

const SHARD := &"storm_shard"
const COLOR := Color(0.88, 0.36, 1.0)

var players_root: Node3D
var _points_acc: Dictionary = {}  # peer_id -> fraction de point en attente


func _ready() -> void:
	Events.storm_started.connect(_on_storm_started)
	Events.player_damaged.connect(_on_player_damaged)
	Events.player_evacuated.connect(_on_player_evacuated)


## Objet porté qui rapporte des points (éclat), ou null.
static func carried_item(inventory: Inventory) -> ItemData:
	for res_id: String in inventory.carried:
		var item := Items.get_item(StringName(res_id))
		if item and item.carry_points_per_second > 0.0:
			return item
	return null


func _physics_process(delta: float) -> void:
	var track := Items.get_item(SHARD).carry_track
	for node in players_root.get_children():
		var player := node as Player
		if player == null:
			continue
		var item := carried_item(player.inventory) if player.can_be_hit() else null
		if item == null:
			player.score.set_objective_rate(track, 0.0)
			continue
		var peer := player.get_peer_id()
		var acc: float = _points_acc.get(peer, 0.0) + item.carry_points_per_second * delta
		var whole := int(acc)
		_points_acc[peer] = acc - whole
		player.score.set_objective_rate(item.carry_track, item.carry_points_per_second)
		if whole > 0:
			player.score.add_objective_points(item.carry_track, whole)


## Début de la Grande Marée : `count` éclats au hasard sur la carte, chacun rouge avec red_chance.
func _on_storm_started(count: int) -> void:
	var base := Items.get_item(SHARD)
	var half := Config.MAP_HALF_SIZE - 10.0
	for i in count:
		var item := base.red_variant if base.red_variant and randf() < base.red_chance else base
		var pos := Vector3(randf_range(-half, half), 0.0, randf_range(-half, half))
		pos.y = MapTerrain.height_at(pos.x, pos.z)
		Events.loot_drop_requested.emit(item.id, 1, -1, pos, false)
	Events.announce_requested.emit("%d × %s tombés sur la carte ! Ramassez-en un : il rapporte des points tant que vous le portez" % [count, base.display_name], COLOR)


## Dégât reçu (joueur ou monstre) : l'éclat tombe aux pieds du porteur.
func _on_player_damaged(peer_id: int, amount: float, _attacker_id: int) -> void:
	var player := players_root.get_node_or_null(str(peer_id)) as Player
	var item := carried_item(player.inventory) if player and amount > 0.0 else null
	if item == null:
		return
	player.inventory.take_resource(item.id)
	Events.loot_drop_requested.emit(item.id, 1, -1, player.global_position, false)
	player.score.notify.rpc_id(peer_id, "%s lâché : vous avez été touché !" % item.display_name, item.color)


func _on_player_evacuated(peer_id: int) -> void:
	var player := players_root.get_node_or_null(str(peer_id)) as Player
	var item := carried_item(player.inventory) if player else null
	if item == null or item.red_evac_fame <= 0:
		return
	player.score.add_contract_fame(item.red_evac_fame, item.carry_track.faction, true, ContractBoard.is_active(peer_id, item.carry_track))
	Events.announce_requested.emit("%s a embarqué avec un %s ! (+%d Fame)" % [ContractSite.player_name(peer_id), item.display_name.to_lower(), item.red_evac_fame], item.color)
