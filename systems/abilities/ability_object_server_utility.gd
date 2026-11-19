extends RefCounted
## Portail et balise d'un AbilityObject (serveur uniquement) : fonctions statiques appelées par
## AbilityObjectServer. Le RPC _scan_ping reste sur l'objet.

const PORTAL_RADIUS := 1.3


static func _world(o: AbilityObject) -> Node:
	return o.get_parent().get_parent()


## Téléporte joueurs et monstres qui touchent l'entrée ; `teleported` : nœud -> âge du dernier passage.
static func portal(o: AbilityObject, teleported: Dictionary) -> void:
	var entry := o.global_position
	var exit: Vector3 = o.spawn_data["exit"]
	var candidates: Array = []
	var players := _world(o).get_node_or_null("Players")
	if players:
		candidates.append_array(players.get_children())
	var monsters := _world(o).get_node_or_null("Monsters")
	if monsters:
		candidates.append_array(monsters.get_children())
	for node in candidates:
		var body := node as Node3D
		if body == null or Vector2(body.global_position.x - entry.x, body.global_position.z - entry.z).length() > PORTAL_RADIUS:
			continue
		if o.age - float(teleported.get(body, -10.0)) < 1.0:
			continue
		teleported[body] = o.age
		var dest := exit + Vector3.UP * 0.3
		body.global_position = dest
		if body is Player:
			(body as Player).teleport.rpc_id((body as Player).get_peer_id(), dest)


## Balise : envoie au propriétaire les positions des autres joueurs proches.
static func ward_scan(o: AbilityObject) -> void:
	var spotted: Array = []
	var players := _world(o).get_node_or_null("Players")
	if players:
		for node in players.get_children():
			var p := node as Player
			if p and p.get_peer_id() != o.owner_id and p.can_be_hit() \
					and p.global_position.distance_to(o.global_position) <= maxf(o.ability.radius_m, 5.0):
				spotted.append(p.global_position)
	o._scan_ping.rpc_id(o.owner_id, spotted)
