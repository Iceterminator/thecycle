class_name AbilityController
extends Node
## Emplacements Q et F du joueur (étapes 8c et 9) : chacun contient une capacité OU un gadget.
## On commence la partie sans rien : capacités et gadgets s'achètent en boutique, puis
## attendent (« pending ») que le joueur appuie sur Q ou F pour les y mettre (remplace
## l'ancien contenu). Racheter une capacité équipée l'améliore (-recharge, 2 fois max) ;
## racheter un gadget équipé le recharge. À la mort, Q et F sont vidés.
## Un gadget sur Q / F vit dans l'inventaire (emplacements 2 et 3) : la touche le prend en
## main (ou rend l'arme), le clic l'utilise. Créé en code par le Player sur tous les peers
## (nœud « Abilities », autorité serveur ; AbilitySync envoie l'état).
##
## Client propriétaire : Q / F -> assigner l'achat en attente, prendre le gadget, ou
## request_use(emplacement, origine et direction de visée) pour une capacité.
## Serveur : vérifie (vivant, pas embarqué, recharge), applique selon la catégorie :
## - stim / camouflage / bouclier / soin : effet sur soi (BuffController) ;
## - grenade / sphère : objet lancé en arc ; tourelle, barrières, frappes, bombe, portail,
##   balise : objets réseau créés par l'AbilityManager (Events.ability_object_requested) ;
## - piège (Entrave) : ralentit la première cible visée.

const ABILITIES_DIR := "res://data/abilities/"
const SLOTS := 2

## Synchronisés (serveur -> tous).
var loadout: PackedStringArray = PackedStringArray(["", ""])
var upgrades: PackedInt32Array = PackedInt32Array([0, 0])
var cooldown_left: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
## Capacité ou gadget acheté, en attente d'être mis sur Q ou F ("" = rien).
var pending: String = ""

var player: Player
## Client : dernière arme en main avant de prendre un gadget (pour la rendre).
var _weapon_before_gadget: int = 0


func _init() -> void:
	var config := SceneReplicationConfig.new()
	for key in ["loadout", "upgrades", "cooldown_left", "pending"]:
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
		Events.match_reset_requested.connect(server_reset)
		player.health.dead_changed.connect(func(dead: bool) -> void:
			if dead:
				server_reset())


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


## Un gadget (objet arme de type gadget) ?
static func is_gadget(id: String) -> bool:
	var item := Items.get_item(StringName(id)) if id != "" else null
	return item != null and item.weapon != null and item.weapon.gadget != WeaponData.GadgetKind.NONE


## Capacité de l'emplacement (null si vide ou si c'est un gadget).
func get_slot(slot: int) -> AbilityData:
	return get_ability(loadout[slot]) if slot >= 0 and slot < SLOTS else null


## Texte du HUD : « [Q] Grenade à choc : prête   [F] Grenade ×2 ».
func status_text() -> String:
	var parts: PackedStringArray = []
	var keys := ["Q", "F"]
	for slot in SLOTS:
		var id := loadout[slot]
		if id == "":
			parts.append("[%s] —" % keys[slot])
		elif is_gadget(id):
			var inv_slot := Inventory.WEAPON_SLOTS + slot
			var in_hand := player.inventory.active_slot == inv_slot
			parts.append("[%s] %s ×%d%s" % [keys[slot], Shop.entry_name(id), player.inventory.slot_ammo[inv_slot], " (en main)" if in_hand else ""])
		else:
			var a := get_slot(slot)
			var state := "prête" if cooldown_left[slot] <= 0.0 else "%d s" % ceili(cooldown_left[slot])
			var up := "" if upgrades[slot] == 0 else " +%d" % upgrades[slot]
			parts.append("[%s] %s%s : %s" % [keys[slot], a.get_display_name() if a else id, up, state])
	var text := "    ".join(parts)
	if pending != "":
		text += "\n>> %s acheté : appuyez sur Q ou F pour l'équiper" % Shop.entry_name(pending)
	return text


# =========================================================================
# Client propriétaire
# =========================================================================

