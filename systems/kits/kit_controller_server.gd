extends RefCounted
## Côté serveur du kit : changement de kit, XP et niveaux, mods équipés, éliminations.

var _c: KitController


func _init(controller: KitController) -> void:
	_c = controller


## Change de kit (menu admin) : niveau 1, PV et bouclier pleins.
func set_kit(id: String) -> bool:
	if not ResourceLoader.exists(KitController.KITS_DIR + id + ".tres") or (load(KitController.KITS_DIR + id + ".tres") as KitData) == null:
		return false
	_c.kit_id = id
	_c.mod_ids = ""
	_c.combat.clear_stacks()
	_c.level = 1
	_c.xp = 0
	apply_stats(true)
	print("[Kit] Joueur %d : %s" % [_c.player.get_peer_id(), _c.get_display_name()])
	return true


func add_xp(amount: int) -> void:
	if not _c.multiplayer.is_server() or amount <= 0 or _c.player.is_evacuated:
		return
	amount = maxi(roundi(amount * (1.0 + _c.get_effect("kit_xp_mult"))), 1)
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




## XP de kit d'un monstre tué : son xp (MonsterData data/monsters/<id>.tres) × kit_xp_monster_scale ;
## sans xp connu, valeur fixe kit_xp_monster_kill.
func on_monster_killed(monster_id: StringName, killer_id: int) -> void:
	if killer_id != _c.player.get_peer_id():
		return
	_c.combat.on_kill()
	var path := "res://data/monsters/%s.tres" % monster_id
	var data := load(path) as MonsterData if ResourceLoader.exists(path) else null
	if data and data.xp > 0:
		add_xp(maxi(1, roundi(data.xp * Config.economy.kit_xp_monster_scale)))
	else:
		add_xp(Config.economy.kit_xp_monster_kill)


func on_player_died(victim_id: int, killer_id: int) -> void:
	if victim_id == _c.player.get_peer_id():
		_c.combat.clear_stacks()
	if killer_id == _c.player.get_peer_id() and victim_id != killer_id:
		_c.combat.on_kill()
		add_xp(Config.economy.kit_xp_player_kill)


## Équipe les mods du kit actuel : le cœur doit être débloqué, chaque mod de niveau doit exister
## à son niveau (sinon l'emplacement reste vide). PV / bouclier recalculés.
func set_mods(slots: Dictionary) -> void:
	var clean := {}
	if _c.mod_unlocked(_c.player.get_peer_id(), _c.get_kit(), String(slots.get("core", ""))):
		clean["core"] = String(slots["core"])
	for tier in range(1, KitModData.TIERS + 1):
		var mod := KitModData.get_mod(String(slots.get(str(tier), "")))
		if mod != null and mod.tier == tier:
			clean[str(tier)] = String(mod.id)
	var text := KitModData.slots_to_text(clean)
	if text == _c.mod_ids:
		return
	_c.mod_ids = text
	apply_stats(false)
