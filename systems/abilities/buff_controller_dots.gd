extends RefCounted
## Dégâts sur la durée d'un BuffController (mods d'arme feu / poison, étape 9), côté serveur.

const DOT_TICK := 0.25

var b: BuffController
var _dots: Dictionary = {}   # serveur : id -> { per_s, end_ms, ignore_shield, attacker }
var _dot_left: float = 0.0


func _init(buffs: BuffController) -> void:
	b = buffs


## Serveur : brûlure / poison. Un nouveau coup relance la durée (pas de cumul infini).
func add_dot(id: String, display_name: String, per_s: float, duration: float,
		ignore_shield: bool, attacker_id: int) -> void:
	if not b.multiplayer.is_server() or per_s <= 0.0 or duration <= 0.0 or b.player.health.is_dead:
		return
	var current: float = _dots[id]["per_s"] if _dots.has(id) else 0.0
	_dots[id] = {"per_s": maxf(per_s, current), "end_ms": Time.get_ticks_msec() + int(duration * 1000.0),
			"ignore_shield": ignore_shield, "attacker": attacker_id}
	b.server_add(id, display_name, {"dot": per_s}, duration)


## Appelé par BuffController._physics_process (serveur) : applique les dégâts sur la durée.
func tick(delta: float) -> void:
	if _dots.is_empty():
		return
	_dot_left -= delta
	if _dot_left > 0.0:
		return
	_dot_left = DOT_TICK
	var now := Time.get_ticks_msec()
	for id: String in _dots.keys():
		var dot: Dictionary = _dots[id]
		if now >= int(dot["end_ms"]) or b.player.health.is_dead:
			_dots.erase(id)
			continue
		# Poison : shield_mult 0 = rien sur le bouclier, tout sur les PV.
		b.player.health.apply_damage(float(dot["per_s"]) * DOT_TICK, int(dot["attacker"]),
				0.0 if dot["ignore_shield"] else 1.0)
