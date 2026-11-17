class_name ContractData
extends Resource
## Réglages d'un contrat (relais, extracteur, cœur stellaire, collecteur, station, drones…).
## Un fichier .tres par contrat dans data/contracts/. Chaque script de contrat n'utilise
## que les champs qui le concernent (voir le commentaire de chaque script).

@export var id: StringName
@export var display_name: String
@export var color: Color = Color(1, 0.85, 0.3)

@export_group("Interaction")
@export var hold_time: float = 3.0              ## maintenir E (s)

@export_group("Récompense")
@export var track: ObjectiveTrack                ## objectif à paliers (relais, Ambrine, cœur, collecteurs) ; vide = Fame directs
@export var points: int = 100                   ## points ponctuels / par unité (d'objectif si `track`, sinon de Fame)
@export var points_per_second: float = 0.0      ## gain continu (relais, cœur, extracteur)
@export var points_growth: float = 0.0          ## extracteur : + pts/s gagnés par minute tenue

@export_group("Objectif")
@export var count: int = 3                      ## nb de drones / de nœuds
@export var resource_item: ItemData             ## collecteur : ressource acceptée
@export var target_health: float = 400.0        ## PV d'un drone
@export var duration: float = 45.0              ## durée à tenir (drones)
@export var radius: float = 8.0                 ## taille du site

@export_group("Monstres")
@export var waves: Array[CampData] = []
@export var monster_health_mult: float = 1.0
@export var monster_damage_mult: float = 1.0
