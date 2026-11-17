extends Node
## Constantes de partie. Valeurs de départ, à équilibrer (voir docs/DESIGN.md).
## Accès depuis n'importe quel script : Config.MATCH_DURATION, etc.

## Touches déclarées en code (touche physique), en plus de celles de project.godot :
## l'éditeur Godot, s'il est ouvert, peut réécrire project.godot et les effacer.
const CODE_KEY_ACTIONS := {
	&"open_shop": KEY_T,
	&"admin_menu": KEY_0,
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
const MONSTER_TIER_INTERVAL := 5.0 * 60.0
const RESPAWN_DELAY := 5.0
const EVAC_BOARD_TIME := 5.0            # temps à rester dans la soute pour embarquer
const MATCH_RESTART_DELAY := 20.0       # écran de fin, puis nouvelle partie (s)
const MATCH_CLOCK_RESYNC := 5.0         # le serveur renvoie l'horloge aux clients toutes les N s
const EVAC_FIRST_BONUS := 50            # classement : premier joueur embarqué
const EVAC_OTHER_BONUS := 0             # classement : joueurs embarqués suivants
const EVAC_MISSED_PENALTY := 100        # classement perdu si pas à bord au décollage
const EVAC_SKY_HEIGHT := 150.0          # altitude du vaisseau hors de la carte (m)
const EVAC_FLIGHT_TIME := 8.0           # durée de la descente / de la montée (s)
const EVAC_POSITION := Vector3(0, 0.5, 0)  # posé sur l'EvacPad (centre de la carte)
const SPECTATOR_SPEED := 15.0           # vol libre des joueurs embarqués (m/s)

# --- Joueur ---
const WALK_SPEED := 5.0
const SPRINT_SPEED := 7.5
const CROUCH_SPEED := 2.5
const JUMP_VELOCITY := 4.8
const MOUSE_SENSITIVITY := 0.0025

const MAX_HEALTH := 100.0
const SHIELD_PER_TIER := [25.0, 50.0, 100.0, 150.0]  # bouclier max par palier (palier 0 = départ)
const SHIELD_REGEN_DELAY := 10.0         # s sans dégâts avant que le bouclier remonte
const SHIELD_REGEN_FRACTION := 0.05      # part du bouclier max rendue par seconde (1/20)
const HEALTH_REGEN_DELAY := 20.0         # s sans dégâts avant que les PV remontent
const HEALTH_REGEN_RATE := 1.0           # PV par seconde
const STARTING_SHIELD_TIER := 0          # palier au largage (25 de bouclier) ; améliorable en boutique

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
const DROP_POD_LIFETIME := 30.0          # la capsule vide disparaît après ce délai (s)
const KEEP_SHIELD_TIER_ON_DEATH := true  # le palier de bouclier acheté est gardé à la mort

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
const BOUNTY_BASE := 20                  # prime de base (points de classement)
const BOUNTY_SHARE := 0.10               # + cette part des points de classement de la cible

# --- Score ---
const DEATH_FAME_LOSS := 0.20            # 20 % de la Fame perdue à la mort
const MAX_ACTIVE_CONTRACTS := 2
const CONTRACTS_OFFERED := 4
