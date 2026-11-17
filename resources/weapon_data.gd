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
enum WeaponType { SMG, ASSAULT_RIFLE, BATTLE_RIFLE, SNIPER_RIFLE, SHOTGUN, LMG, PISTOL, MISSILE_LAUNCHER, HEAVY }
enum Slot { PRIMARY, SECONDARY }
## AUTO : tir continu. SEMI : un tir par clic. BURST : un clic = burst_count tirs.
## CHARGE, CHARGE_BURST, BEAM : pas encore codés (le tir retombe sur SEMI, BURST, AUTO).
enum FireMode { AUTO, SEMI, BURST, CHARGE, CHARGE_BURST, BEAM }
## EXPLOSIVE_PROJECTILE : pas encore de dégâts de zone (se comporte comme PROJECTILE).
enum ProjectileType { HITSCAN, PROJECTILE, EXPLOSIVE_PROJECTILE }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const RARITY_DAMAGE_BONUS := 0.10    ## +10 % de dégâts par palier de rareté
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
@export var rarity: Rarity = Rarity.COMMON

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
@export var damage_vs_shield_multiplier: float = 1.0  ## pas encore appliqué
@export var damage_vs_health_multiplier: float = 1.0  ## pas encore appliqué

@export_group("Projectile")
@export var projectile_speed_mps: float = -1.0
@export var aoe_damage: float = -1.0             ## pas encore appliqué
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

@export_group("Progression")
@export var spawn_cost_credits: int = -1         ## prix en partie (-1 = inconnu)
@export var unlock_cost: int = -1                ## prix de déblocage hors partie

@export_group("Notes")
## Champs absents des sources : valeurs de départ à équilibrer en jouant.
@export var estimated_fields: PackedStringArray = []
@export_multiline var behavior: String = ""
@export_multiline var notes: String = ""


## Dégâts d'un impact (une balle, ou un plomb pour un fusil à pompe), rareté comprise.
func get_hit_damage() -> float:
	var base := damage
	if pellets > 1:
		base = pellet_damage if pellet_damage > 0.0 else damage / pellets
	return base * (1.0 + RARITY_DAMAGE_BONUS * rarity)


## Multiplicateur de distance : 1 jusqu'à falloff_start_m, puis baisse linéaire
## jusqu'à falloff_min_multiplier à falloff_end_m.
func get_falloff_multiplier(distance: float) -> float:
	if falloff_start_m < 0.0 or distance <= falloff_start_m:
		return 1.0
	if falloff_end_m <= falloff_start_m or distance >= falloff_end_m:
		return falloff_min_multiplier
	var t := (distance - falloff_start_m) / (falloff_end_m - falloff_start_m)
	return lerpf(1.0, falloff_min_multiplier, t)


func get_max_range() -> float:
	return max_range_m if max_range_m > 0.0 else DEFAULT_MAX_RANGE


## s entre deux appuis (AUTO, SEMI) ou entre deux débuts de rafale (BURST).
func get_fire_interval() -> float:
	if fire_interval_s > 0.0:
		return fire_interval_s
	return 60.0 / maxf(rpm, 1.0)


## Mode de tir réellement joué (les modes pas encore codés retombent sur un mode proche).
func get_effective_fire_mode() -> FireMode:
	match fire_mode:
		FireMode.CHARGE:
			return FireMode.SEMI
		FireMode.CHARGE_BURST:
			return FireMode.BURST
		FireMode.BEAM:
			return FireMode.AUTO
	return fire_mode


## Tirs par cycle de get_fire_interval() (sert au contrôle de cadence du serveur).
func get_shots_per_cycle() -> int:
	return maxi(burst_count, 1) if get_effective_fire_mode() == FireMode.BURST else 1


func is_projectile() -> bool:
	return projectile_type != ProjectileType.HITSCAN and projectile_speed_mps > 0.0


## Champ de vision en visée.
func get_ads_fov(default_ads_fov: float, default_fov: float) -> float:
	return default_fov / scope_zoom if scope_zoom > 1.0 else default_ads_fov
