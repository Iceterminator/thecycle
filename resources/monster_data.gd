class_name MonsterData
extends Resource
## Données d'un type de monstre. Un monstre = un fichier .tres dans data/monsters/.

@export var id: StringName
@export var display_name: String

@export_group("Vie")
@export var max_health: float = 60.0

@export_group("Déplacement")
@export var walk_speed: float = 2.5            ## patrouille
@export var run_speed: float = 6.0             ## poursuite

@export_group("Comportement")
@export var detection_radius: float = 16.0     ## voit un joueur à cette distance (avec ligne de vue)
@export var lose_radius: float = 28.0          ## abandonne si la cible est plus loin
@export var leash_radius: float = 32.0         ## rentre au camp s'il s'en éloigne trop

@export_group("Attaque")
@export var attack_range: float = 1.6
@export var attack_damage: float = 8.0
@export var attack_windup: float = 0.35        ## préparation visible avant le coup (s)
@export var attack_cooldown: float = 1.0       ## délai avant le coup suivant (s)
@export var post_hit_pause: float = 0.6        ## après un coup réussi : s'arrête et recule un peu (s)

@export_group("Récompense")
@export var credits: int = 10                  ## crédits lâchés à la mort

@export_group("Apparence")
@export var radius: float = 0.35
@export var height: float = 0.9
@export var color: Color = Color(0.5, 0.3, 0.6)
