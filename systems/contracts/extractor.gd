class_name Extractor
extends ContractSite
## Contrat « Extraction d'Ambrine ». Maintenir E (data.hold_time) pour installer
## l'extracteur, ou le reprendre à un autre joueur.
## Tant qu'il le garde, son propriétaire reçoit DIRECTEMENT des points d'objectif
## (pas besoin d'y retourner), de plus en plus vite :
## points_per_second + points_growth × minutes tenues (remis à zéro quand il change de mains).
## Les monstres ne sont pas alertés ; les joueurs, si (annonce).
## Champs utilisés : hold_time, points_per_second, points_growth, track, color.

var owner_id: int = 0          ## synchronisé
var held_minutes: float = 0.0  ## synchronisé


func _sync_props() -> Array[String]:
	return ["owner_id", "held_minutes"]


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
	var t := make_mesh(tank, Color(0.55, 0.58, 0.62))
	t.position.y = 1.3
	add_child(t)


func _label_height() -> float:
	return 3.2


func current_rate() -> float:
	return data.points_per_second + data.points_growth * held_minutes


func _refresh() -> void:
	if owner_id == 0:
		_label.text = "%s — libre" % data.display_name
	else:
		_label.text = "%s — %s\n+%.1f pts d'objectif/s" % [data.display_name, player_name(owner_id), current_rate()]


func get_prompt(player: Player) -> String:
	if owner_id == player.get_peer_id():
		return "Extracteur à vous : +%.1f pts d'objectif/s, de plus en plus vite" % current_rate()
	if owner_id == 0:
		return "Maintenir E (%d s) : installer un extracteur" % int(data.hold_time)
	return "Maintenir E (%d s) : reprendre l'extracteur" % int(data.hold_time)


func get_hold_time(player: Player) -> float:
	return 0.0 if owner_id == player.get_peer_id() else data.hold_time


func server_interact(player: Player) -> void:
	var peer := player.get_peer_id()
	if owner_id == peer:
		return
	var verb := "installé" if owner_id == 0 else "repris"
	_set_owner(peer)
	announce("%s a %s l'extracteur d'Ambrine !" % [player_name(peer), verb])


func _set_owner(peer: int) -> void:
	var old := find_player(owner_id)
	if old:
		old.score.set_objective_rate(data.track, 0.0)
	owner_id = peer
	held_minutes = 0.0


func _physics_process(delta: float) -> void:
	if owner_id == 0:
		return
	var owner := find_player(owner_id)
	if owner == null:
		_set_owner(0)
		return
	held_minutes += delta / 60.0
	give_points_over_time(owner, current_rate(), delta)
	owner.score.set_objective_rate(data.track, current_rate())
