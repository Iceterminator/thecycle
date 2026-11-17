class_name WeaponData
extends Resource
## Données d'une arme. Une arme = un fichier .tres dans data/weapons/.
## Pour équilibrer : modifier le .tres, pas ce script.

enum Family { ASSAULT_RIFLE, SMG, SHOTGUN, SNIPER, PISTOL, HEAVY }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var id: StringName
@export var display_name: String
@export var family: Family = Family.ASSAULT_RIFLE
@export var rarity: Rarity = Rarity.COMMON

@export_group("Tir")
@export var damage: float = 18.0
@export var fire_rate_rpm: float = 600.0       ## coups par minute
@export var pellets: int = 1                   ## > 1 pour les fusils à pompe
@export var headshot_multiplier: float = 1.5
@export var range_m: float = 120.0
@export var hitscan: bool = true               ## false = projectile (armes lourdes)
@export var automatic: bool = true             ## false = semi-auto (un clic = un tir)

@export_group("Chargeur")
@export var magazine_size: int = 30
@export var reload_time: float = 2.0

@export_group("Précision")
@export var spread_deg: float = 1.5
@export var ads_spread_deg: float = 0.4
@export var recoil_deg: float = 0.8

const RARITY_DAMAGE_BONUS := 0.10  ## +10 % de dégâts par palier de rareté


func get_damage() -> float:
	return damage * (1.0 + RARITY_DAMAGE_BONUS * rarity)


func get_fire_interval() -> float:
	return 60.0 / fire_rate_rpm
