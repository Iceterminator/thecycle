class_name StartLoadout
extends Resource
## Règles de jeu : équipement et boutique de départ.
## Valeurs dans res://data/rules/start_loadout.tres (accès : Config.start_loadout.<champ>).

@export var base_weapon: StringName  ## arme de départ (emplacement 1), jamais perdue
@export var default_kit: StringName  ## kit au premier largage
@export var default_abilities: Array[String] = []  ## capacités du menu admin
@export var default_shop_weapons: Array[String] = []  ## boutique par défaut : 4 armes
@export var default_shop_gadgets: Array[String] = []  ## boutique par défaut : 4 gadgets / capacités
