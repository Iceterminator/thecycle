extends RefCounted
## Calculs dérivés des données du kit : bonus de niveau et de mod, paramètres de
## mouvement, PV / bouclier max, vitesse, régénération. Sans état propre.

var _c: KitController


func _init(controller: KitController) -> void:
	_c = controller


## Somme d'un effet sur les bonus débloqués (niveaux 1 à `level`).
func get_effect(effect: String) -> float:
	var kit := _c.get_kit()
	var total := 0.0
	if kit == null:
		return total
	for i in mini(_c.level, kit.level_perk_effects.size()):
		total += float(kit.level_perk_effects[i].get(effect, 0.0))
	# Mod équipé.
	var mod := get_mod()
	if not mod.is_empty():
		total += float(mod.get("effects", {}).get(effect, 0.0))
	return total


## Paramètre d'une capacité de mouvement (KitData.movement).
func move_param(ability: String, key: String, default: float = NAN) -> float:
	var kit := _c.get_kit()
	var block: Dictionary = kit.movement.get(ability, {}) if kit else {}
	if block.has(key):
		return float(block[key])
	if is_nan(default):
		if not block.is_empty():
			push_warning("[Kit] %s.%s absent des données du kit" % [ability, key])
		return 0.0
	return default


func max_health() -> float:
	var kit := _c.get_kit()
	var base := kit.health if kit and kit.health > 0.0 else Config.combat.kit_default_health
	return base + get_effect("max_health_add")


func max_shield() -> float:
	var kit := _c.get_kit()
	var base := kit.shield if kit and kit.shield > 0.0 else Config.combat.kit_default_shield
	return base + get_effect("max_shield_add")


func move_speed() -> float:
	var kit := _c.get_kit()
	var base := kit.move_speed_mps if kit and kit.move_speed_mps > 0.0 else Config.combat.kit_default_speed
	base += get_effect("move_speed_add")
	return base * (1.0 + get_effect("move_speed_mult"))


func health_regen_delay() -> float:
	var delay := move_param("fast_health_regen", "health_regen_delay_s", Config.combat.health_regen_delay)
	return delay * (1.0 + get_effect("health_regen_delay_mult"))


func health_regen_rate() -> float:
	var rate := move_param("fast_health_regen", "health_regen_per_s", Config.combat.health_regen_rate)
	return rate * (1.0 + get_effect("health_regen_mult"))


## Mod équipé : { id, effect, effects, unlock_level }, ou {}.
func get_mod() -> Dictionary:
	var kit := _c.get_kit()
	if kit == null or _c.mod_id == "":
		return {}
	for m: Dictionary in kit.mods:
		if String(m.get("id", "")) == _c.mod_id:
			return m
	return {}


## Le mod `id` de ce kit est-il débloqué pour ce joueur (réputation de la faction du kit) ?
static func mod_unlocked(peer: int, kit: KitData, id: String) -> bool:
	if kit == null:
		return false
	for m: Dictionary in kit.mods:
		if String(m.get("id", "")) == id:
			return ProfileManager.is_unlocked(peer, kit.faction, int(m.get("unlock_level", 0)))
	return false
