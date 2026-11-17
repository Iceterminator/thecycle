class_name ItemData
extends Resource
## Un objet ramassable. Un objet = un fichier .tres dans data/items/.
## Le réseau n'envoie que l'`id` ; l'autoload Items retrouve la ressource.

enum Kind { WEAPON, HEAL, SHIELD_RECHARGE, CREDITS, SHIELD_UPGRADE }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.WEAPON
@export var weapon: WeaponData                 ## seulement pour Kind.WEAPON
@export var amount: int = 1                    ## crédits : montant par défaut au sol
@export var effect: float = 0.0                ## PV ou bouclier rendus (soins / recharges)
@export var use_time: float = 0.0              ## durée d'utilisation (s)
@export var color: Color = Color.WHITE         ## couleur de l'objet au sol

@export_group("Boutique")
@export var price: int = 0                     ## prix en crédits (0 = pas en vente)
@export var shield_tier: int = 0               ## Kind.SHIELD_UPGRADE : palier obtenu (voir Config.SHIELD_PER_TIER)
