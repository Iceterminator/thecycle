class_name ItemData
extends Resource
## Un objet ramassable. Un objet = un fichier .tres dans data/items/.
## Le réseau n'envoie que l'`id` ; l'autoload Items retrouve la ressource.

enum Kind { WEAPON, HEAL, SHIELD_RECHARGE, CREDITS }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.WEAPON
@export var weapon: WeaponData                 ## seulement pour Kind.WEAPON
@export var amount: int = 1                    ## crédits : montant par défaut au sol
@export var effect: float = 0.0                ## PV ou bouclier rendus (soins / recharges)
@export var use_time: float = 0.0              ## durée d'utilisation (s)
@export var color: Color = Color.WHITE         ## couleur de l'objet au sol
