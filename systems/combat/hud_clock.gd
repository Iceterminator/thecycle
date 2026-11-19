extends RefCounted
## Textes du haut du HUD : horloge de partie, état de l'évac, alarme du scanner.

const HudWidgets := preload("res://systems/combat/hud_widgets.gd")
const HudScreens := preload("res://systems/combat/hud_screens.gd")


static func on_clock_synced(hud: CombatHud, elapsed: float, phase: int) -> void:
	hud._clock_elapsed = elapsed
	hud._clock_phase = phase
	if phase != MatchManager.Phase.ENDED:
		hud._results_panel.visible = false



static func update_clock(hud: CombatHud, delta: float) -> void:
	hud._clock_label.remove_theme_color_override("font_color")
	if hud._clock_phase == MatchManager.Phase.ENDED:
		hud._clock_label.text = "FIN"
		hud._clock_sub.text = "Fin de partie"
		hud._status_label.text = ""
		hud._restart_left = maxf(hud._restart_left - delta, 0.0)
		if hud._results_panel.visible:
			hud._results_label.text = hud._results_text + "\nRetour au lobby dans %d s" % ceili(hud._restart_left)
		return
	if hud._clock_phase == MatchManager.Phase.LOBBY:
		var ready := hud._lobby_ready.values().count(true)
		hud._clock_label.text = "%d / %d" % [ready, hud._player.get_parent().get_child_count()]
		hud._clock_sub.text = "LOBBY — EN ATTENTE QUE TOUT LE MONDE SOIT PRÊT"
		hud._storm_label.text = ""
		hud._status_label.text = ""
		return
	hud._clock_elapsed = 0.0 if hud._clock_phase == MatchManager.Phase.DROP else minf(hud._clock_elapsed + delta, Config.match_rules.match_duration)
	hud._storm_label.text = StormManager.hud_text(hud._player.global_position).replace("\n", "  —  ") + scanner_text(hud)
	HudScreens.update_downed(hud)
	if hud._clock_phase == MatchManager.Phase.EVAC:
		hud._clock_label.text = fmt(Config.match_rules.match_duration - hud._clock_elapsed)
		hud._clock_label.add_theme_color_override("font_color", CombatHud.ACCENT)
		hud._clock_sub.text = "DÉCOLLAGE DE L'ÉVAC"
		hud._status_label.text = "ÉVAC AU SOL — EMBARQUEZ !"
	else:
		hud._clock_label.text = fmt(maxf(Config.match_rules.evac_landing_time - hud._clock_elapsed, 0.0))
		hud._clock_sub.text = "ÉVAC DANS   ·   partie %s / %s" % [fmt(hud._clock_elapsed), fmt(Config.match_rules.match_duration)]
		hud._status_label.text = ""
		if MatchManager.is_pad_blocked():
			var late := hud._clock_elapsed >= Config.match_rules.evac_landing_time
			hud._clock_sub.text = ("NAVETTE BLOQUÉE   ·   partie %s / %s" if late else "ÉVAC DANS   ·   partie %s / %s") % [fmt(hud._clock_elapsed), fmt(Config.match_rules.match_duration)]
			hud._status_label.text = "CONTRAT : tuez les monstres pour nettoyer la plateforme d'évac"



## Secondes -> « mm:ss ».
static func fmt(seconds: float) -> String:
	var s := maxi(ceili(seconds), 0)
	return "%02d:%02d" % [floori(s / 60.0), s % 60]



static func scanner_text(hud: CombatHud) -> String:
	var nearest := INF
	for node in hud._player.get_parent().get_children():
		var other := node as Player
		if other == null or other == hud._player or other.health.is_dead or other.is_evacuated:
			continue
		if Allies.allied(hud._player.get_peer_id(), other.get_peer_id()):
			continue
		nearest = minf(nearest, other.global_position.distance_to(hud._player.global_position))
	if nearest > Config.combat.scanner_range:
		return ""
	return "   ⚠ Prospecteur à %d m" % roundi(nearest)
