class_name QuestDrawData
extends Resource
## Un type de quête tirable au début de chaque partie. Un fichier .tres par type dans
## data/quest_draws/. Le nombre d'exemplaires est tiré entre min_count et max_count ;
## chaque exemplaire prend une variante au hasard (niveau de cristal, par exemple).

@export var display_name: String
@export var kind: StringName  ## « crystal » ou le type de contrat (uplink, extractor, relic, collector, facility, drones)
@export var variants: Array[Resource] = []  ## CrystalData ou ContractData
@export var min_count: int = 1
@export var max_count: int = 1
@export var mandatory: bool = false  ## toujours présent (Cristal)
@export var objective_id: StringName  ## objectif de l'écran Tab (data/objectives/) ; vide = pas de paliers
@export var variant_weights: PackedFloat32Array = PackedFloat32Array()  ## poids par variante (même ordre) ; vide = uniforme
@export var ignores_spacing: bool = false  ## peut être près d'une autre quête (Cristal)
@export var spawn_delay: float = 0.0  ## apparaît à ce temps de partie (s) ; 0 = dès le départ
@export var spawns_with_storm: bool = false  ## n'apparaît qu'au début de la Grande Marée
