extends RefCounted
## Changement d'arme de Weapon (tous les peers) et remise à zéro du serveur à la réapparition.

var _w: Weapon


func _init(weapon: Weapon) -> void:
	_w = weapon


## Changement d'arme (sur tous les peers, quand le serveur change l'emplacement actif).
func on_active_weapon_changed() -> void:
	var new_data := _w.inventory.get_active_weapon()
	if new_data == null:
		return
	_w.data = new_data
	_w.ammo = _w.inventory.get_active_ammo()
	_w.is_reloading = false
	_w._reload_left = 0.0
	_w._burst_left = 0
	_w._client.stop_holding()
	_w._fire_cooldown = _equip_time()
	if _w.multiplayer.is_server():
		_w._srv.reload_end_ms = 0
		_w._srv.trigger_ms = 0
		_w._srv.switch_until_ms = Time.get_ticks_msec() + int(_equip_time() * 900.0)
		_w._srv.tokens = minf(_w._srv.tokens, _w._server_fire.token_capacity())
		# Le client peut ne pas voir le changement (même modèle d'arme échangé) :
		# on lui renvoie le bon chargeur.
		_w._sync_ammo.rpc_id(_w.player.get_peer_id(), _w.ammo)
	_w._emit_ammo()


## À l'apparition, le chargeur peut arriver du serveur après la lecture faite dans _ready :
## si l'arme affiche 0 sans recharger alors que le serveur en a, on reprend sa valeur.
func on_inventory_changed() -> void:
	if _w.ammo == 0 and not _w.is_reloading and _w._burst_left == 0 and _w.inventory.get_active_ammo() > 0:
		_w.ammo = _w.inventory.get_active_ammo()
		_w._emit_ammo()


func _equip_time() -> float:
	return (_w.data.equip_time_s if _w.data.equip_time_s > 0.0 else Config.WEAPON_SWITCH_TIME) * handling("equip")


## Facteur des mods de kit sur un temps de maniement (« reload », « ads », « equip », « recoil »).
func handling(kind: String) -> float:
	return _w.player.kit.combat.handling_mult(kind, _w.data) if _w.player.kit else 1.0


## Réapparition (serveur) : repart d'un état propre.
func server_refill() -> void:
	_w._srv.reload_end_ms = 0
	_w._srv.switch_until_ms = 0
	_w._srv.trigger_ms = 0
	_w._srv.tokens = _w._server_fire.token_capacity()
	_w._srv.last_ms = Time.get_ticks_msec()
	_w._sync_ammo.rpc_id(_w.player.get_peer_id(), _w.inventory.get_active_ammo())


## Début d'un rechargement (serveur, demande déjà validée).
func server_start_reload() -> void:
	_w._srv.trigger_ms = 0
	# 10 % de marge : la demande de rechargement et les tirs suivants n'arrivent
	# pas forcément avec le même délai.
	_w._srv.reload_end_ms = Time.get_ticks_msec() + int(_w.data.reload_s * handling("reload") * 900.0)
