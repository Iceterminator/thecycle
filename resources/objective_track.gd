class_name ObjectiveTrack
extends Resource
## Progression d'un objectif (Forage, Relais, Ambrine, Cœur stellaire, Biomasse, Lumicèpes).
## Le joueur cumule des POINTS D'OBJECTIF propres à cet objectif ; chaque palier atteint
## lui donne des de la FAME. Un fichier .tres par objectif dans data/objectives/.
## Après le dernier palier, les paliers continuent avec le même écart et la même récompense
## que le dernier (on ne plafonne pas).

@export var id: StringName
@export var display_name: String
@export var color: Color = Color.WHITE
## Faction de l'objectif (WeaponData.Faction) : la Fame de ses paliers devient de la réputation.
@export var faction: int = 0
@export var thresholds: PackedInt32Array = PackedInt32Array([100, 250, 500])  ## points d'objectif cumulés
@export var rewards: PackedInt32Array = PackedInt32Array([10, 15, 25])        ## Fame par palier


## Seuil du palier n (0 = premier), y compris au-delà de la liste.
func threshold(n: int) -> int:
	if n < thresholds.size():
		return thresholds[n]
	var last := thresholds[thresholds.size() - 1]
	var gap := last - (thresholds[thresholds.size() - 2] if thresholds.size() > 1 else 0)
	return last + gap * (n - thresholds.size() + 1)


func reward(n: int) -> int:
	return rewards[mini(n, rewards.size() - 1)]


## Nombre de paliers atteints avec `points` points d'objectif.
func tiers_reached(points: int) -> int:
	var n := 0
	while points >= threshold(n):
		n += 1
	return n
