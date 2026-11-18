class_name CombatRules
extends Resource
## Règles de jeu : déplacement, PV par défaut, régénération, capacités, à terre.
## Valeurs dans res://data/rules/combat.tres (accès : Config.combat.<champ>).

@export var sprint_multiplier: float  ## sprint = marche × ce facteur
@export var air_control: float  ## part de contrôle en l'air
@export var slide_speed: float  ## vitesse de glissade (m/s)
@export var slide_duration: float  ## durée de glissade (s)
@export var slide_jump_boost: float  ## saut pendant la glissade : élan (m/s)
@export var slide_cooldown: float  ## délai entre deux glissades (s)
@export var crouch_speed: float  ## vitesse accroupi (m/s)
@export var jump_velocity: float  ## vitesse de saut (m/s)
@export var kit_default_health: float  ## PV si le kit n'en a pas
@export var kit_default_shield: float  ## bouclier si le kit n'en a pas
@export var kit_default_speed: float  ## vitesse de marche si le kit n'en a pas (m/s)
@export var shield_regen_delay: float  ## s sans dégâts avant que le bouclier remonte
@export var shield_regen_rate: float  ## bouclier rendu par seconde
@export var health_regen_delay: float  ## s sans dégâts avant que les PV remontent
@export var health_regen_rate: float  ## PV rendus par seconde
@export var melee_range: float  ## portée du coup de poing chargé (m)
@export var ability_aim_range: float  ## frappes : portée de visée (m)
@export var ability_place_range: float  ## tourelle : portée de pose (m)
@export var grenade_throw_speed: float  ## grenades et sphères lancées (m/s)
@export var warp_bomb_distance: float  ## bombe de distorsion : sortie à cette distance (m)
@export var snare_range: float  ## entrave : portée (m)
@export var ward_health: float  ## balise d'écoute : PV
@export var ward_lifetime: float  ## balise d'écoute : durée de vie (s)
@export var scan_reveal_time: float  ## balise : un joueur repéré reste sur la carte (s)
@export var cloak_monster_ignore: float  ## camouflage à partir duquel les monstres ne voient plus le joueur
@export var heal_beam_self_cost: int  ## rayon vital : charges de l'auto-soin
@export var heal_beam_self_cooldown: float  ## rayon vital : délai entre deux auto-soins (s)
@export var scanner_range: float  ## scanner directionnel : alarme de proximité (m)
@export var downed_time: float  ## s à terre avant de mourir
@export var downed_health: float  ## PV à terre
@export var downed_speed: float  ## vitesse à terre (m/s)
@export var revive_time: float  ## maintenir E pour relever un allié (s)
@export var revive_health_ratio: float  ## relevé avec cette part de ses PV max
