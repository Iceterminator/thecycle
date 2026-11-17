class_name AbilityController
extends Node
## Capacités du joueur (étape 8c) : 2 emplacements (touches Q et F), recharges,
## 2 améliorations par capacité en partie (Config.ABILITY_UPGRADE_PRICE crédits, chacune
## retire AbilityData.upgrade_cooldown_s à la recharge). Créé en code par le Player sur
## tous les peers (nœud « Abilities », autorité serveur ; AbilitySync envoie l'état).
##
## Client propriétaire : Q / F -> request_use(emplacement, origine et direction de visée).
## Serveur : vérifie (vivant, pas embarqué, recharge), applique selon la catégorie :
## - stim / camouflage / bouclier / soin : effet sur soi (BuffController) ;
## - grenade / sphère : objet lancé en arc ; tourelle, barrières, frappes, bombe, portail,
##   balise : objets réseau créés par l'AbilityManager (Events.ability_object_requested) ;
## - piège (Entrave) : ralentit la première cible visée.
## Le choix des capacités se fait dans le menu Équipement (K), dans la même fenêtre que le
## kit (largage / réapparition).

const ABILITIES_DIR := "res://data/abilities/"
const SLOTS := 2

## Synchronisés (serveur -> tous).
var loadout: PackedStringArray = PackedStringArray(["", ""])
var upgrades: PackedInt32Array = PackedInt32Array([0, 0])
var cooldown_left: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])

var player: Player


func _init() -> void:
	var config := SceneReplicationConfig.new()
	for key in ["loadout", "upgrades", "cooldown_left"]:
		var path := NodePath(".:" + key)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "AbilitySync"
	sync.replication_config = config
	add_child(sync)


func _ready() -> void:
	player = get_parent() as Player
	set_physics_process(multiplayer.is_server())
	set_process(player.is_multiplayer_authority())
	if multiplayer.is_server():
		loadout = PackedStringArray(Config.DEFAULT_ABILITIES)
		Events.match_reset_requested.connect(server_reset)


static func get_ability(id: String) -> AbilityData:
	if id == "" or not ResourceLoader.exists(ABILITIES_DIR + id + ".tres"):
		return null
	return load(ABILITIES_DIR + id + ".tres") as AbilityData


static func list_abilities() -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for file in ResourceLoader.list_directory(ABILITIES_DIR):
		var a: AbilityData = load(ABILITIES_DIR + file) as AbilityData if file.ends_with(".tres") else null
		if a:
			result.append(a)
	result.sort_custom(func(x: AbilityData, y: AbilityData) -> bool: return x.get_display_name() < y.get_display_name())
	return result


func get_slot(slot: int) -> AbilityData:
	return get_ability(loadout[slot]) if slot >= 0 and slot < SLOTS else null


## Texte du HUD : « [Q] Grenade à choc : prête   [F] Stimulant : 12 s ».
func status_text() -> String:
	var parts: PackedStringArray = []
	var keys := ["Q", "F"]
	for slot in SLOTS:
		var a := get_slot(slot)
		if a == null:
			continue
		var state := "prête" if cooldown_left[slot] <= 0.0 else "%d s" % ceili(cooldown_left[slot])
		var up := "" if upgrades[slot] == 0 else " +%d" % upgrades[slot]
		parts.append("[%s] %s%s : %s" % [keys[slot], a.get_display_name(), up, state])
	return "    ".join(parts)


# =========================================================================
# Client propriétaire
# =========================================================================

func _process(_delta: float) -> void:
	if player.health.is_dead or player.health.is_downed or player.is_evacuated or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	for slot in SLOTS:
		if Input.is_action_just_pressed("ability_%d" % (slot + 1)) and cooldown_left[slot] <= 0.0:
			request_use.rpc_id(1, slot, player.camera.global_position, -player.camera.global_basis.z)


# =========================================================================
# Serveur
# =========================================================================