func _process(_delta: float) -> void:
	if player.health.is_dead or player.health.is_downed or player.is_evacuated or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	for slot in SLOTS:
		if not Input.is_action_just_pressed("ability_%d" % (slot + 1)):
			continue
		if pending != "":
			request_assign.rpc_id(1, slot)
		elif is_gadget(loadout[slot]):
			# Gadget : la touche le prend en main, ou rend l'arme d'avant.
			var inv := player.inventory
			var gadget_slot := Inventory.WEAPON_SLOTS + slot
			if inv.active_slot == gadget_slot:
				inv.request_switch.rpc_id(1, _weapon_before_gadget if inv.slot_ids[_weapon_before_gadget] != "" else 0)
			else:
				if inv.active_slot < Inventory.WEAPON_SLOTS:
					_weapon_before_gadget = inv.active_slot
				inv.request_switch.rpc_id(1, gadget_slot)
		elif loadout[slot] != "" and cooldown_left[slot] <= 0.0:
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


## Serveur : un achat (ou un gadget ramassé) attend Q ou F. Renvoie la raison d'un refus, ou "".
func server_offer(id: String) -> String:
	if pending != "":
		return "Équipez d'abord %s (Q ou F)" % Shop.entry_name(pending)
	if get_ability(id) == null and not is_gadget(id):
		return "Objet inconnu"
	pending = id
	return ""


## Q ou F pressée avec un achat en attente : il prend cet emplacement (remplace l'ancien).
@rpc("any_peer", "call_local", "reliable")
func request_assign(slot: int) -> void:
	if not _sender_ok() or slot < 0 or slot >= SLOTS or pending == "" or player.health.is_dead:
		return
	var id := pending
	pending = ""
	server_set_slot(slot, id)
	player.score.notify.rpc_id(player.get_peer_id(), "%s équipé sur %s" % [Shop.entry_name(id), ["Q", "F"][slot]], Color(0.6, 1.0, 0.6))


## Serveur : met une capacité ou un gadget sur Q (0) / F (1), à la place de l'ancien contenu.
## Si c'était déjà sur l'autre emplacement, il quitte l'autre (menu admin).
func server_set_slot(slot: int, id: String) -> bool:
	if slot < 0 or slot >= SLOTS or (get_ability(id) == null and not is_gadget(id)):
		return false
	var other := 1 - slot
	if loadout[other] == id:
		server_clear_slot(other)
	server_clear_slot(slot)
	var l := loadout.duplicate()
	l[slot] = id
	loadout = l
	if is_gadget(id):
		player.inventory.server_set_gadget(slot, StringName(id))
	return true


## Serveur : vide Q (0) ou F (1) (gadget épuisé, remplacement, mort).
func server_clear_slot(slot: int) -> void:
	if is_gadget(loadout[slot]):
		player.inventory.server_clear_gadget(slot)
	var l := loadout.duplicate()
	l[slot] = ""
	loadout = l
	var up := upgrades.duplicate()
	up[slot] = 0
	upgrades = up
	var left := cooldown_left.duplicate()
	left[slot] = 0.0
	cooldown_left = left


## Serveur (boutique, déjà payé) : améliore la capacité de l'emplacement.
func server_upgrade(slot: int) -> void:
	if slot < 0 or slot >= SLOTS or get_slot(slot) == null:
		return
	var up := upgrades.duplicate()
	up[slot] = mini(up[slot] + 1, Config.economy.ability_max_upgrades)
	upgrades = up


## Serveur : nouvelle partie ou mort : Q et F vides, plus d'achat en attente.
func server_reset() -> void:
	for slot in SLOTS:
		server_clear_slot(slot)
	pending = ""


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
			_request(base.merged({"kind": "turret", "pos": _aim_ground(origin, dir, Config.combat.ability_place_range)}))
			return true
		AbilityData.Category.BARRIER:
			var flat := Vector3(dir.x, 0, dir.z).normalized()
			_request(base.merged({"kind": "barrier", "pos": _ground(player.global_position + flat * 2.5), "dir": flat}))
			return true
		AbilityData.Category.STRIKE:
			_request(base.merged({"kind": "strike", "pos": _aim_ground(origin, dir, Config.combat.ability_aim_range)}))
			return true
		AbilityData.Category.TRAP:
			if a.id == &"snare_trap":
				return _server_snare(a, origin, dir)
			# Bombe de distorsion : la sortie s'ouvre plus loin, même derrière un obstacle.
			var flat := Vector3(dir.x, 0, dir.z).normalized()
			_request(base.merged({"kind": "strike", "pos": _ground(player.global_position + flat * Config.combat.warp_bomb_distance)}))
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
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * Config.combat.snare_range)
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


