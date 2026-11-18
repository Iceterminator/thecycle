class_name StartLoadout
extends Resource
## Règles de jeu : équipement et boutique de départ.
## Valeurs dans res://data/rules/start_loadout.tres (accès : Config.start_loadout.<champ>).

@export var base_weapon: StringName  ## arme de départ (emplacement 1), jamais perdue
@export var default_kit: StringName  ## kit au premier largage
@export var heal_item: StringName  ## consommable de la touche 3
@export var shield_item: StringName  ## consommable de la touche 4
@export var max_medkits: int  ## soins portés max
@export var max_shield_cells: int  ## recharges de bouclier portées max
@export var default_abilities: Array[String] = []  ## capacités du menu admin
@export var default_shop_weapons: Array[String] = []  ## boutique par défaut : 4 armes
@export var default_shop_gadgets: Array[String] = []  ## boutique par défaut : 4 gadgets / capacités
