class_name MonsterData
extends Resource
## Données d'un type de monstre. Un monstre = un fichier .tres dans data/monsters/.

@export var id: StringName
@export var display_name: String

@export_group("Vie")
@export var max_health: float = 60.0
@export var regen_delay_s: float = -1.0         ## s sans dégâts avant la régénération (-1 = aucune)
@export var regen_per_s: float = 0.0           ## PV rendus par seconde une fois la régénération lancée

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
@export var credits: int = 10                  ## crédits versés au tueur
@export var biomass_drop: int = 0              ## biomasse lâchée au sol (contrat Biomasse)
@export var xp: int = 0                        ## XP du jeu d'origine ; XP de kit donnée = xp × Config.economy.kit_xp_monster_scale

@export_group("Apparence")
@export var radius: float = 0.35
@export var height: float = 0.9
@export var color: Color = Color(0.5, 0.3, 0.6)

@export_group("Tir à distance")
@export var ranged: bool = false               ## true : tire des projectiles (attack_range = portée de tir)
@export var projectile_speed: float = 22.0     ## m/s : assez lent pour être esquivé
@export var min_range: float = 6.0             ## recule si un joueur s'approche plus près
@export var ranged_burst_count: int = 1        ## projectiles par attaque
@export var ranged_burst_interval_s: float = 0.08  ## délai entre deux projectiles d'une salve (s)

@export_group("Modèle 3D")
## Modèle animé (animations Idle, Walk, Run, Attack, Hit si présentes) ; sans modèle : capsule colorée.
@export var model: PackedScene
@export var model_yaw_deg: float = 180.0       ## rotation pour que le modèle regarde vers -Z
@export var model_height_mult: float = 1.0     ## hauteur du modèle = height × ce facteur
