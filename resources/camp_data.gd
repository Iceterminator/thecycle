class_name CampData
extends Resource
## Composition d'un camp (meute) de monstres. `min_counts[i]` / `max_counts[i]`
## correspondent à `monsters[i]`. Un camp = un fichier .tres dans data/camps/.

@export var level: int = 1
@export var monsters: Array[MonsterData] = []
@export var min_counts: PackedInt32Array = PackedInt32Array()
@export var max_counts: PackedInt32Array = PackedInt32Array()


## Tire la composition du camp (liste de monstres à faire apparaître).
func roll() -> Array[MonsterData]:
	var result: Array[MonsterData] = []
	for i in mini(monsters.size(), mini(min_counts.size(), max_counts.size())):
		for n in randi_range(min_counts[i], max_counts[i]):
			result.append(monsters[i])
	return result
