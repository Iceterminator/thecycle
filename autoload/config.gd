extends Node
## Constantes de partie. Valeurs de départ, à équilibrer (voir docs/DESIGN.md).
## Accès depuis n'importe quel script : Config.MATCH_DURATION, etc.

## Touches déclarées en code (touche physique), en plus de celles de project.godot :
## l'éditeur Godot, s'il est ouvert, peut réécrire project.godot et les effacer.
const CODE_KEY_ACTIONS := {
	&"open_shop": KEY_T,
	&"admin_menu": KEY_0,
	&"show_map": KEY_TAB,           # maintenir : carte, quêtes, classement
	&"equipment": KEY_K,           # menu Équipement (choix du kit)
	&"melee": KEY_V,               # mêlée (coup de poing chargé du Bastion)
}


func _ready() -> void:
	for action: StringName in CODE_KEY_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = CODE_KEY_ACTIONS[action]
		InputMap.action_add_event(action, key)

# --- Réseau ---
const DEFAULT_PORT := 7777
const MAX_PLAYERS := 20

# --- Partie (en secondes) ---
const MATCH_DURATION := 20.0 * 60.0     # décollage de l'évac
const EVAC_LANDING_TIME := 15.0 * 60.0  # l'évac se pose
const EVENT_TIMES := [5.0 * 60.0, 10.0 * 60.0]
const RESPAWN_DELAY := 5.0
const EVAC_BOARD_TIME := 5.0            # temps à rester dans la soute pour embarquer
const MATCH_RESTART_DELAY := 20.0       # écran de fin, puis nouvelle partie (s)
const MATCH_CLOCK_RESYNC := 5.0         # le serveur renvoie l'horloge aux clients toutes les N s
const EVAC_FIRST_BONUS := 50            # Fame : premier joueur embarqué
const EVAC_OTHER_BONUS := 0             # Fame : joueurs embarqués suivants
const EVAC_MISSED_PENALTY := 100        # Fame perdue si pas à bord au décollage
const EVAC_SKY_HEIGHT := 150.0          # altitude du vaisseau hors de la carte (m)
const EVAC_FLIGHT_TIME := 8.0           # durée de la descente / de la montée (s)
const EVAC_POSITION := Vector3(0, 0.5, 0)  # posé sur l'EvacPad (centre de la carte)
const SPECTATOR_SPEED := 15.0           # vol libre des joueurs embarqués (m/s)

# --- Joueur ---
# Vitesse de marche : celle du kit (KitData.move_speed_mps). Sprint = marche x SPRINT_MULTIPLIER.
const SPRINT_MULTIPLIER := 1.9          # référence : combat_rules.sprint_multiplier
const AIR_CONTROL := 0.25               # part de contrôle en l'air (référence : combat_rules.air_control)
const SLIDE_SPEED := 9.0                # glissade (sprint + accroupi) pour tous les kits (m/s)
const SLIDE_DURATION := 0.7
const SLIDE_JUMP_BOOST := 2.5           # saut pendant la glissade : élan vers l'avant (m/s)
const SLIDE_COOLDOWN := 0.8
const CROUCH_SPEED := 2.5
const JUMP_VELOCITY := 4.8
const MOUSE_SENSITIVITY := 0.0025

# PV et bouclier max : ceux du kit (KitController). Valeurs par défaut si le kit n'en a pas.
const KIT_DEFAULT_HEALTH := 500.0
const KIT_DEFAULT_SHIELD := 500.0
const KIT_DEFAULT_SPEED := 3.9
const SHIELD_PER_TIER := [25.0, 50.0, 100.0, 150.0]  # ancien système (boutique), plus utilisé
const SHIELD_REGEN_DELAY := 7.0          # s sans dégâts avant que le bouclier remonte (référence)
const SHIELD_REGEN_RATE := 90.0          # bouclier rendu par seconde (référence)
const HEALTH_REGEN_DELAY := 7.0          # s sans dégâts avant que les PV remontent (référence ; Bastion : son kit)
const HEALTH_REGEN_RATE := 25.0          # PV par seconde (référence ; Bastion : son kit)
const STARTING_SHIELD_TIER := 0          # ancien système, plus utilisé

