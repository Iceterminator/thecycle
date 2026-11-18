class_name WeaponData
extends Resource
## Données d'une arme. Une arme = un fichier .tres dans data/weapons/<id>.tres.
## Pour équilibrer : modifier le .tres, pas ce script.
##
## Les champs reprennent ceux de data/reference/the_cycle_legacy_data.json (mêmes noms,
## mêmes unités : mètres, secondes, m/s). Une valeur inconnue dans la source vaut -1.
## Les .tres sont générés par tools/import_legacy_data.gd.

## Factions inventées (équivalents des factions du jeu d'origine, voir DESIGN §12).
enum Faction { STARTER, LOURDE, TECHNO, EQUILIBRE }
enum WeaponType { SMG, ASSAULT_RIFLE, BATTLE_RIFLE, SNIPER_RIFLE, SHOTGUN, LMG, PISTOL, MISSILE_LAUNCHER, HEAVY, GADGET }
enum Slot { PRIMARY, SECONDARY }
## AUTO : tir continu. SEMI : un tir par clic. BURST : un clic = burst_count tirs.
## CHARGE : maintenir charge_time_s, le tir part dès que la charge est pleine (relâcher avant
## = pas de tir). CHARGE_BURST : pareil, puis une rafale de burst_count tirs.
## BEAM : après spin_up_s de montée en régime, un « tick » de dégâts tous les fire_interval_s
## tant qu'on maintient (1 munition par tick).
enum FireMode { AUTO, SEMI, BURST, CHARGE, CHARGE_BURST, BEAM }
## EXPLOSIVE_PROJECTILE : dégâts directs sur la cible touchée + aoe_damage dans aoe_radius_m
## (moins au bord), y compris pour le tireur.
enum ProjectileType { HITSCAN, PROJECTILE, EXPLOSIVE_PROJECTILE }

const DEFAULT_MAX_RANGE := 300.0     ## portée si max_range_m est inconnu (m)

@export var id: StringName
@export var display_name: String
## Nom dans le jeu d'origine. Affiché à la place de display_name tant que
## Config.SHOW_REFERENCE_WEAPON_NAMES est vrai (repère temporaire pour les tests).
@export var reference_name: String = ""
@export var faction: Faction = Faction.STARTER
@export var faction_level: int = 0               ## réputation requise (0 = arme de départ)
@export var type: WeaponType = WeaponType.ASSAULT_RIFLE
@export var slot: Slot = Slot.PRIMARY

@export_group("Tir")
@export var fire_mode: FireMode = FireMode.AUTO
@export var projectile_type: ProjectileType = ProjectileType.HITSCAN
@export var damage: float = 18.0                 ## par balle (total de tous les plombs si pellets > 1)
@export var pellets: int = 1                     ## > 1 pour les fusils à pompe
@export var pellet_damage: float = -1.0          ## dégâts d'un plomb
@export var spread_deg: float = 0.0              ## cône des plombs (fusils à pompe)
@export var rpm: float = 600.0                   ## coups par minute (information)
@export var fire_interval_s: float = 0.1         ## s entre deux tirs (entre deux rafales pour BURST)
@export var dps: float = -1.0                    ## information, non utilisé par le code
@export var burst_count: int = 1
@export var burst_interval_s: float = 0.0        ## s entre deux tirs d'une rafale
@export var charge_time_s: float = -1.0
@export var spin_up_s: float = -1.0

@export_group("Dégâts")
@export var weakspot_multiplier: float = 1.5     ## tête des joueurs, point faible des monstres
@export var falloff_start_m: float = -1.0        ## -1 = pas de baisse avec la distance
@export var falloff_end_m: float = -1.0
@export var falloff_min_multiplier: float = 0.6  ## multiplicateur à partir de falloff_end_m
@export var max_range_m: float = -1.0            ## -1 = DEFAULT_MAX_RANGE
@export var damage_vs_shield_multiplier: float = 1.0  ## part des dégâts qui touche le bouclier
@export var damage_vs_health_multiplier: float = 1.0  ## part des dégâts qui touche les PV

