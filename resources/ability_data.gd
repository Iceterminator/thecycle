class_name AbilityData
extends Resource
## Une capacité (étape 8c). Un fichier .tres par capacité dans data/abilities/<id>.tres,
## généré depuis data/reference/the_cycle_legacy_data.json (tools/import_legacy_data.gd).
## Deux emplacements (touches Q et F), un temps de recharge, 2 améliorations en partie.
## -1 = valeur absente de la source (non utilisée par cette capacité).

## Catégories de la référence : chacune a un comportement réutilisable (AbilityController
## et AbilityObject).
enum Category { GRENADE, STIM, DEPLOYABLE, BARRIER, CLOAK, STRIKE, FIELD, MOBILITY, SHIELD, SCANNER, TRAP, HEAL }

@export var id: StringName
@export var display_name: String
## Nom dans le jeu d'origine (affiché tant que Config.SHOW_REFERENCE_WEAPON_NAMES est vrai).
@export var reference_name: String = ""
@export var faction: WeaponData.Faction = WeaponData.Faction.STARTER
@export var faction_level: int = 0
@export var category: Category = Category.STIM

@export_group("Chiffres")
@export var cooldown_s: float = 30.0
@export var duration_s: float = -1.0
@export var delay_s: float = -1.0             ## frappes, pièges : délai avant l'effet
@export var radius_m: float = -1.0
@export var damage: float = -1.0
@export var damage_per_s: float = -1.0
@export var damage_per_missile: float = -1.0
@export var missiles: int = -1
@export var heal_instant: float = -1.0
@export var heal_per_s: float = -1.0
@export var health: float = -1.0              ## objet posé (tourelle, balise)
@export var rpm: float = -1.0                 ## tourelle
@export var range_m: float = -1.0
@export var width_m: float = -1.0             ## barrières
@export var height_m: float = -1.0
@export var distance_m: float = -1.0          ## portail
@export var slow_percent: float = -1.0
@export var scan_interval_s: float = -1.0
@export var max_active: int = -1

@export_group("Effets sur soi (bonus / malus)")
## Effets temporaires pendant duration_s (voir BuffController) : speed_mult,
## damage_taken_mult, max_health_add, health_regen_mult, no_health_regen, heal_per_s,
## cloak (0 à 1), cloak_moving (camouflage quand on court), cloak_breaks_on_fire,
## invulnerable, recoil_mult.
@export var buff: Dictionary = {}
## Effet à la fin (ex. ralentissement après le camouflage) et sa durée.
@export var after_buff: Dictionary = {}
@export var after_duration_s: float = 0.0

@export_group("Améliorations")
## Chaque amélioration (2 max, Config.economy.ability_upgrade_price crédits) retire ces secondes
## à la recharge (référence : Kinetic Barrier -5 s).
@export var upgrade_cooldown_s: float = 5.0

@export_group("Fiche")
@export_multiline var activation: String = ""
@export var effects: PackedStringArray = []
## Image pour le HUD et les menus (facultative) ; sans image, AbilityIcon la dessine.
@export var hud_icon: Texture2D
@export_multiline var visual: String = ""
@export_multiline var counterplay: String = ""
@export_multiline var behavior: String = ""
@export var estimated_fields: PackedStringArray = []
@export_multiline var notes: String = ""


## Nom affiché (nom d'origine tant que Config.SHOW_REFERENCE_WEAPON_NAMES est vrai).
func get_display_name() -> String:
	if Config.SHOW_REFERENCE_WEAPON_NAMES and reference_name != "":
		return reference_name
	return display_name


## Recharge réelle selon les améliorations et le bonus de kit (« recharge des capacités »).
func get_cooldown(upgrades: int, kit_mult: float, kit_add: float = 0.0) -> float:
	return maxf((cooldown_s - upgrade_cooldown_s * upgrades) * (1.0 + kit_mult) + kit_add, 1.0)
