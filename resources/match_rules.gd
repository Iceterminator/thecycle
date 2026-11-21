class_name MatchRules
extends Resource
## Règles de jeu : calendrier de partie, monstres, cristaux, contrats.
## Valeurs dans res://data/rules/match.tres (accès : Config.match_rules.<champ>).

@export var match_duration: float  ## décollage de l'évac (s)
@export var evac_announce_time: float  ## annonce de l'évac ; des monstres occupent la plateforme (s)
@export var evac_landing_time: float  ## arrivée de l'évac, si la plateforme est nettoyée (s)
@export var evac_board_time: float  ## temps à rester dans la soute pour embarquer (s)
@export var respawn_delay: float  ## délai de réapparition (s)
@export var match_restart_delay: float  ## écran de fin, puis nouvelle partie (s)
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
@export var max_active_contracts: int  ## contrats actifs max
@export var contracts_offered: int  ## contrats proposés
@export var drawn_quest_types: int = 5  ## types de quêtes tirés en plus du Cristal, à chaque partie
@export var lumicep_spots_per_collector: int = 5  ## points de Lumicèpes par collecteur de Lumicèpes tiré
@export var always_objectives: PackedStringArray = []  ## objectifs actifs à chaque partie, sans quête tirée (ex. biomasse : comptée au ramassage)
@export var quest_min_spacing: float = 60.0  ## distance min entre deux quêtes tirées (m) ; les cristaux l'ignorent
@export var quest_spread_distance_weight: float = 1.0  ## répartition : points par mètre jusqu'au plus proche exemplaire du même type
@export var quest_spread_new_quadrant_bonus: float = 60.0  ## répartition : bonus si le quart de carte n'a pas encore ce type
@export var quest_spread_opposite_bonus: float = 60.0  ## répartition : bonus pour le quart opposé au 1er exemplaire du type
@export var quest_spread_load_penalty: float = 25.0  ## répartition : malus par quête déjà présente dans le quart
@export var briefing_time: float = 60.0  ## salle de briefing : durée max après le premier « prêt » (s)
@export var map_ready_timeout: float = 30.0  ## départ du briefing : attente max des cartes (serveur + joueurs de la salle), puis on part quand même (s)
@export var drop_edge_min: float = 15.0  ## point de largage : distance min aux murs de la carte (m)
@export var drop_edge_max: float = 30.0  ## point de largage : distance max aux murs de la carte (m)
@export var drop_camp_distance: float = 20.0  ## point de largage : distance min à un camp de monstres (m)
@export var drop_clear_radius: float = 2.0  ## point de largage : rayon libre de décor solide (m)
@export var drop_candidates: int = 120  ## points candidats tirés dans la bande avant de choisir
@export var drop_squad_spacing: float = 2.5  ## écart entre deux membres d'une escouade au largage (m)
@export var drop_pod_height: float = 250.0  ## hauteur de départ de la capsule au-dessus du sol (m)
@export var drop_pod_fall_time: float = 10.0  ## durée de la descente (s)
@export var drop_pod_open_delay: float = 5.0  ## capsule fermée au sol avant l'ouverture (s)
@export var uplink_first_time: float = 114.0  ## relais tournant : le 1er s'active à ce temps de partie (s)
@export var uplink_active_time: float = 362.0  ## relais tournant : durée d'activité de chaque relais (s)
@export_group("Événements du jeu d'origine")
@export var surge_lead: float = 120.0  ## surtension : annoncée et ouverte (s) avant le début de la Grande Marée
@export var surge_count: int = 3  ## surtension : nombre de cristaux posés
@export var surge_lifetime: float = 90.0  ## surtension : durée de vie des cristaux (s)
@export var surge_points: int = 400  ## surtension : points d'objectif d'un cristal ramassé
@export var surge_min_player_distance: float = 60.0  ## cristaux et Alpha : emplacements d'abord à cette distance des joueurs (m)
@export var alpha_time: float = 720.0  ## temps de partie où l'Alpha apparaît (s)
@export var alpha_steps: int = 4  ## Alpha : tranches de PV max infligés qui rapportent de la Fame (4 = par 25 %)
@export var alpha_step_fame: int = 25  ## Alpha : Fame par tranche
@export var alpha_kill_fame: int = 25  ## Alpha : Fame de plus pour le joueur qui l'achève
