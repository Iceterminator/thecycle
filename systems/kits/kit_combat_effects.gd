extends RefCounted
## Effets de combat des mods de kit : dégâts subis / infligés (air, sprint, sous 30 % de PV,
## cumuls d'éliminations), soin par élimination, maniement des armes (pistolets, Dernier souffle).
## Dégâts : calculés par le serveur (Health, WeaponDamage). Maniement : même calcul sur le
## client et le serveur (la santé est synchronisée).

var _c: KitController
## Serveur : fin (ms) de chaque cumul de « Rage du chasseur ».
var _stacks_end_ms: Array[int] = []


func _init(controller: KitController) -> void:
	_c = controller


## Sous le seuil de PV (« Dernier souffle ») ?
func low_hp() -> bool:
	var player := _c.player
	var threshold := _c.get_effect("low_hp_threshold")
	if player == null or threshold <= 0.0 or player.health.is_dead:
		return false
	return player.health.health < player.health.get_max_health() * threshold


## Facteur sur les dégâts que ce joueur SUBIT (en l'air, en sprint, sous le seuil de PV).
func damage_taken_mult() -> float:
	var player := _c.player
	var mult := 1.0
	if player.is_airborne:
		mult *= 1.0 + _c.get_effect("air_damage_taken_mult")
	if player.is_sprinting:
		mult *= 1.0 + _c.get_effect("sprint_damage_taken_mult")
	if low_hp():
		mult *= 1.0 + _c.get_effect("low_hp_damage_taken_mult")
	return maxf(mult, 0.0)


## Facteur sur les dégâts que ce joueur INFLIGE (cumuls d'éliminations, en l'air).
func damage_dealt_mult(target_is_player: bool) -> float:
	var mult := 1.0 + _c.get_effect("kill_damage_bonus") * kill_stacks()
	if _c.player.is_airborne:
		mult *= 1.0 + _c.get_effect("air_damage_dealt_mult")
		if target_is_player:
			mult *= 1.0 + _c.get_effect("air_damage_dealt_players_mult")
	return maxf(mult, 0.0)


## Cumuls de « Rage du chasseur » encore actifs (serveur).
func kill_stacks() -> int:
	var now := Time.get_ticks_msec()
	_stacks_end_ms = _stacks_end_ms.filter(func(end: int) -> bool: return end > now)
	return _stacks_end_ms.size()


## Serveur : ce joueur vient d'éliminer un joueur ou un monstre.
func on_kill() -> void:
	var max_stacks := int(_c.get_effect("kill_damage_max_stacks"))
	if max_stacks > 0:
		if kill_stacks() >= max_stacks:
			_stacks_end_ms.pop_front()
		_stacks_end_ms.append(Time.get_ticks_msec() + int(_c.get_effect("kill_damage_duration_s") * 1000.0))
	var heal := _c.get_effect("kill_heal")
	if heal > 0.0:
		_c.player.health.heal(heal)


func clear_stacks() -> void:
	_stacks_end_ms.clear()


## Facteur sur un temps de maniement de l'arme `wdata` : "reload" (rechargement), "ads" (visée),
## "equip" (sortie) ou "recoil" (recul). Pistolets et, sauf le recul, Dernier souffle.
func handling_mult(kind: String, wdata: WeaponData) -> float:
	var mult := 1.0
	if wdata != null and wdata.type == WeaponData.WeaponType.PISTOL:
		mult *= maxf(1.0 + _c.get_effect("pistol_%s_mult" % kind), 0.1)
	if kind != "recoil" and low_hp():
		mult *= maxf(1.0 + _c.get_effect("low_hp_handling_mult"), 0.1)
	return mult
