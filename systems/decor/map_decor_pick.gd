extends RefCounted
## Choix d'un modèle du décor selon le biome (MapBiomes / data/biomes/) : biome tiré selon les
## poids au point (les frontières mélangent les décors), densité du biome, modèle au hasard.

const CATEGORIES := {
	&"trees": &"tree_density",
	&"big_trees": &"tree_density",
	&"rocks": &"rock_density",
	&"bushes": &"bush_density",
	&"grass": &"grass_density",
	&"small": &"small_density",
}


## [chemin res://, échelle du modèle], ou [] si rien ne pousse ici (densité, liste vide).
## min_density : densité plancher (forêt hors carte, pour fermer l'horizon).
static func pick(rng: RandomNumberGenerator, category: StringName, x: float, z: float, min_density: float = 0.0) -> Array:
	var data := MapBiomes.DATA[MapBiomes.random_biome(x, z, rng)]
	var density := maxf(float(data.get(CATEGORIES[category])), min_density)
	if rng.randf() >= density:
		return []
	return from_dict(rng, data.get(category) as Dictionary)


static func from_dict(rng: RandomNumberGenerator, models: Dictionary) -> Array:
	if models.is_empty():
		return []
	var keys := models.keys()
	var model: String = keys[rng.randi() % keys.size()]
	return [model, float(models[model])]
