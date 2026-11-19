extends RefCounted
## Horloge de la partie (serveur) : annonces, passage de l'évac, niveau des monstres, fin.
## Utilisé par MatchManager, qui garde l'état (elapsed, phase, pad_blocked).

var _m: MatchManager


func _init(manager: MatchManager) -> void:
	_m = manager


## Annonces : [temps (s), texte, couleur]. Déclenchées quand l'horloge franchit le temps.
func _announces() -> Array:
	var land := Config.match_rules.evac_landing_time
	var end := Config.match_rules.match_duration
	return [
		[Config.match_rules.evac_announce_time, "La navette d'évacuation arrivera dans %d secondes, au centre de la carte !" % roundi(land - Config.match_rules.evac_announce_time), MatchManager.EVAC_COLOR],
		[end - 30.0, "Décollage de l'évac dans 30 secondes !", MatchManager.EVAC_COLOR],
		[end - 10.0, "Décollage dans 10 secondes !", MatchManager.EVAC_COLOR],
	]


## Fait avancer l'horloge jusqu'à `to` en déclenchant tout ce qui est franchi.
func advance(to: float) -> void:
	var before := _m.elapsed
	_m.elapsed = minf(to, Config.match_rules.match_duration)
	var elapsed := _m.elapsed
	for entry: Array in _announces():
		if before < entry[0] and elapsed >= entry[0]:
			Events.announce_requested.emit(entry[1], entry[2])
	if before < Config.match_rules.evac_announce_time and elapsed >= Config.match_rules.evac_announce_time:
		_m._set_pad_blocked(true)
		Events.evac_announced.emit()  # MonsterManager occupe la plateforme (ou la déclare libre)
		if _m.pad_blocked:
			Events.announce_requested.emit("Des monstres occupent la plateforme d'évac : tuez-les pour que la navette puisse se poser !", MatchManager.EVAC_COLOR)
	if _m.phase == MatchManager.Phase.PLAYING and _m.pad_blocked and before < Config.match_rules.evac_landing_time and elapsed >= Config.match_rules.evac_landing_time:
		Events.announce_requested.emit("NAVETTE BLOQUÉE — NETTOYER LA PLATEFORME", MatchManager.EVAC_COLOR)
	if _m.phase == MatchManager.Phase.PLAYING and not _m.pad_blocked and elapsed >= Config.match_rules.evac_landing_time:
		_m.phase = MatchManager.Phase.EVAC
		Events.evac_landed.emit()
		Events.announce_requested.emit("L'évac se pose au centre ! Montez à bord par la rampe.", MatchManager.ANNOUNCE_COLOR)
		_m._broadcast_clock()
	# Niveau des monstres (1 au départ, puis 2 et 3 aux temps de Config).
	for i in Config.match_rules.monster_level_times.size():
		var t: float = Config.match_rules.monster_level_times[i]
		if before < t and elapsed >= t:
			Events.monster_level_changed.emit(i + 2)
			Events.announce_requested.emit("Les monstres passent au niveau %d : plus résistants, plus de crédits !" % (i + 2), MatchManager.MONSTER_COLOR)
	if before < Config.match_rules.crystal_upgrade_time and elapsed >= Config.match_rules.crystal_upgrade_time:
		Events.crystal_upgrade_requested.emit()
	if elapsed >= Config.match_rules.match_duration:
		_m._cycle.end_match()