# --- Combat ---
const DEFAULT_FOV := 90.0
const ADS_FOV := 60.0                    # champ de vision en visée
const HEAD_ZONE_HEIGHT := 0.45           # haut de la capsule compté comme « tête » (m)
const SHOT_ORIGIN_TOLERANCE := 2.0       # écart max (m) entre l'origine d'un tir et les yeux vus par le serveur
const FIRE_BURST_TOLERANCE := 3.0        # tirs d'avance tolérés par le serveur (gigue réseau)
const WEAPON_SWITCH_TIME := 0.4          # pas de tir pendant le changement d'arme (s)

# --- Loot et inventaire (valeurs provisoires, à revoir avec la boucle complète) ---
const BASE_WEAPON := &"k28_autopistol"   # équipement de départ (emplacement 1), jamais perdu
const HEAL_ITEM := &"medkit"             # consommable de la touche 3
const SHIELD_ITEM := &"shield_cell"      # consommable de la touche 4
const MAX_MEDKITS := 3
const MAX_SHIELD_CELLS := 3
const INTERACT_RANGE := 2.5              # portée de l'interaction (E), en m
const INTERACT_SERVER_MARGIN := 1.0      # tolérance côté serveur (latence, centre de l'objet)
const PICKUP_LIFETIME := 180.0           # un objet au sol disparaît après ce délai (s)
const LOOT_SCATTER_RADIUS := 1.2         # éparpillement du loot autour d'une caisse / d'un mort
const DEATH_CREDITS_LOSS := 0.5          # part des crédits perdue à la mort (va au tueur)

# --- Monstres ---
const MONSTER_KILLER_ID := -1            # killer_id quand un joueur est tué par un monstre
const CAMP_RESPAWN_DELAY := 60.0         # un camp vidé réapparaît après ce délai (tests)
const STORM_KILLER_ID := -2              # killer_id quand un joueur est tué par la tempête
## Niveau des monstres (1 au début) : il monte à ces temps de partie. Appliqué aux monstres qui
## apparaissent ensuite (camps repeuplés, vagues), pas à ceux déjà en vie. Index 0 = niveau 1.
const MONSTER_LEVEL_TIMES := [5.0 * 60.0, 10.0 * 60.0]
const MONSTER_LEVEL_HEALTH_MULT := [1.0, 1.25, 1.5]
const MONSTER_LEVEL_DAMAGE_MULT := [1.0, 1.15, 1.3]
const MONSTER_LEVEL_CREDITS_MULT := [1.0, 1.5, 2.0]
## À ce temps de partie, les cristaux pas encore commencés montent d'un niveau (le max reste max).
const CRYSTAL_UPGRADE_TIME := 10.0 * 60.0

# --- Tempête (façon zone qui se referme ; phases dans data/storm/) ---
const STORM_START_RADIUS := 145.0        # zone sûre de départ : toute la carte (200 x 200 m)
const STORM_TICK := 1.0                  # les dégâts tombent toutes les N s
const STORM_MONSTER_MULT := 1.3          # monstres dans la tempête : détection et vitesse de course

# --- Boutique et largages (valeurs provisoires) ---
const DROP_POD_FALL_TIME := 3.0          # délai entre l'achat et l'atterrissage de la capsule (s)
const DROP_POD_DISTANCE := 3.0           # la capsule tombe à cette distance devant le joueur (m)
const DROP_POD_HEIGHT := 60.0            # hauteur de départ de la capsule (m)

# --- Menu admin (touche 0, tests) ---
const ADMIN_MENU_ENABLED := true         # false = le serveur refuse toutes les demandes admin
const ADMIN_SPAWN_DISTANCE := 3.0        # les objets apparaissent à cette distance devant le joueur (m)
const ADMIN_CRYSTAL_DISTANCE := 7.0      # distance pour un cristal (il est large)
const ADMIN_MAX_CREDITS := 100000        # montant max par demande
const ADMIN_MAX_TIME_SKIP := 1200.0      # avance max du temps par demande (s)
## Temporaire : affiche le nom des armes dans le jeu d'origine (WeaponData.reference_name)
## au lieu de nos noms, pour se repérer pendant les tests. Mettre à false pour nos noms.
const SHOW_REFERENCE_WEAPON_NAMES := true

