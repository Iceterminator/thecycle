class_name ContractData
extends Resource
## Réglages d'un contrat (relais, extracteur, cœur stellaire, collecteur, station, drones…).
## Un fichier .tres par contrat dans data/contracts/. Chaque script de contrat n'utilise
## que les champs qui le concernent (voir le commentaire de chaque script).

@export var id: StringName
@export var display_name: String
@export var color: Color = Color(1, 0.85, 0.3)
## Faction du contrat (WeaponData.Faction) : la Fame gagnée devient de la réputation (étape 9).
@export var faction: int = 0

@export_group("Interaction")
@export var hold_time: float = 3.0              ## maintenir E (s)
@export var hack_time: float = 6.0              ## extracteur : maintenir E pour pirater l'extracteur d'un rival (s)

@export_group("Récompense")
@export var track: ObjectiveTrack                ## objectif à paliers (relais, Ambrine, cœur, collecteurs) ; vide = Fame directs
@export var points: int = 100                   ## points ponctuels / par unité (d'objectif si `track`, sinon de Fame)
@export var points_per_second: float = 0.0      ## gain continu (relais, cœur, extracteur)
@export var level_rates: PackedFloat32Array = PackedFloat32Array()  ## extracteur : pts/s de chaque niveau (vide = points_per_second)
@export var level_times: PackedFloat32Array = PackedFloat32Array()  ## extracteur : secondes tenues pour atteindre chaque niveau

@export_group("Objectif")
@export var count: int = 3                      ## nb de drones / de nœuds
@export var resource_item: ItemData             ## collecteur : ressource acceptée
@export var target_health: float = 400.0        ## PV d'un drone
@export var radius: float = 8.0                 ## taille du site

@export_group("Monstres")
@export var waves: Array[CampData] = []
@export var monster_health_mult: float = 1.0
@export var monster_damage_mult: float = 1.0

@export_group("Drones")
@export var trigger_radius: float = 60.0        ## un joueur à cette distance du site fait apparaître la meute (m)
@export var pack: CampData                      ## meute déjà sur place, qui attaque les drones
@export var launch_time: float = 60.0           ## durée du décollage du porteur (s)
@export var carrier_health: float = 1500.0      ## PV du porteur pendant son décollage
@export var launch_fame: int = 3                ## Fame du joueur qui a déclenché un décollage réussi
@export var condition_thresholds: PackedFloat32Array = PackedFloat32Array([0.8, 0.4])  ## part de PV au-dessus de laquelle : intact, bon
@export var condition_points: PackedInt32Array = PackedInt32Array([100, 70, 40])       ## points d'objectif : intact, bon, endommagé
@export var condition_names: PackedStringArray = PackedStringArray(["intact", "bon", "endommagé"])

@export_group("Station centrale")
@export var central_unlock_count: int = 2       ## stations activées dans la partie pour ouvrir la station centrale
@export var zone_radius: float = 10.0           ## rayon de la zone qui rapporte des points (m)
@export var active_time: float = 300.0          ## durée d'ouverture (s)
@export var guard_interval: float = 30.0        ## délai entre deux Gardiens (s)
@export var guard_max: int = 6                  ## Gardiens vivants au maximum
@export var guards: Array[MonsterData] = []     ## Gardiens tirés au hasard
