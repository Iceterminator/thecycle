class_name QuestDrawData
extends Resource
## Un type de quête tirable au début de chaque partie. Un fichier .tres par type dans
## data/quest_draws/. Le nombre d'exemplaires est tiré entre min_count et max_count ;
## chaque exemplaire prend une variante au hasard (niveau de cristal, par exemple).

@export var display_name: String
@export var kind: StringName  ## « crystal » ou le type de contrat (uplink, extractor, collector, facility, drones)
@export var variants: Array[Resource] = []  ## CrystalData ou ContractData
@export var min_count: int = 1
@export var max_count: int = 1
@export var mandatory: bool = false  ## toujours présent (Cristal)
@export var objective_id: StringName  ## objectif de l'écran Tab (data/objectives/) ; vide = pas de paliers
@export var variant_weights: PackedFloat32Array = PackedFloat32Array()  ## poids par variante (même ordre) ; vide = uniforme
@export var ignores_spacing: bool = false  ## peut être près d'une autre quête (Cristal)
@export var spawn_delay: float = 0.0  ## apparaît à ce temps de partie (s) ; 0 = dès le départ

@export_group("Filons")
## Chaque exemplaire tiré (min_count-max_count) devient un filon : cluster_min à cluster_max
## quêtes groupées autour de l'emplacement (Ambrine). 1 = une seule quête par emplacement.
@export var cluster_min: int = 1
@export var cluster_max: int = 1
## m autour du centre du filon. Le décor est dégagé sur 13 m autour des emplacements de quête
## (MapDecorPlan.CLEAR_RADIUS) mais un gros rocher peut déborder de 2-3 m : rester vers 9 m.
@export var cluster_radius: float = 9.0
@export var cluster_gap: float = 1.0  ## m minimum entre deux quêtes d'un même filon
@export var cluster_max_slope: float = 0.5  ## pente maxi d'une quête du filon (tan de l'angle : 0,5 ≈ 27°)