# --- Écran Tab (carte) ---
const MAP_REVEAL_RADIUS := 40.0          # quêtes et monstres montrés (carte, minimap, textes flottants) à cette distance (m)
const MINIMAP_HALF_SIZE := 45.0          # la minimap montre ± cette distance autour du joueur (m)

# --- Limites de la carte ---
const MAP_HALF_SIZE := 100.0             # la carte fait 200 x 200 m, centrée sur l'origine
const KILL_Y := -15.0                    # en dessous de cette hauteur : mort (plus de chute infinie)
const FALL_KILLER_ID := -3               # killer_id quand un joueur meurt en tombant hors de la carte
const DROP_POD_LIFETIME := 30.0          # la capsule vide disparaît après ce délai (s)
const KEEP_SHIELD_TIER_ON_DEATH := true  # ancien système, plus utilisé

# --- Kits (étape 8b) ---
const DEFAULT_KIT := &"basic_prospector_kit"  # kit au premier largage
const KIT_CHANGE_WINDOW := 30.0          # s après le largage / la réapparition pour changer de kit (K)
const KIT_LEVEL_XP := [100, 250, 450, 700, 1000]  # XP cumulée pour les niveaux 2 à 6 (valeurs de départ)
const KIT_XP_PLAYER_KILL := 100
const KIT_XP_MONSTER_KILL := 10
const KIT_XP_PER_OBJECTIVE_POINT := 1.0  # XP par point d'objectif gagné
const KIT_XP_PER_FAME := 1.0             # XP par point de Fame gagné
const MELEE_RANGE := 2.5                 # portée du coup de poing chargé (m)

# --- Quêtes : cristal + foreuse (valeurs provisoires) ---
const CRYSTAL_ACTIVATE_TIME := 3.0       # maintenir E pour lancer la foreuse (s)
const CRYSTAL_EXTRACT_TIME := 5.0        # maintenir E pour extraire une fois les vagues finies (s)
const CRYSTAL_WAVE_DELAY := 4.0          # pause avant chaque vague (s)
const CRYSTAL_WAVE_SPAWN_MIN := 16.0     # les monstres apparaissent entre ces distances (m)
const CRYSTAL_WAVE_SPAWN_MAX := 22.0
const CRYSTAL_RESET_DELAY := 15.0        # foreuse détruite : le cristal redevient utilisable après (s)
const CRYSTAL_RESPAWN_DELAY := 120.0     # cristal extrait : il réapparaît après (tests)
const HOLD_SERVER_TOLERANCE := 0.85      # le serveur accepte un maintien de E à 85 % de la durée (latence)

# --- Contrats (valeurs provisoires) ---
const CONTRACT_RESET_DELAY := 90.0       # station / drones : réutilisables après (s)
const COLLECT_HOLD_TIME := 1.5           # maintenir E pour récolter / déposer / envoyer (s)
const LUMICEP_RESPAWN_TIME := 60.0       # les Lumicèpes repoussent sur leurs spots (s)
const TICK_INTERVAL := 24.0              # Tiques : une toutes les (TICK_INTERVAL / Lumicèpes portés) s
const TICK_MIN_INTERVAL := 4.0
const BOUNTY_INTERVAL := 90.0            # une prime est posée toutes les… (s)
const BOUNTY_DURATION := 120.0           # survivre ce temps = la cible touche la moitié de la prime
const BOUNTY_BASE := 20                  # prime de base (Fame)
const BOUNTY_SHARE := 0.10               # + cette part des Fame de la cible

# --- Score ---
const PLAYER_KILL_FAME := 50            # Fame gagnée pour chaque joueur tué (on ne perd rien en mourant)
const MAX_ACTIVE_CONTRACTS := 2
const CONTRACTS_OFFERED := 4
