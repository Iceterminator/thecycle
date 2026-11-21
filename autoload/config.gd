extends Node
## Réglages techniques globaux. Les règles de jeu (prix, Fame, timings, stats) sont dans data/rules/.
## Accès depuis n'importe quel script : Config.match_rules.match_duration, etc.

const SettingsStore := preload("res://systems/settings/settings_store.gd")  ## touches et HUD du joueur
const QualiteGraphique := preload("res://systems/rendu/qualite_graphique.gd")

## Touches déclarées en code (touche physique), en plus de celles de project.godot :
## l'éditeur Godot, s'il est ouvert, peut réécrire project.godot et les effacer.
const CODE_KEY_ACTIONS := {
	&"open_shop": KEY_T,
	&"admin_menu": KEY_0,
	&"show_map": KEY_TAB,           # maintenir : carte, quêtes, classement
	&"melee": KEY_V,               # mêlée (coup de poing chargé du Bastion)
	&"ability_1": KEY_Q,           # capacité 1 (étape 8c)
	&"ability_2": KEY_F,           # capacité 2
	&"pact": KEY_P,                # menu Pactes (étape 8e)
	&"contracts": KEY_J,            # tableau de contrats
}


func _ready() -> void:
	for action: StringName in CODE_KEY_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = CODE_KEY_ACTIONS[action]
		InputMap.action_add_event(action, key)
	SettingsStore.load_and_apply()
	QualiteGraphique.appliquer_global()

## Règles de jeu (équilibrage) : dans data/rules/, chargées ici.
var economy: EconomyRules = preload("res://data/rules/economy.tres")
var match_rules: MatchRules = preload("res://data/rules/match.tres")
var combat: CombatRules = preload("res://data/rules/combat.tres")
var start_loadout: StartLoadout = preload("res://data/rules/start_loadout.tres")

# --- Réseau ---
const DEFAULT_PORT := 7777
const MAX_PLAYERS := 20
const NET_TIMEOUT_MIN_MS := 30000      # délai ENet avant de couper une connexion muette (min / max, ms) :
const NET_TIMEOUT_MAX_MS := 60000      # la construction de la carte bloque le jeu plusieurs secondes

# --- Partie (en secondes) ---
const EVAC_PAD_CAMP := "res://data/camps/evac_pad.tres"  # monstres qui bloquent la plateforme ("" = aucun)
const MATCH_CLOCK_RESYNC := 5.0         # le serveur renvoie l'horloge aux clients toutes les N s
const EVAC_SKY_HEIGHT := 150.0          # altitude du vaisseau hors de la carte (m)
const EVAC_FLIGHT_TIME := 8.0           # durée de la descente / de la montée (s)
const EVAC_POSITION := Vector3(0, 0.5, 0)  # posé sur l'EvacPad (centre de la carte)
const SPECTATOR_SPEED := 15.0           # vol libre des joueurs embarqués (m/s)

# --- Joueur ---
# Vitesse de marche : celle du kit (KitData.move_speed_mps). Sprint = marche x SPRINT_MULTIPLIER.
const MOUSE_SENSITIVITY := 0.0025

# PV et bouclier max : ceux du kit (KitController). Valeurs par défaut si le kit n'en a pas.
const SHIELD_PER_TIER := [25.0, 50.0, 100.0, 150.0]  # ancien système (boutique), plus utilisé
const STARTING_SHIELD_TIER := 0          # ancien système, plus utilisé

# --- Combat ---
const DEFAULT_FOV := 90.0
const ADS_FOV := 60.0                    # champ de vision en visée
const HEAD_ZONE_HEIGHT := 0.45           # haut de la capsule compté comme « tête » (m)
const SHOT_ORIGIN_TOLERANCE := 2.0       # écart max (m) entre l'origine d'un tir et les yeux vus par le serveur
const FIRE_BURST_TOLERANCE := 3.0        # tirs d'avance tolérés par le serveur (gigue réseau)
const WEAPON_SWITCH_TIME := 0.4          # pas de tir pendant le changement d'arme (s)

# --- Loot et inventaire (valeurs provisoires, à revoir avec la boucle complète) ---
const INTERACT_RANGE := 2.5              # portée de l'interaction (E), en m
const INTERACT_SERVER_MARGIN := 1.0      # tolérance côté serveur (latence, centre de l'objet)
const PICKUP_LIFETIME := 180.0           # un objet au sol disparaît après ce délai (s)
const LOOT_SCATTER_RADIUS := 1.2         # éparpillement du loot autour d'une caisse / d'un mort

# --- Monstres ---
const MONSTER_KILLER_ID := -1            # killer_id quand un joueur est tué par un monstre
## Niveau des monstres (1 au début) : il monte à ces temps de partie. Appliqué aux monstres qui
## apparaissent ensuite (camps repeuplés, vagues), pas à ceux déjà en vie. Index 0 = niveau 1.
## À ce temps de partie, les cristaux pas encore commencés montent d'un niveau (le max reste max).

# --- Grande Marée (tempête globale ; data/storm/) ---

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
const SHOW_REFERENCE_WEAPON_NAMES := false

# --- Écran Tab (carte) ---
const MAP_REVEAL_RADIUS := 40.0          # quêtes et monstres montrés (carte, minimap, textes flottants) à cette distance (m)
const MINIMAP_HALF_SIZE := 45.0          # la minimap montre ± cette distance autour du joueur (m)

# --- Limites de la carte ---
const MAP_HALF_SIZE := 150.0             # la carte fait 300 x 300 m, centrée sur l'origine
const MAP_BUILD_BUDGET_MS := 8           # construction de la carte : temps max par image avant de rendre la main (ms)
const KILL_Y := -15.0                    # en dessous de cette hauteur : mort (plus de chute infinie)
const FALL_KILLER_ID := -3               # killer_id quand un joueur meurt en tombant hors de la carte
const DROP_POD_LIFETIME := 30.0          # la capsule vide disparaît après ce délai (s)

# --- Kits (étape 8b) ---

# --- Capacités (étape 8c) ---

# --- Boutique configurable (lobby) : 4 cases d'armes + 4 cases gadgets / capacités ---
const SHOP_WEAPON_SLOTS := 4
const SHOP_GADGET_SLOTS := 4
const SHOT_ONLY_LAYER := 16              # couche 5 : arrête les tirs mais pas les corps (Paravent)

# --- Boosts d'arme (étape 8e, remplacent les raretés) ---

# --- Gadgets (étape 8d) ---

# --- Pactes et état « à terre » (étape 8e) ---
## En attendant les escouades (étape 9), un partenaire de pacte compte comme coéquipier
## (état « à terre », Rayon vital). false = personne ne tombe à terre avant l'étape 9.
const PACT_PARTNER_IS_ALLY := true

# --- Profils, factions, lobby, escouades (étape 9) ---
## Points de réputation cumulés pour les niveaux 1 à 10 d'une faction (valeurs de départ).
const SQUAD_MAX := 4
const QUICK_PLAY_ADDRESSES := ["127.0.0.1"]  # « Partie rapide » : essayés après le dernier serveur

# --- Quêtes : cristal + foreuse (valeurs provisoires) ---
const HOLD_SERVER_TOLERANCE := 0.85      # le serveur accepte un maintien de E à 85 % de la durée (latence)

# --- Contrats (valeurs provisoires) ---

# --- Score ---
