class_name Extractor
extends ContractSite
## Contrat « Extraction d'Ambrine » : une bouche d'Ambrine (plusieurs par partie, visibles sur la carte).
## Maintenir E (data.hold_time) sur une bouche libre y pose un extracteur. Un joueur peut en
## posséder plusieurs ; chacun monte de niveau tout seul (level_rates / level_times).
## Un rival maintient E (data.hack_time) sur un extracteur adverse pour le pirater : son propriétaire
## est prévenu dès le début, et si l'extracteur est pris son niveau repart à zéro.
## Le propriétaire reçoit DIRECTEMENT des points d'objectif (sans y retourner).
## Les monstres ne sont pas alertés ; les joueurs, si (annonce).
## Champs utilisés : hold_time, hack_time, points_per_second, level_rates, level_times, track, color.

const HACK_WARN_COOLDOWN_MS := 3000  ## un même piratage ne prévient pas le propriétaire plus souvent

var owner_id: int = 0          ## synchronisé
var held_seconds: float = 0.0  ## synchronisé
var _tank: MeshInstance3D
var _last_warn_ms: int = -HACK_WARN_COOLDOWN_MS


func _sync_props() -> Array[String]:
	return ["owner_id", "held_seconds"]


func _ready() -> void:
	add_to_group("extractor_site")
	super()


func _build_visual() -> void:
	add_cylinder_collision(1.0, 2.2)
	var deposit := CylinderMesh.new()
	deposit.top_radius = 1.2
	deposit.bottom_radius = 1.5
	deposit.height = 0.4
	deposit.radial_segments = 7
	var d := make_mesh(deposit, data.color.darkened(0.3), true)
	d.position.y = 0.2
	add_child(d)
	var tank := CylinderMesh.new()
	tank.top_radius = 0.7
	tank.bottom_radius = 0.8
	tank.height = 1.8
	_tank = make_mesh(tank, Color(0.55, 0.58, 0.62))  # le réservoir n'apparaît qu'une fois l'extracteur posé
	_tank.position.y = 1.3
	add_child(_tank)


func _label_height() -> float:
	return 3.2


func current_rate() -> float:
	var rate := data.points_per_second
	for i in mini(data.level_rates.size(), data.level_times.size()):
		if held_seconds >= data.level_times[i]:
			rate = data.level_rates[i]
	return rate


func _refresh() -> void:
	if _tank:
		_tank.visible = owner_id != 0
	if owner_id == 0:
		_label.text = "Bouche d'Ambrine — libre"
	else:
		_label.text = "%s — %s\n+%.1f pts d'objectif/s" % [data.display_name, player_name(owner_id), current_rate()]


func get_prompt(player: Player) -> String:
	if owner_id == player.get_peer_id():
		return "Extracteur à vous : +%.1f pts d'objectif/s, de plus en plus vite" % current_rate()
	if owner_id == 0:
		return "Maintenir E (%d s) : installer un extracteur" % int(data.hold_time)
	return "Maintenir E (%d s) : pirater l'extracteur de %s" % [int(data.hack_time), player_name(owner_id)]


func get_hold_time(player: Player) -> float:
	if owner_id == player.get_peer_id():
		return 0.0
	return data.hold_time if owner_id == 0 else data.hack_time


## Serveur : un rival commence à pirater (appelé par l'Interactor au début du maintien de E).
func server_hold_started(player: Player) -> void:
	var now := Time.get_ticks_msec()
	if owner_id == 0 or owner_id == player.get_peer_id() or now - _last_warn_ms < HACK_WARN_COOLDOWN_MS:
		return
	var victim := find_player(owner_id)
	if victim:
		_last_warn_ms = now
		victim.score.notify.rpc_id(owner_id, "Votre extracteur est piraté !", Color(1.0, 0.4, 0.3))


func server_interact(player: Player) -> void:
	var peer := player.get_peer_id()
	if owner_id == peer:
		return
	var verb := "installé" if owner_id == 0 else "piraté"
	var old_owner := owner_id
	owner_id = peer
	held_seconds = 0.0
	_refresh_rate(old_owner)
	announce("%s a %s un extracteur d'Ambrine !" % [player_name(peer), verb])


## Gain continu affiché d'un joueur : somme de ses extracteurs.
func _refresh_rate(peer: int) -> void:
	var player := find_player(peer)
	if player == null:
		return
	var total := 0.0
	for node in get_tree().get_nodes_in_group("extractor_site"):
		var site := node as Extractor
		if site and site.owner_id == peer:
			total += site.current_rate()
	player.score.set_objective_rate(data.track, total)


func _physics_process(delta: float) -> void:
	if owner_id == 0:
		return
	var owner := find_player(owner_id)
	if owner == null:
		owner_id = 0  # déconnecté
		held_seconds = 0.0
		return
	held_seconds += delta
	give_points_over_time(owner, current_rate(), delta)
	_refresh_rate(owner_id)


## Écran Tab : les bouches (libres ou prises) sont toujours visibles.
func map_info() -> Dictionary:
	var info := super()
	info["always"] = true
	if owner_id == 0:
		info["color"] = data.color.darkened(0.45)
	return info