func _physics_process(delta: float) -> void:
	var changed := false
	var left := cooldown_left.duplicate()
	for slot in SLOTS:
		if left[slot] > 0.0:
			left[slot] = maxf(left[slot] - delta, 0.0)
			changed = true
	if changed:
		cooldown_left = left


func _sender_ok() -> bool:
	return multiplayer.is_server() and multiplayer.get_remote_sender_id() == player.get_peer_id()


## Menu Équipement : choisir ses 2 capacités (même fenêtre que le kit).
@rpc("any_peer", "call_local", "reliable")
func request_loadout(first: String, second: String) -> void:
	if not _sender_ok() or first == second or get_ability(first) == null or get_ability(second) == null:
		return
	if not player.kit.can_change_kit_now():
		player.kit._kit_result.rpc_id(player.get_peer_id(), false, "Capacités : changement seulement au largage ou à la réapparition")
		return
	server_set_loadout(first, second)
	player.kit._kit_result.rpc_id(player.get_peer_id(), true, "Capacités équipées")


func server_set_loadout(first: String, second: String) -> void:
	loadout = PackedStringArray([first, second])
	upgrades = PackedInt32Array([0, 0])
	cooldown_left = PackedFloat32Array([0.0, 0.0])


## Boutique : améliorer une capacité (2 fois max, crédits).
@rpc("any_peer", "call_local", "reliable")
func request_upgrade(slot: int) -> void:
	if not _sender_ok() or slot < 0 or slot >= SLOTS or get_slot(slot) == null:
		return
	if upgrades[slot] >= Config.ABILITY_MAX_UPGRADES or player.health.is_dead or player.is_evacuated:
		return
	if not player.inventory.spend_credits(Config.ABILITY_UPGRADE_PRICE):
		player.shop._purchase_result.rpc_id(player.get_peer_id(), false, "Pas assez de crédits")
		return
	var up := upgrades.duplicate()
	up[slot] += 1
	upgrades = up
	player.shop._purchase_result.rpc_id(player.get_peer_id(), true,
			"%s amélioré (%d/%d)" % [get_slot(slot).get_display_name(), up[slot], Config.ABILITY_MAX_UPGRADES])


func server_reset() -> void:
	upgrades = PackedInt32Array([0, 0])
	cooldown_left = PackedFloat32Array([0.0, 0.0])


func server_reset_cooldowns() -> void:
	cooldown_left = PackedFloat32Array([0.0, 0.0])


@rpc("any_peer", "call_local", "reliable")
func request_use(slot: int, origin: Vector3, direction: Vector3) -> void:
	if not _sender_ok() or slot < 0 or slot >= SLOTS:
		return
	if player.health.is_dead or player.health.is_downed or player.is_evacuated or cooldown_left[slot] > 0.0:
		return
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.01:
		return
	if origin.distance_to(player.camera.global_position) > Config.SHOT_ORIGIN_TOLERANCE:
		return
	var ability := get_slot(slot)
	if ability == null:
		return
	direction = direction.normalized()
	if not _server_activate(ability, origin, direction):
		return
	var left := cooldown_left.duplicate()
	left[slot] = ability.get_cooldown(upgrades[slot], player.kit.get_effect("ability_cooldown_mult"))
	cooldown_left = left
	print("[Capacité] Joueur %d : %s" % [player.get_peer_id(), ability.get_display_name()])


