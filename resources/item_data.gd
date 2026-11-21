class_name ItemData
extends Resource
## Un objet ramassable. Un objet = un fichier .tres dans data/items/.
## Le réseau n'envoie que l'`id` ; l'autoload Items retrouve la ressource.

enum Kind { WEAPON, HEAL, SHIELD_RECHARGE, CREDITS, SHIELD_UPGRADE, RESOURCE, ABILITY }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.WEAPON
@export var weapon: WeaponData                 ## seulement pour Kind.WEAPON
@export var ability: AbilityData               ## seulement pour Kind.ABILITY (créé par Items)
@export var amount: int = 1                    ## crédits : montant par défaut au sol
@export var effect: float = 0.0                ## PV ou bouclier rendus (soins / recharges)
@export var use_time: float = 0.0              ## durée d'utilisation (s)
@export var color: Color = Color.WHITE         ## couleur de l'objet au sol

@export_group("Boutique")
@export var price: int = 0                     ## prix en crédits (0 = pas en vente)
@export var shield_tier: int = 0               ## Kind.SHIELD_UPGRADE : palier obtenu (voir Config.SHIELD_PER_TIER)
@export var max_carry: int = 0                 ## Kind.RESOURCE : quantité max portée (0 = illimitée)

@export_group("Objectif")
## Kind.RESOURCE : si défini, ramasser l'objet donne directement `amount` points d'objectif (rien n'est porté).
@export var objective_track: ObjectiveTrack
## Couleur au sol selon la quantité (clé = quantité, ex. 75 -> vert) ; sinon `color`.
@export var amount_colors: Dictionary = {}

@export_group("Objet porté")
## Kind.RESOURCE porté qui rapporte des points d'objectif tant qu'on le porte (éclat d'orage).
@export var carry_track: ObjectiveTrack
@export var carry_points_per_second: float = 0.0  ## points d'objectif par seconde de port
@export var red_variant: ItemData                 ## variante rare tirée à l'apparition (éclat rouge)
@export var red_chance: float = 0.0               ## probabilité d'obtenir la variante rouge (0 à 1)
@export var red_evac_fame: int = 0                ## Fame gagnée si on embarque dans l'évac avec cet objet
