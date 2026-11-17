class_name KitData
extends Resource
## Données d'un kit (combinaison du joueur). Un kit = un fichier .tres dans data/kits/<id>.tres.
## Champs repris de data/reference/the_cycle_legacy_data.json ; -1 = valeur inconnue.
## Utilisé en jeu depuis l'étape 8b (KitController sur le joueur) : PV, bouclier, vitesse,
## capacités de mouvement selon mobility_type (KitMovement), niveaux en partie.

enum MobilityType { NONE, JETPACK, DASH, SUPER_JUMP, JETBOOSTERS }

@export var id: StringName
@export var display_name: String
## Nom dans le jeu d'origine (affiché tant que Config.SHOW_REFERENCE_WEAPON_NAMES est vrai).
@export var reference_name: String = ""
@export var faction: WeaponData.Faction = WeaponData.Faction.STARTER
@export var faction_level: int = 0
@export var health: float = -1.0
@export var shield: float = -1.0
@export var move_speed_mps: float = -1.0
@export var mobility_type: MobilityType = MobilityType.NONE
## Paramètres des capacités, par capacité : { "jetpack": { "fuel_max": 100, ... }, ... }.
## Les textes « activation » décrivent les touches.
@export var movement: Dictionary = {}
## Bonus débloqués en partie, dans l'ordre : index 0 = niveau 1 (actif dès le départ).
@export var level_perks: PackedStringArray = []
## Les mêmes bonus, chiffrés (même index) : { effet: valeur }. Effets connus :
## creature_defense, creature_damage (part en plus / en moins), max_health_add, max_shield_add,
## move_speed_mult, health_regen_mult, health_regen_delay_mult, fuel_regen_mult, thrust_mult,
## dive_damage_add, energy_charges_add, air_jumps_add, super_jump_mult, punch_damage_mult,
## charge_speed_mult, ability_cooldown_mult (capacités, étape 8c).
@export var level_perk_effects: Array[Dictionary] = []
## Mods hors partie : [{ "id": ..., "effect": ... }].
@export var mods: Array[Dictionary] = []

@export_group("Notes")
@export var estimated_fields: PackedStringArray = []
@export_multiline var history: String = ""
@export_multiline var playstyle: String = ""
