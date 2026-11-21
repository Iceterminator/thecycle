extends RefCounted
## Calculs dérivés des données du kit : bonus de niveau et de mods (cœur + niveaux 1 à 3),
## paramètres de mouvement, PV / bouclier max, vitesse, régénération. Sans état propre
## (hors cache des effets des mods).

var _c: KitController
var _cache_key: String = "?"
var _mod_effects: Array[Dictionary] = []


func _init(controller: KitController) -> void:
	_c = controller


## Somme d'un effet sur les bonus débloqués (niveaux 1 à `level`) et les mods équipés.
func get_effect(effect: String) -> float:
	var kit := _c.get_kit()
	var total := 0.0
	if kit == null:
		return total
	for i in mini(_c.level, kit.level_perk_effects.size()):
		total += float(kit.level_perk_effects[i].get(effect, 0.0))
	for fx in _effects_of_mods(kit):
		total += float(fx.get(effect, 0.0))
	return total


## Effets du cœur et des mods de niveau équipés (recalculés seulement quand ils changent).
func _effects_of_mods(kit: KitData) -> Array[Dictionary]:
	var key := _c.kit_id + "|" + _c.mod_ids
	if key == _cache_key:
		return _mod_effects
	_cache_key = key
	_mod_effects = []
	var slots := KitModData.slots_from_text(_c.mod_ids)
	var core := core_of(kit, String(slots.get("core", "")))
	if not core.is_empty():
		_mod_effects.append(core.get("effects", {}))
	for tier in range(1, KitModData.TIERS + 1):
		var mod := KitModData.get_mod(String(slots.get(str(tier), "")))
		if mod != null and mod.tier == tier:
			_mod_effects.append(mod.effects)
	return _mod_effects


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
	return base * (1.0 + get_effect("max_health_mult")) + get_effect("max_health_add")


func max_shield() -> float:
	var kit := _c.get_kit()
	var base := kit.shield if kit and kit.shield > 0.0 else Config.combat.kit_default_shield
	return base + get_effect("max_shield_add")


func move_speed() -> float:
	var kit := _c.get_kit()
	var base := kit.move_speed_mps if kit and kit.move_speed_mps > 0.0 else Config.combat.kit_default_speed
	base += get_effect("move_speed_add")
	var mult := 1.0 + get_effect("move_speed_mult")
	if _c.combat.low_hp():
		mult *= 1.0 + get_effect("low_hp_speed_mult")
	return base * mult


func health_regen_delay() -> float:
	var delay := move_param("fast_health_regen", "health_regen_delay_s", Config.combat.health_regen_delay)
	return delay * (1.0 + get_effect("health_regen_delay_mult"))


func health_regen_rate() -> float:
	var rate := move_param("fast_health_regen", "health_regen_per_s", Config.combat.health_regen_rate)
	return rate * (1.0 + get_effect("health_regen_mult"))


## Cœur `id` de ce kit : { id, name, effect, effects, unlock_level }, ou {}.
static func core_of(kit: KitData, id: String) -> Dictionary:
	if kit != null and id != "":
		for m: Dictionary in kit.mods:
			if String(m.get("id", "")) == id:
				return m
	return {}


## Le cœur `id` de ce kit est-il débloqué pour ce joueur (réputation de la faction du kit) ?
static func mod_unlocked(peer: int, kit: KitData, id: String) -> bool:
	var core := core_of(kit, id)
	return not core.is_empty() and ProfileManager.is_unlocked(peer, kit.faction, int(core.get("unlock_level", 0)))
