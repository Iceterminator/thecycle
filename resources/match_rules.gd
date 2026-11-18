class_name MatchRules
extends Resource
## Règles de jeu : calendrier de partie, monstres, cristaux, contrats, primes.
## Valeurs dans res://data/rules/match.tres (accès : Config.match_rules.<champ>).

@export var match_duration: float  ## décollage de l'évac (s)
@export var evac_announce_time: float  ## annonce de l'évac ; des monstres occupent la plateforme (s)
@export var evac_landing_time: float  ## arrivée de l'évac, si la plateforme est nettoyée (s)
@export var evac_board_time: float  ## temps à rester dans la soute pour embarquer (s)
@export var respawn_delay: float  ## délai de réapparition (s)
@export var match_restart_delay: float  ## écran de fin, puis nouvelle partie (s)
@export var kit_change_window: float  ## s après le largage pour changer de kit
@export var camp_respawn_delay: float  ## un camp vidé réapparaît après (s)
@export var monster_level_times: Array[float] = []  ## temps de partie où les monstres montent de niveau (s)
@export var monster_level_health_mult: Array[float] = []  ## PV des monstres par niveau
@export var monster_level_damage_mult: Array[float] = []  ## dégâts des monstres par niveau
@export var monster_level_credits_mult: Array[float] = []  ## crédits des monstres par niveau
@export var storm_monster_mult: float  ## monstres pendant la Grande Marée : détection et vitesse
@export var crystal_upgrade_time: float  ## les cristaux pas commencés montent d'un niveau (s)
@export var crystal_activate_time: float  ## maintenir E pour lancer la foreuse (s)
@export var crystal_extract_time: float  ## maintenir E pour extraire (s)
@export var crystal_wave_delay: float  ## pause avant chaque vague (s)
@export var crystal_wave_spawn_min: float  ## distance min d'apparition des vagues (m)
@export var crystal_wave_spawn_max: float  ## distance max d'apparition des vagues (m)
@export var crystal_reset_delay: float  ## foreuse détruite : cristal réutilisable après (s)
@export var crystal_respawn_delay: float  ## cristal extrait : réapparaît après (s)
@export var contract_reset_delay: float  ## station / drones réutilisables après (s)
@export var collect_hold_time: float  ## maintenir E pour récolter / déposer / envoyer (s)
@export var lumicep_respawn_time: float  ## les Lumicèpes repoussent après (s)
@export var tick_interval: float  ## Tiques : une toutes les (intervalle / Lumicèpes portés) s
@export var tick_min_interval: float  ## intervalle min entre deux Tiques (s)
@export var bounty_interval: float  ## une prime est posée toutes les (s)
@export var bounty_duration: float  ## survivre ce temps = la cible touche la moitié de la prime (s)
@export var max_active_contracts: int  ## contrats actifs max
@export var contracts_offered: int  ## contrats proposés