## Applique la capacité. Renvoie false si elle n'a pas pu partir (pas de cible…).
func _server_activate(a: AbilityData, origin: Vector3, dir: Vector3) -> bool:
	var owner_id := player.get_peer_id()
	var base := {"ability": String(a.id), "owner": owner_id}
	match a.category:
		AbilityData.Category.STIM, AbilityData.Category.CLOAK, AbilityData.Category.SHIELD, AbilityData.Category.HEAL:
			if a.heal_instant > 0.0:
				player.health.heal(a.heal_instant)
			player.buffs.server_add(String(a.id), a.get_display_name(), a.buff, maxf(a.duration_s, 0.1), a.after_buff, a.after_duration_s)
			# Pied ferme : les PV max montent, les PV aussi.
			var bonus := float(a.buff.get("max_health_add", 0.0))
			if bonus > 0.0:
				player.health.heal(bonus)
			return true
		AbilityData.Category.GRENADE, AbilityData.Category.FIELD:
			_request(base.merged({"kind": "grenade", "origin": origin, "dir": dir}))
			return true
		AbilityData.Category.DEPLOYABLE:
			_request(base.merged({"kind": "turret", "pos": _aim_ground(origin, dir, Config.ABILITY_PLACE_RANGE)}))
			return true
		AbilityData.Category.BARRIER:
			var flat := Vector3(dir.x, 0, dir.z).normalized()
			_request(base.merged({"kind": "barrier", "pos": _ground(player.global_position + flat * 2.5), "dir": flat}))
			return true
		AbilityData.Category.STRIKE:
			_request(base.merged({"kind": "strike", "pos": _aim_ground(origin, dir, Config.ABILITY_AIM_RANGE)}))
			return true
		AbilityData.Category.TRAP:
			if a.id == &"snare_trap":
				return _server_snare(a, origin, dir)
			# Bombe de distorsion : la sortie s'ouvre plus loin, même derrière un obstacle.
			var flat := Vector3(dir.x, 0, dir.z).normalized()
			_request(base.merged({"kind": "strike", "pos": _ground(player.global_position + flat * Config.WARP_BOMB_DISTANCE)}))
			return true
		AbilityData.Category.MOBILITY:
			var flat := Vector3(dir.x, 0, dir.z).normalized()
			var entry := _ground(player.global_position + flat * 2.0)
			_request(base.merged({"kind": "portal", "pos": entry, "exit": _ground(entry + flat * maxf(a.distance_m, 5.0))}))
			return true
		AbilityData.Category.SCANNER:
			_request(base.merged({"kind": "ward", "pos": _ground(player.global_position + Vector3(Vector3(dir.x, 0, dir.z).normalized() * 1.0))}))
			return true
	return false


func _request(data: Dictionary) -> void:
	Events.ability_object_requested.emit(data)


## Entrave : la première cible visée (joueur ou monstre, à portée) est ralentie.
func _server_snare(a: AbilityData, origin: Vector3, dir: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * Config.SNARE_RANGE)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var target := hit["collider"] as Node
	if target == null or not target.is_in_group("damageable") or not target.can_be_hit():
		return false
	var mult := 1.0 - maxf(a.slow_percent, 0.0) / 100.0
	if target is Player:
		(target as Player).buffs.server_add("snare_trap", a.get_display_name(), {"speed_mult": mult}, a.duration_s)
	elif target is Monster:
		(target as Monster).apply_slow(mult, a.duration_s)
	else:
		return false
	return true


## Point visé au sol (ou au bout de la portée, posé sur le sol).
func _aim_ground(origin: Vector3, dir: Vector3, max_range: float) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * max_range, 1)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	var point: Vector3 = hit["position"] if not hit.is_empty() else origin + dir * max_range
	return _ground(point)


func _ground(pos: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 5.0, pos + Vector3.DOWN * 60.0, 1)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector3(pos.x, 0.0, pos.z)


## Serveur (menu admin) : met une capacité sur un emplacement ; si elle est déjà sur
## l'autre, les deux sont échangées. Recharge prête.
func server_set_slot(slot: int, id: String) -> bool:
	if slot < 0 or slot >= SLOTS or get_ability(id) == null:
		return false
	var l := loadout.duplicate()
	var other := 1 - slot
	if l[other] == id:
		l[other] = l[slot]
	l[slot] = id
	loadout = l
	var left := cooldown_left.duplicate()
	left[slot] = 0.0
	cooldown_left = left
	return true
