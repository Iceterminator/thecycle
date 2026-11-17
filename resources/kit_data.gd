class_name KitData
extends Resource
## Données d'un kit (combinaison du joueur). Un kit = un fichier .tres dans data/kits/<id>.tres.
## Champs repris de data/reference/the_cycle_legacy_data.json ; -1 = valeur inconnue.
## Pas encore utilisé en jeu (étape 9 : factions et loadout). Les capacités de mouvement
## deviendront des composants attachés au joueur selon mobility_type.

enum MobilityType { NONE, JETPACK, DASH, SUPER_JUMP, JETBOOSTERS }

@export var id: StringName
@export var display_name: String
@export var faction: WeaponData.Faction = WeaponData.Faction.STARTER
@export var faction_level: int = 0
@export var health: float = -1.0
@export var shield: float = -1.0
@export var move_speed_mps: float = -1.0
@export var mobility_type: MobilityType = MobilityType.NONE
## Paramètres des capacités, par capacité : { "jetpack": { "fuel_max": 100, ... }, ... }.
## Les textes « activation » décrivent les touches.
@export var movement: Dictionary = {}
## Bonus débloqués en partie, dans l'ordre : index 0 = niveau 1.
@export var level_perks: PackedStringArray = []
## Mods hors partie : [{ "id": ..., "effect": ... }].
@export var mods: Array[Dictionary] = []

@export_group("Notes")
@export var estimated_fields: PackedStringArray = []
@export_multiline var history: String = ""
@export_multiline var playstyle: String = ""
