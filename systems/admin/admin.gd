class_name Admin
extends Node
## Menu admin du joueur (touche 0), pour les tests : faire apparaître devant soi des
## armes, des crédits, des cristaux de quête, et avancer le temps de partie.
## Client propriétaire : affiche l'interface (AdminUi) et DEMANDE.
## Serveur : vérifie (menu autorisé dans Config, propriétaire, vivant, données valides),
## puis passe par le bus Events (LootManager pour les objets, QuestManager pour les cristaux).
## Kits : équipés tout de suite (request_set_kit).

signal admin_result(ok: bool, message: String)

const ADMIN_UI_SCRIPT := preload("res://systems/admin/admin_ui.gd")
const QUESTS_DIR := "res://data/quests/"

@onready var player: Player = get_parent()

var ui: AdminUi
var fly := AdminFly.new()  # vol rapide, local au joueur propriétaire


func _ready() -> void:
	if player.is_multiplayer_authority() and Config.ADMIN_MENU_ENABLED:
		ui = ADMIN_UI_SCRIPT.new()
		add_child(ui)
		ui.setup(player, self)


## Les CrystalData disponibles (un par difficulté), triés par niveau.
static func get_crystal_datas() -> Array[CrystalData]:
	var result: Array[CrystalData] = []
	for file in ResourceLoader.list_directory(QUESTS_DIR):
		if file.ends_with(".tres"):
			var crystal := load(QUESTS_DIR + file) as CrystalData
			if crystal:
				result.append(crystal)
	result.sort_custom(func(a: CrystalData, b: CrystalData) -> bool: return a.level < b.level)
	return result


# =========================================================================
# Serveur
# =========================================================================

## Une arme (amount ignoré) ou des crédits (amount = montant), au sol devant le joueur.
@rpc("any_peer", "call_local", "reliable")
func request_spawn_item(item_id: String, amount: int) -> void:
	if not _server_allowed():
		return
	var item := Items.get_item(StringName(item_id))
	if item == null:
		_reply(false, "Objet inconnu : %s" % item_id)
		return
	var message := ""
	match item.kind:
		ItemData.Kind.WEAPON:
			amount = 1
			message = "%s posé devant vous" % item.display_name
		ItemData.Kind.CREDITS:
			amount = clampi(amount, 1, Config.ADMIN_MAX_CREDITS)
			message = "%d crédits posés devant vous" % amount
		_:
			_reply(false, "Objet non autorisé : %s" % item_id)
			return
	Events.loot_drop_requested.emit(item.id, amount, -1, _front(Config.ADMIN_SPAWN_DISTANCE), false)
	print("[Admin] Joueur %d : %s" % [player.get_peer_id(), message])
	_reply(true, message)


## Lobby : lancer la partie tout de suite.
@rpc("any_peer", "call_local", "reliable")
func request_force_start() -> void:
	if not _server_allowed():
		return
	var match_manager := player.get_parent().get_parent().get_node_or_null("MatchManager") as MatchManager
	if match_manager and MatchManager.is_lobby():
		match_manager.server_force_start()
		_reply(true, "Partie lancée")
	else:
		_reply(false, "Pas dans le lobby")


## Capacité équipée tout de suite sur Q (slot 0) ou F (slot 1).
@rpc("any_peer", "call_local", "reliable")
func request_set_ability(slot: int, ability_id: String) -> void:
	if not _server_allowed():
		return
	if player.abilities.server_set_slot(slot, ability_id):
		_reply(true, "%s : %s" % ["Q" if slot == 0 else "F", AbilityController.get_ability(ability_id).get_display_name()])
	else:
		_reply(false, "Capacité inconnue : %s" % ability_id)


## Capacités : recharges remises à zéro.
@rpc("any_peer", "call_local", "reliable")
func request_abilities_ready() -> void:
	if not _server_allowed():
		return
	player.abilities.server_reset_cooldowns()
	_reply(true, "Recharges à zéro")


## Équipe directement un kit (sans la limite « au largage / à la réapparition »).
@rpc("any_peer", "call_local", "reliable")
func request_set_kit(kit_id: String) -> void:
	if not _server_allowed():
		return
	if player.kit.server_set_kit(kit_id):
		_reply(true, "Kit équipé : %s" % player.kit.get_display_name())
	else:
		_reply(false, "Kit inconnu : %s" % kit_id)


@rpc("any_peer", "call_local", "reliable")
func request_spawn_crystal(crystal_data_path: String) -> void:
	if not _server_allowed():
		return
	# Seulement un CrystalData du dossier des quêtes (le chemin vient du réseau).
	if not crystal_data_path.begins_with(QUESTS_DIR) or not ResourceLoader.exists(crystal_data_path):
		_reply(false, "Cristal inconnu")
		return
	var crystal := load(crystal_data_path) as CrystalData
	if crystal == null:
		_reply(false, "Cristal inconnu")
		return
	Events.crystal_spawn_requested.emit(crystal_data_path, _ground(_front(Config.ADMIN_CRYSTAL_DISTANCE)))
	var message := "%s %s posé devant vous" % [crystal.display_name, crystal.difficulty_name]
	print("[Admin] Joueur %d : %s" % [player.get_peer_id(), message])
	_reply(true, message)


@rpc("any_peer", "call_local", "reliable")
func request_time_skip(seconds: float) -> void:
	if not _server_allowed():
		return
	if not is_finite(seconds) or seconds <= 0.0:
		return
	seconds = minf(seconds, Config.ADMIN_MAX_TIME_SKIP)
	Events.time_skip_requested.emit(seconds)
	var text := "Admin : temps avancé de %d min %02d s" % [floori(seconds / 60.0), int(seconds) % 60]
	Events.announce_requested.emit(text, Color(0.75, 0.6, 1.0))
	print("[Admin] Joueur %d : %s" % [player.get_peer_id(), text])
	_reply(true, "Temps avancé")


## Aller directement à un temps de partie (on ne peut qu'avancer).
@rpc("any_peer", "call_local", "reliable")
func request_time_set(seconds: float) -> void:
	if not _server_allowed():
		return
	if not is_finite(seconds) or seconds <= 0.0 or seconds > Config.match_rules.match_duration:
		return
	Events.match_time_set_requested.emit(seconds)
	var text := "Admin : partie avancée à %d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]
	Events.announce_requested.emit(text, Color(0.75, 0.6, 1.0))
	print("[Admin] Joueur %d : %s" % [player.get_peer_id(), text])
	_reply(true, text)


func _server_allowed() -> bool:
	if not multiplayer.is_server():
		return false
	if not Config.ADMIN_MENU_ENABLED or multiplayer.get_remote_sender_id() != player.get_peer_id():
		return false
	return true


## Point à `distance` m devant le joueur, à hauteur de ses pieds.
func _front(distance: float) -> Vector3:
	var forward := -player.global_basis.z
	forward.y = 0.0
	return player.global_position + forward.normalized() * distance


## Pose le point sur le sol (le cristal n'est pas recalé par le QuestManager).
func _ground(pos: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 10.0, pos + Vector3.DOWN * 50.0)
	query.collision_mask = 1  # monde seulement
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else pos


func _reply(ok: bool, message: String) -> void:
	_admin_result.rpc_id(player.get_peer_id(), ok, message)


@rpc("any_peer", "call_local", "reliable")
func _admin_result(ok: bool, message: String) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	admin_result.emit(ok, message)
