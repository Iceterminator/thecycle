class_name BiomeData
extends Resource
## Un biome de la carte (un .tres par biome dans data/biomes/, ordre fixé par MapBiomes).
## Modèles du décor : dictionnaires chemin res:// -> échelle (les packs n'ont pas la même taille).
## Densités : part des tirages de MapDecor gardée dans ce biome (0 = aucun, 1 = autant qu'ailleurs).

@export var display_name: String = ""

@export_group("Sol")
@export var grass_color: Color = Color("#4f5a22")   ## sol plat
@export var dirt_color: Color = Color("#9a7d3f")    ## taches de terre
@export var rock_color: Color = Color("#7d766c")    ## pentes fortes
@export var peak_color: Color = Color("#b4aea2")    ## sommets
@export var map_color: Color = Color(0.2, 0.26, 0.16)  ## carte et minimap

@export_group("Relief")
@export var height_scale: float = 1.0   ## multiplie le relief de base
@export var height_offset: float = 0.0  ## monte (+) ou creuse (-) le biome (m)
@export var dunes: float = 0.0          ## amplitude des dunes (m), désert

@export_group("Décor")
@export var tree_density: float = 1.0
@export var rock_density: float = 1.0
@export var bush_density: float = 1.0
@export var grass_density: float = 1.0
@export var small_density: float = 1.0
@export var trees: Dictionary = {}
@export var big_trees: Dictionary = {}  ## forêt hors carte (en plus des arbres)
@export var rocks: Dictionary = {}
@export var bushes: Dictionary = {}
@export var grass: Dictionary = {}
@export var small: Dictionary = {}
@export var water_plants: Dictionary = {}  ## posées à la surface de l'eau (marais)
