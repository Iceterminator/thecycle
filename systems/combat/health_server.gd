extends RefCounted
## Transitions d'état serveur d'un joueur (Health) : relevé, réapparition, nouveau kit,
## recherche d'un allié debout. Fonctions statiques appelées par Health.


## Un allié vivant, debout et pas embarqué peut-il relever ce joueur ?
static func has_ally_standing(h: Health) -> bool:
	var players := h.get_parent().get_parent()
	if players == null:
		return false
	for node in players.get_children():
		var ally := node as Player
		if ally == null or not Allies.can_revive(h.get_peer_id(), ally.get_peer_id()):
			continue
		if not ally.health.is_dead and not ally.health.is_downed and not ally.is_evacuated:
			return true
	return false


## Relevé par un allié (E maintenu).
static func revive_downed(h: Health, by_id: int) -> void:
	if not h.is_downed or h.is_dead:
		return
	h.is_downed = false
	h.downed_by = 0
	h.health = h.get_max_health() * Config.combat.revive_health_ratio
	h.shield = 0.0
	h._since_damage = 0.0
	Events.player_revived.emit(h.get_peer_id(), by_id)


## Nouveau kit ou niveau. `refill` : tout plein ; sinon le gain de max s'ajoute.
static func apply_kit(h: Health, new_max_health: float, new_max_shield: float, refill: bool) -> void:
	if refill or h.is_dead:
		h.health = new_max_health
		h.max_shield = new_max_shield
		h.shield = new_max_shield
	else:
		h.health = clampf(h.health + new_max_health - h._applied_max_health, 1.0, new_max_health)
		var gain := new_max_shield - h.max_shield
		h.max_shield = new_max_shield
		h.shield = clampf(h.shield + gain, 0.0, new_max_shield)
	h._applied_max_health = new_max_health


## Remet le joueur sur pied (réapparition), PV et bouclier du kit pleins.
static func revive(h: Health) -> void:
	h.is_downed = false
	h.downed_by = 0
	var kit := h._kit()
	if kit:
		h.max_shield = kit.max_shield()
	h.health = h.get_max_health()
	h._applied_max_health = h.health
	h.shield = h.max_shield
	h.killer_id = 0
	h._since_damage = 0.0
	h.is_dead = false
