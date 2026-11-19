extends RefCounted
## Côté serveur du kit : changement de kit, XP et niveaux, mod équipé.

var _c: KitController


func _init(controller: KitController) -> void:
	_c = controller


## Change de kit (menu admin) : niveau 1, PV et bouclier pleins.
func set_kit(id: String) -> bool:
	if not ResourceLoader.exists(KitController.KITS_DIR + id + ".tres") or (load(KitController.KITS_DIR + id + ".tres") as KitData) == null:
		return false
	_c.kit_id = id
	_c.mod_id = ""
	_c.level = 1
	_c.xp = 0
	apply_stats(true)
	print("[Kit] Joueur %d : %s" % [_c.player.get_peer_id(), _c.get_display_name()])
	return true


func add_xp(amount: int) -> void:
	if not _c.multiplayer.is_server() or amount <= 0 or _c.player.is_evacuated:
		return
	_c.xp += amount
	while _c.xp_for_next_level() > 0 and _c.xp >= _c.xp_for_next_level():
		_c.level += 1
		apply_stats(false)
		var perk := ""
		var kit := _c.get_kit()
		if kit and _c.level - 1 < kit.level_perks.size():
			perk = " : " + kit.level_perks[_c.level - 1]
		_c.player.score.notify.rpc_id(_c.player.get_peer_id(), "%s niveau %d%s" % [_c.get_display_name(), _c.level, perk], Color(0.6, 1.0, 0.7))
		_c.leveled_up.emit(_c.level)


## PV / bouclier max du kit sur la Health. `refill` : tout plein ; sinon le gain de max
## s'ajoute aux valeurs actuelles.
func apply_stats(refill: bool) -> void:
	_c.player.health.server_apply_kit(_c.max_health(), _c.max_shield(), refill)


## Équipe un mod du kit actuel ("" = aucun), s'il est débloqué. PV / bouclier recalculés.
func set_mod(id: String) -> void:
	if id != "" and not _c.mod_unlocked(_c.player.get_peer_id(), _c.get_kit(), id):
		id = ""
	if id == _c.mod_id:
		return
	_c.mod_id = id
	apply_stats(false)
