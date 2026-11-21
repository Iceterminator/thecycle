class_name EconomyRules
extends Resource
## Règles de jeu : Fame, prix, XP de kit, réputation.
## Valeurs dans res://data/rules/economy.tres (accès : Config.economy.<champ>).

@export var evac_pad_clear_fame: int  ## Fame du joueur qui tue le dernier monstre de la plateforme d'évac
@export var evac_first_bonus: int  ## Fame : premier joueur embarqué
@export var evac_other_bonus: int  ## Fame : joueurs embarqués suivants
@export var evac_missed_penalty: int  ## Fame perdue si pas à bord au décollage
@export var player_kill_fame: int  ## Fame par joueur tué (on ne perd rien en mourant)
@export var bounty_base: int  ## prime de base (Fame)
@export var bounty_share: float  ## + cette part des Fame de la cible
@export var death_credits_loss: float  ## part des crédits perdue à la mort (va au tueur)
@export var weapon_boost_prices: Array[int] = []  ## prix des paliers de boost 1, 2, 3
@export var weapon_replace_hold_time: float = 2.0  ## maintien (s) pour remplacer une arme portée par une arme au sol
@export var ability_price: int  ## achat d'une capacité en boutique
@export var ability_upgrade_price: int  ## crédits par amélioration de capacité
@export var ability_max_upgrades: int  ## améliorations max d'une capacité
@export var weapon_fallback_price: int  ## prix d'une arme sans prix dans ses données
@export var kit_level_xp: Array[int] = []  ## XP cumulée pour les niveaux de kit 2 à 6
@export var kit_xp_player_kill: int  ## XP de kit par joueur tué
@export var kit_xp_monster_kill: int  ## XP de kit par monstre tué
@export var kit_xp_monster_scale: float = 0.05  ## XP de kit d'un monstre = son xp (MonsterData) × ce facteur
@export var kit_xp_per_objective_point: float  ## XP de kit par point d'objectif
@export var kit_xp_per_fame: float  ## XP de kit par point de Fame
@export var rep_levels: Array[int] = []  ## réputation cumulée pour les niveaux de faction 1 à 10
@export var preferred_faction_bonus: float  ## bonus de réputation avec la faction de prédilection
