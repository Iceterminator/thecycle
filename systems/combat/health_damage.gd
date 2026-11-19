extends RefCounted
## Calcul des dégâts subis par un joueur (serveur) : filtres, réductions, bouclier,
## passage à terre ou mort. Fonctions statiques appelées par Health.apply_damage.


## Applique les dégâts à `h`. Renvoie true si ce coup a tué le joueur.
static func apply(h: Health, amount: float, attacker_id: int, shield_mult: float, health_mult: float) -> bool:
	if not h.multiplayer.is_server():
		push_error("[Health] apply_damage appelé hors du serveur")
		return false
	if h.is_dead or amount <= 0.0:
		return false
	# Largage (écran de départ, capsule) : invulnérable, y compris à la chute.
	var host := h.get_parent() as Player
	if host and host.is_dropping():
		return false
	# Lobby : personne ne peut être blessé.
	if MatchManager.is_lobby() and attacker_id != Config.FALL_KILLER_ID:
		return false
	# Alliés (escouade, pacte) : ils ne peuvent pas se blesser.
	if Allies.allied(h.get_peer_id(), attacker_id):
		return false
	# Défense du kit contre les créatures (bonus de niveau).
	var kit := h._kit()
	if kit and attacker_id == Config.MONSTER_KILLER_ID:
		amount *= maxf(1.0 - kit.get_effect("creature_defense"), 0.0)
	# Effets temporaires : Coque (invulnérable), stimulants / camouflages (dégâts subis).
	var buffs := h._buffs()
	if buffs:
		if buffs.get_max("invulnerable") > 0.0 and attacker_id != Config.FALL_KILLER_ID:
			return false
		amount *= buffs.get_mult("damage_taken_mult")
	h._since_damage = 0.0
	# Le bouclier prend d'abord (dégâts x shield_mult), le reste passe sur les PV (x health_mult)
	# (ex. fusil à pompe plus mortel une fois le bouclier tombé).
	var absorbed := minf(h.shield, amount * shield_mult)
	h.shield -= absorbed
	var rest := amount - absorbed / maxf(shield_mult, 0.001)
	h.health = maxf(h.health - rest * health_mult, 0.0)
	Events.player_damaged.emit(h.get_peer_id(), amount, attacker_id)
	if h.health <= 0.0 and not h.is_downed and h._has_ally_standing() and attacker_id != Config.FALL_KILLER_ID:
		# À terre plutôt que mort : un allié peut venir relever.
		h.is_downed = true
		h.downed_by = attacker_id
		h._downed_left = Config.combat.downed_time
		h.health = Config.combat.downed_health
		h.shield = 0.0
		Events.player_downed.emit(h.get_peer_id(), attacker_id)
		return false
	if h.health <= 0.0:
		# Achevé à terre : le kill revient à celui qui l'a mis à terre.
		if h.is_downed and h.downed_by != 0:
			attacker_id = h.downed_by
		h.is_downed = false
		h.killer_id = attacker_id
		h.is_dead = true
		print("[Combat] Joueur %d tué par %d" % [h.get_peer_id(), attacker_id])
		Events.player_died.emit(h.get_peer_id(), attacker_id)
		return true
	return false
