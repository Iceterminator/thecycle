extends RefCounted
## Dégâts sur la durée d'un monstre (mods d'arme feu / poison), serveur.

var _m: Monster
var _dots: Array = []        # [par seconde, fin (ms), attaquant]
var _dot_left: float = 0.0


func _init(monster: Monster) -> void:
	_m = monster


func apply_dot(per_s: float, duration: float, attacker_id: int) -> void:
	_dots.append([per_s, Time.get_ticks_msec() + int(duration * 1000.0), attacker_id])


func tick(delta: float) -> void:
	if _dots.is_empty() or _m.health <= 0.0:
		return
	_dot_left -= delta
	if _dot_left > 0.0:
		return
	_dot_left = 0.25
	var now := Time.get_ticks_msec()
	_dots = _dots.filter(func(d: Array) -> bool: return now < int(d[1]))
	for d: Array in _dots.duplicate():
		if _m.health > 0.0:
			_m.server_receive_hit(float(d[0]) * 0.25, int(d[2]))
