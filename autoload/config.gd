extends Node
## Constantes de partie. Valeurs de départ, à équilibrer (voir docs/DESIGN.md).
## Accès depuis n'importe quel script : Config.MATCH_DURATION, etc.

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

# --- Joueur ---
const WALK_SPEED := 5.0
const SPRINT_SPEED := 7.5
const CROUCH_SPEED := 2.5
const JUMP_VELOCITY := 4.8
const MOUSE_SENSITIVITY := 0.0025

const MAX_HEALTH := 100.0
const SHIELD_PER_TIER := [0.0, 50.0, 100.0, 150.0]
const SHIELD_REGEN_DELAY := 5.0
const SHIELD_REGEN_RATE := 25.0          # points par seconde
const STARTING_SHIELD_TIER := 1          # palier de bouclier au largage (0 à 3)

# --- Combat ---
const DEFAULT_FOV := 90.0
const ADS_FOV := 60.0                    # champ de vision en visée
const HEAD_ZONE_HEIGHT := 0.45           # haut de la capsule compté comme « tête » (m)
const SHOT_ORIGIN_TOLERANCE := 2.0       # écart max (m) entre l'origine d'un tir et les yeux vus par le serveur
const FIRE_BURST_TOLERANCE := 3.0        # tirs d'avance tolérés par le serveur (gigue réseau)

# --- Score ---
const DEATH_FAME_LOSS := 0.20            # 20 % de la Fame perdue à la mort
const MAX_ACTIVE_CONTRACTS := 2
const CONTRACTS_OFFERED := 4
