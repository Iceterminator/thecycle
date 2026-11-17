class_name LootTable
extends Resource
## Table de loot d'une caisse : chaque objet a un poids (plus il est grand, plus
## l'objet sort souvent). `weights[i]` correspond à `items[i]`.

@export var items: Array[ItemData] = []
@export var weights: PackedFloat32Array = PackedFloat32Array()
@export var min_drops: int = 2
@export var max_drops: int = 4


## Tire entre min_drops et max_drops objets au hasard.
func roll() -> Array[ItemData]:
	var result: Array[ItemData] = []
	var total := 0.0
	for w in weights:
		total += w
	if items.is_empty() or total <= 0.0:
		return result
	for i in randi_range(min_drops, max_drops):
		var r := randf() * total
		for j in mini(items.size(), weights.size()):
			r -= weights[j]
			if r <= 0.0:
				result.append(items[j])
				break
	return result
