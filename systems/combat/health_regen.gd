extends RefCounted
## Tick serveur de Health : chute sous la carte, agonie à terre, régénération
## du bouclier et des PV. Fonctions statiques appelées par Health._physics_process.


static func tick(h: Health, delta: float) -> void:
	if h.is_dead:
		return
	# Tombé sous la carte : mort (le serveur a la position envoyée par le client).
	var body := h.get_parent() as Player
	if body and not body.is_evacuated and not body.is_dropping() and body.global_position.y < Config.KILL_Y:
		h.apply_damage(h.health + h.shield + 1.0, Config.FALL_KILLER_ID)
		return
	# À terre : on saigne, pas de régénération ; à la fin, mort (kill pour celui qui l'a mis à terre).
	if h.is_downed:
		h._downed_left -= delta
		if h._downed_left <= 0.0:
			_bleed_out(h)
		return
	h._since_damage += delta
	if h._since_damage >= Config.combat.shield_regen_delay and h.shield < h.max_shield:
		h.shield = minf(h.shield + Config.combat.shield_regen_rate * delta, h.max_shield)
	var kit := h._kit()
	var buffs := h._buffs()
	var max_health := h.get_max_health()
	var delay := kit.health_regen_delay() if kit else Config.combat.health_regen_delay
	var rate := kit.health_regen_rate() if kit else Config.combat.health_regen_rate
	if buffs:
		if buffs.get_max("no_health_regen") > 0.0:
			return  # régénération retardée tant que l'effet dure
		if buffs.get_max("regen_now") > 0.0:
			delay = 0.0
		rate *= buffs.get_mult("health_regen_mult")
	if h._since_damage >= delay and h.health < max_health:
		h.health = minf(h.health + rate * delta, max_health)


## Serveur : fin du temps à terre, mort directe (rien ne peut l'empêcher) ; le kill revient
## à celui qui l'a mis à terre.
static func _bleed_out(h: Health) -> void:
	var killer := h.downed_by
	h.is_downed = false
	h.downed_by = 0
	h.health = 0.0
	h.shield = 0.0
	h.killer_id = killer
	h.is_dead = true
	print("[Combat] Joueur %d mort à terre (mis à terre par %d)" % [h.get_peer_id(), killer])
	Events.player_died.emit(h.get_peer_id(), killer)