@export_group("Projectile")
@export var projectile_speed_mps: float = -1.0
@export var aoe_damage: float = -1.0             ## explosifs : dégâts au centre de la zone
@export var aoe_radius_m: float = -1.0

@export_group("Chargeur")
@export var magazine: int = 30
@export var reload_s: float = 2.0

@export_group("Maniement")
@export var ads_time_s: float = 0.25             ## temps pour passer en visée
@export var equip_time_s: float = 0.4            ## pas de tir pendant ce temps après un changement d'arme
@export var stability: float = -1.0              ## valeur du jeu d'origine (information)
@export var scope_zoom: float = -1.0             ## > 1 : lunette (champ de vision divisé en visée)
@export var hipfire_spread_multiplier: float = 1.0
@export var recoil_multiplier: float = 1.0
## Réglages propres au remake (absents de la source) :
@export var hip_spread_deg: float = 1.5          ## dispersion sans viser
@export var ads_spread_deg: float = 0.4          ## dispersion en visée
@export var recoil_deg: float = 0.8              ## recul par tir

@export_group("Boosts (paliers achetés en boutique)")
## Un dictionnaire par palier, dans l'ordre ; chaque palier s'ajoute aux précédents.
## Clés : damage, range, fire_rate (part en plus : 0.1 = +10 %).
@export var boosts: Array[Dictionary] = [{"damage": 0.1}, {"range": 0.1}, {"fire_rate": 0.1}]

@export_group("Gadget (étape 8d)")
## Gadget : arme spéciale qui occupe un emplacement d'arme (voir Weapon).
## FRAG_GRENADE : lancée en arc, explose après fuse_s. HEAL_BEAM : rayon de soin sur un
## allié (heal_per_tick), clic droit = se soigner (self_heal). RECALL : maintenir pour poser
## la balise (place_time_s), puis maintenir spin_up_s pour s'y téléporter.
enum GadgetKind { NONE, FRAG_GRENADE, HEAL_BEAM, RECALL }
@export var gadget: GadgetKind = GadgetKind.NONE
@export var consumable: bool = false            ## chargeur vide = gadget retiré (pas de rechargement)
@export var heal_per_tick: float = -1.0
@export var self_heal: float = -1.0
@export var fuse_s: float = -1.0
@export var place_time_s: float = -1.0
@export var beacon_health: float = -1.0

@export_group("Progression")
@export var spawn_cost_credits: int = -1         ## prix en partie (-1 = inconnu)
@export var unlock_cost: int = -1                ## prix de déblocage hors partie

@export_group("Ressenti")
## Réglages visuels, déduits de la fiche « detailed » par le générateur.
@export var tracer_color: Color = Color(1.0, 0.9, 0.5)
@export var tracer_width: float = 0.02           ## épaisseur du traçant / du rayon (m)
@export var tracer_time: float = 0.06            ## durée d'affichage du traçant (s)
@export var muzzle_flash_scale: float = 1.0
@export var impact_scale: float = 1.0
@export var projectile_size: float = 0.04        ## projectile visible (m)
@export var smoke_trail: bool = false            ## traînée de fumée (roquettes, obus)
## Image de l'arme pour le HUD et les menus (facultative) ; sans image, WeaponIcon la dessine.
@export var hud_icon: Texture2D

@export_group("Modèle 3D")
## Scène « tenue en main » de l'arme (assets/models/weapons/held/, tools/make_held_scenes.gd) :
## le modèle + les repères Poignee (posée dans la paume) et Bouche (bout du canon). Vue à la première personne et par les autres
## joueurs (WeaponModel). Sans modèle, rien n'est affiché en main.
@export var model: PackedScene
## Rotation pour mettre le canon vers l'avant (-Z) et le dessus vers le haut.
@export var model_rotation_deg: Vector3 = Vector3.ZERO
## Longueur réelle de l'arme (m) : le modèle est redimensionné, le repère Poignee sur l'origine.
@export var model_length: float = 0.25
## Décalage de la position en main (m, repère de la tête : x droite, y haut, -z devant).
@export var model_offset: Vector3 = Vector3.ZERO
## Teinte multipliée sur les couleurs du modèle (blanc = aucune) : couleur de la faction (gris départ, rouge Forge Brask, vert Lumen, bleu Consortium Vega), légèrement variée quand un même modèle revient dans une faction.
@export var model_tint: Color = Color.WHITE

