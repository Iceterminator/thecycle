class_name CrystalData
extends Resource
## Un niveau de cristal (quête « foreuse »). Un fichier .tres par niveau dans data/quests/.
## Chaque vague réutilise un CampData (composition de monstres).

@export var level: int = 1
@export var display_name: String = "Cristal"
@export var difficulty_name: String = "facile"
@export var color: Color = Color(0.3, 0.9, 1.0)   ## teinte des prismes (appliquée par le jeu)
@export var model: PackedScene                   ## modèle 3D : socle + maillage « Cristal »

@export_group("Vagues")
@export var waves: Array[CampData] = []
@export var monster_health_mult: float = 1.0   ## vagues plus dures : monstres plus résistants
@export var monster_damage_mult: float = 1.0   ## … et qui frappent plus fort

@export_group("Foreuse")
@export var drill_health: float = 800.0

@export_group("Récompense")
@export var objective_points: int = 100       ## points d'objectif « Forage » gagnés à l'extraction
@export var track: ObjectiveTrack                ## objectif « Forage » (paliers -> Fame)
