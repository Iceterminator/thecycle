extends "res://tests/net_test.gd"
## Aides en plus de net_test.gd : étapes partagées hôte <-> client, placement, tir,
## interaction, monstres. Les tests 02 et suivants héritent de ce script.

## Zone de test : bord de la plateforme d'évac (sol plat, sans décor, loin des camps).
const SPOT_HOST := Vector2(14.0, -6.0)
const SPOT_CLIENT := Vector2(14.0, -2.0)

## Étapes reçues de l'autre côté : nom -> valeur (texte).
var _steps: Dictionary = {}


## Pas de prime pendant un test (elle tombe au hasard sur un joueur et change la Fame).
func _speed_up() -> void:
	super()
	config.match_rules.bounty_interval = 100000.0


# =========================================================================
# Étapes : l'un annonce, l'autre attend (RPC sur le nœud /root/Test, même chemin partout)
# =========================================================================

func send_step(step: String, value: String = "") -> void:
	_step_rpc.rpc(step, value)


@rpc("any_peer", "reliable")
func _step_rpc(step: String, value: String) -> void:
	_steps[step] = value


func wait_step(step: String, timeout: float = 30.0) -> bool:
	return await wait_until(func() -> bool: return _steps.has(step), timeout, "étape « %s » de l'autre côté" % step)


func step_value(step: String) -> String:
	return _steps.get(step, "")


# =========================================================================
# Placement
# =========================================================================

## Point au sol (relief), un peu au-dessus pour laisser tomber le joueur.
func ground(spot: Vector2, lift: float = 0.3) -> Vector3:
	return Vector3(spot.x, MapTerrain.height_at(spot.x, spot.y) + lift, spot.y)


## Le joueur local se place lui-même (le déplacement est décidé par son client).
func move_self(pos: Vector3) -> void:
	var p := local_player()
	if p:
		p.global_position = pos
		p.velocity = Vector3.ZERO


## Place le joueur local, puis attend que le serveur voie la nouvelle position.
func move_self_and_settle(pos: Vector3) -> void:
	move_self(pos)
	await wait(1.0)


# =========================================================================
# Tir (client propriétaire : le vrai RPC de l'arme, une demande = une balle)
# =========================================================================

## Demande un tir de l'arme du joueur local vers `target` (coordonnées monde).
func fire_at(target: Vector3) -> void:
	var p := local_player()
	var origin := p.camera.global_position
	p.weapon.request_fire.rpc_id(1, origin, (target - origin).normalized(), true)


## Torse d'un joueur (point visé).
func chest(p: Node3D) -> Vector3:
	return p.global_position + Vector3.UP * 1.0


# =========================================================================
# Interaction (Interactor : request_hold_start puis request_interact)
# =========================================================================

## Maintient E sur `target` pendant `hold` s (0 = interaction simple).
func hold_interact(target: Node, hold: float) -> void:
	var interactor := local_player().interactor
	if hold > 0.0:
		interactor.request_hold_start.rpc_id(1, target.get_path())
		await wait(hold + 0.3)
	interactor.request_interact.rpc_id(1, target.get_path())


# =========================================================================
# Monstres
# =========================================================================

func monsters() -> Array[Monster]:
	var result: Array[Monster] = []
	var w := world()
	if w == null:
		return result
	for node in w.get_node("Monsters").get_children():
		var m := node as Monster
		if m and m.health > 0.0:
			result.append(m)
	return result


## Monstres vivants à moins de `radius` m de `pos` (à plat).
func monsters_near(pos: Vector3, radius: float) -> Array[Monster]:
	var result: Array[Monster] = []
	for m in monsters():
		if Vector2(m.global_position.x - pos.x, m.global_position.z - pos.z).length() <= radius:
			result.append(m)
	return result


## Hôte : tue un monstre (dégâts serveur), au nom de `killer_id`.
func kill_monster(m: Monster, killer_id: int) -> void:
	if is_instance_valid(m) and m.health > 0.0:
		m.server_receive_hit(m.health + 1.0, killer_id)