@export_group("Fiche (detailed)")
## Fiche de design de la référence : ce que l'arme doit faire ressentir.
@export_multiline var role: String = ""
@export_multiline var shot_feel: String = ""
@export_multiline var projectile_visual: String = ""
@export_multiline var impact: String = ""
@export_multiline var recoil_feel: String = ""
@export_multiline var sound: String = ""
@export var best_range_m: Vector2 = Vector2.ZERO  ## portée idéale (min, max)
@export var strengths: PackedStringArray = []
@export var weaknesses: PackedStringArray = []
@export_multiline var counter: String = ""

@export_group("Notes")
## Champs absents des sources : valeurs de départ à équilibrer en jouant.
@export var estimated_fields: PackedStringArray = []
@export_multiline var behavior: String = ""
@export_multiline var notes: String = ""


## Dégâts d'un impact (une balle, ou un plomb pour un fusil à pompe), sans boost.
func get_hit_damage() -> float:
	var base := damage
	if pellets > 1:
		base = pellet_damage if pellet_damage > 0.0 else damage / pellets
	return base


## Multiplicateur de distance : 1 jusqu'à falloff_start_m, puis baisse linéaire
## jusqu'à falloff_min_multiplier à falloff_end_m.
func get_falloff_multiplier(distance: float) -> float:
	if falloff_start_m < 0.0 or distance <= falloff_start_m:
		return 1.0
	if falloff_end_m <= falloff_start_m or distance >= falloff_end_m:
		return falloff_min_multiplier
	var t := (distance - falloff_start_m) / (falloff_end_m - falloff_start_m)
	return lerpf(1.0, falloff_min_multiplier, t)


## Boost cumulé d'une clé (damage, range, fire_rate) au palier `level` : 1.0 = aucun.
func get_boost(key: String, level: int) -> float:
	var total := 1.0
	for i in mini(level, boosts.size()):
		total += float(boosts[i].get(key, 0.0))
	return total


func get_max_range() -> float:
	return max_range_m if max_range_m > 0.0 else DEFAULT_MAX_RANGE


## s entre deux appuis (AUTO, SEMI) ou entre deux débuts de rafale (BURST).
func get_fire_interval() -> float:
	if fire_interval_s > 0.0:
		return fire_interval_s
	return 60.0 / maxf(rpm, 1.0)


## Mode de tir joué (tous les modes sont codés ; gardé pour les appels existants).
func get_effective_fire_mode() -> FireMode:
	return fire_mode


func is_burst() -> bool:
	return fire_mode == FireMode.BURST or fire_mode == FireMode.CHARGE_BURST


## Temps à maintenir avant le premier tir (charge ou montée en régime), 0 sinon.
func get_trigger_delay() -> float:
	match fire_mode:
		FireMode.CHARGE, FireMode.CHARGE_BURST:
			return maxf(charge_time_s, 0.0)
		FireMode.BEAM:
			return maxf(spin_up_s, 0.0)
	return 0.0


## Tirs par cycle de get_fire_interval() (sert au contrôle de cadence du serveur).
func get_shots_per_cycle() -> int:
	return maxi(burst_count, 1) if is_burst() else 1


func is_explosive() -> bool:
	return projectile_type == ProjectileType.EXPLOSIVE_PROJECTILE and aoe_radius_m > 0.0


func is_projectile() -> bool:
	return projectile_type != ProjectileType.HITSCAN and projectile_speed_mps > 0.0


## Champ de vision en visée.
func get_ads_fov(default_ads_fov: float, default_fov: float) -> float:
	return default_fov / scope_zoom if scope_zoom > 1.0 else default_ads_fov
