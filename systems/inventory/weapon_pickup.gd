class_name WeaponPickup
extends Node
## Ramassage d'une arme au sol par emplacement.
## - Touche 1 / 2 en visant l'arme : emplacement vide = prise immédiate (et équipée) ;
##   emplacement occupé = MAINTENIR Config.economy.weapon_replace_hold_time s pour remplacer
##   (un simple appui change d'arme, géré par Inventory).
## - Touche E : voir slot_for_e (le maintien éventuel est géré par Interactor via Pickup.get_hold_time).
## Client propriétaire : annonce le début du maintien puis demande la prise ; le serveur vérifie
## la cible, la portée et que le maintien est réellement écoulé. L'ancienne arme tombe au sol.

signal hold_progress(ratio: float)  ## 0 = pas de maintien en cours

@onready var player: Player = get_parent()

# Client : maintien en cours
var _hold_slot: int = -1
var _hold_path: NodePath
var _hold_elapsed: float = 0.0
# Serveur : début du maintien annoncé par le client
var _srv_hold_path: NodePath
var _srv_hold_slot: int = -1
var _srv_hold_start_ms: int = 0


func _ready() -> void:
	set_process(player.is_multiplayer_authority())


## Emplacement visé par la touche E : celui en main ; s'il est occupé et que l'autre est libre, l'autre.
static func slot_for_e(inv: Inventory) -> int:
	var hand := inv.active_slot if inv.active_slot < Inventory.WEAPON_SLOTS else 0
	if inv.slot_ids[hand] != "" and inv.slot_ids[1 - hand] == "":
		return 1 - hand
	return hand


## Vrai si l'objet visé est une arme au sol (pas un gadget).
static func is_weapon_pickup(node: Node) -> bool:
	var pickup := node as Pickup
	return pickup != null and pickup.item.kind == ItemData.Kind.WEAPON and pickup.item.weapon != null \
			and pickup.item.weapon.gadget == WeaponData.GadgetKind.NONE


# =========================================================================
# Client propriétaire
# =========================================================================

func _process(delta: float) -> void:
	var target := player.interactor.current_target
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not is_weapon_pickup(target):
		_cancel_hold()
		return
	if _hold_slot < 0:
		for slot in Inventory.WEAPON_SLOTS:
			if Input.is_action_just_pressed("slot_%d" % (slot + 1)):
				_begin(target.get_path(), slot)
		return
	if not Input.is_action_pressed("slot_%d" % (_hold_slot + 1)) or target.get_path() != _hold_path:
		_cancel_hold()
		return
	_hold_elapsed += delta
	var hold_time := Config.economy.weapon_replace_hold_time
	hold_progress.emit(clampf(_hold_elapsed / hold_time, 0.0, 1.0))
	if _hold_elapsed >= hold_time:
		request_take.rpc_id(1, _hold_path, _hold_slot)
		_cancel_hold()


func _begin(path: NodePath, slot: int) -> void:
	if player.inventory.slot_ids[slot] == "":
		request_take.rpc_id(1, path, slot)  # emplacement libre : immédiat
		return
	_hold_slot = slot
	_hold_path = path
	_hold_elapsed = 0.0
	request_hold_start.rpc_id(1, path, slot)


func _cancel_hold() -> void:
	if _hold_slot >= 0:
		_hold_slot = -1
		_hold_elapsed = 0.0
		hold_progress.emit(0.0)


# =========================================================================
# Serveur
# =========================================================================

@rpc("any_peer", "call_local", "reliable")
func request_hold_start(path: NodePath, slot: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player.get_peer_id():
		return
	_srv_hold_path = path
	_srv_hold_slot = slot
	_srv_hold_start_ms = Time.get_ticks_msec()


@rpc("any_peer", "call_local", "reliable")
func request_take(path: NodePath, slot: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player.get_peer_id():
		return
	var health := player.health
	if MatchManager.is_lobby() or health.is_dead or health.is_downed or player.is_evacuated or player.is_dropping():
		return
	if slot < 0 or slot >= Inventory.WEAPON_SLOTS:
		return
	var target := get_node_or_null(path) as Pickup
	if target == null or not is_weapon_pickup(target) or target.is_taken():
		return
	var dist := player.camera.global_position.distance_to(target.global_position)
	if dist > Config.INTERACT_RANGE + Config.INTERACT_SERVER_MARGIN:
		push_warning("[Arme] Refusé : joueur %d trop loin (%.1f m)" % [player.get_peer_id(), dist])
		return
	if player.inventory.slot_ids[slot] != "":  # remplacement : le maintien doit être écoulé
		var held := (Time.get_ticks_msec() - _srv_hold_start_ms) / 1000.0
		if _srv_hold_path != path or _srv_hold_slot != slot \
				or held < Config.economy.weapon_replace_hold_time * Config.HOLD_SERVER_TOLERANCE:
			push_warning("[Arme] Refusé : touche pas maintenue assez longtemps (%.1f s)" % held)
			return
	_srv_hold_path = NodePath()
	target.server_take_into(player, slot)


## Serveur : place l'arme dans l'emplacement (slot < 0 : celui de la touche E) et l'équipe.
## Si l'emplacement est occupé, l'ancienne arme tombe au sol avec son palier et ses munitions.
func server_take(item: ItemData, amount: int, ammo: int, slot: int) -> void:
	var inv := player.inventory
	if slot < 0:
		slot = slot_for_e(inv)
	if inv.slot_ids[slot] != "":
		Events.loot_drop_requested.emit(StringName(inv.slot_ids[slot]), 1 + inv.slot_boosts[slot], inv.slot_ammo[slot], _drop_position(), false)
	var mag := ammo if ammo >= 0 else player.magazine_for(item.weapon)
	var boost := clampi(amount - 1, 0, item.weapon.boosts.size())  # palier porté par l'objet au sol
	inv.server_set_slot(slot, item.id, mag, boost)
	inv.active_slot = slot


func _drop_position() -> Vector3:
	return player.global_position - player.global_basis.z * 1.0 + Vector3(0, 0.5, 0)
