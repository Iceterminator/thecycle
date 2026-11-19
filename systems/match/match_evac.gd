extends RefCounted
## Évacuation (serveur) : embarquement des joueurs et contrat « Nettoyer la plateforme ».
## Utilisé par MatchManager, qui garde l'état (evacuated, pad_blocked).

var _m: MatchManager


func _init(manager: MatchManager) -> void:
	_m = manager


func on_player_evacuated(peer_id: int) -> void:
	if _m.phase != MatchManager.Phase.EVAC or peer_id in _m.evacuated:
		return
	var player := _m.world.get_player(peer_id)
	if player == null:
		return
	_m.evacuated.append(peer_id)
	var bonus := Config.economy.evac_first_bonus if _m.evacuated.size() == 1 else Config.economy.evac_other_bonus
	player.score.add_rank_points(bonus)
	player.set_evacuated.rpc(true)
	var text := "%s a embarqué dans l'évac !" % ProfileManager.name_of(peer_id)
	if bonus > 0:
		text += " (premier à bord : +%d)" % bonus
	Events.announce_requested.emit(text, MatchManager.ANNOUNCE_COLOR)
	print("[Partie] Joueur %d embarqué (+%d)" % [peer_id, bonus])


## Contrat « Nettoyer la plateforme » rempli : Fame au tueur, la navette peut se poser
## (tout de suite si elle est déjà là, sinon à Config.match_rules.evac_landing_time).
func on_evac_pad_cleared(killer_id: int) -> void:
	if not _m.pad_blocked or _m.phase != MatchManager.Phase.PLAYING:
		return
	_m._set_pad_blocked(false)
	var killer := _m.world.get_player(killer_id)
	if killer:
		killer.score.add_contract_fame(Config.economy.evac_pad_clear_fame)
		Events.announce_requested.emit("%s a nettoyé la plateforme d'évac ! (+%d)" % [ProfileManager.name_of(killer_id), Config.economy.evac_pad_clear_fame], MatchManager.EVAC_COLOR)
	else:
		Events.announce_requested.emit("La plateforme d'évac est dégagée !", MatchManager.EVAC_COLOR)
	_m._clock.advance(_m.elapsed)  # se pose tout de suite si l'heure est passée
