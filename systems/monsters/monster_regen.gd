extends RefCounted
## Régénération de vie d'un monstre (serveur) : après data.regen_delay_s sans dégâts,
## la vie remonte de data.regen_per_s par seconde. La vie est répliquée par le MonsterSync.

var _m: Monster
var _since_hit: float = 0.0


func _init(monster: Monster) -> void:
	_m = monster


## Un coup reçu relance le délai.
func on_hit() -> void:
	_since_hit = 0.0


func tick(delta: float) -> void:
	var data := _m.data
	if data.regen_delay_s < 0.0 or data.regen_per_s <= 0.0 or _m.health <= 0.0:
		return
	_since_hit += delta
	if _since_hit >= data.regen_delay_s and _m.health < _m.max_health:
		_m.health = minf(_m.health + data.regen_per_s * delta, _m.max_health)
