class_name WeaponSpread
extends RefCounted
## Maniement d'une arme selon l'état du tireur (jeu d'origine) : dispersion et recul accroupi.
## Le serveur tire la dispersion (hitscan et projectiles) avec l'état synchronisé du joueur
## (is_crouching, is_airborne, ground_speed) ; le client n'applique que le recul.

## Vitesse horizontale (m/s) au-dessus de laquelle le joueur compte comme « en mouvement ».
const MOVING_SPEED := 0.5


## Dispersion (degrés) d'un tir : à la hanche ou en visée, avec les facteurs accroupi / mouvement / air.
static func shot_spread_deg(data: WeaponData, player: Player, aiming: bool) -> float:
	var base := data.ads_spread_deg if aiming else data.hip_spread_deg * data.hipfire_spread_multiplier
	return base * state_multiplier(data, player)


## Produit des facteurs de dispersion qui s'appliquent à l'état actuel du joueur.
static func state_multiplier(data: WeaponData, player: Player) -> float:
	var mult := 1.0
	if player.is_crouching:
		mult *= data.crouch_spread_multiplier
	if player.is_airborne:
		mult *= data.in_air_spread_multiplier
	if player.ground_speed > MOVING_SPEED:
		mult *= data.moving_spread_multiplier
	return mult


## Facteur de recul : réduit quand le joueur est accroupi.
static func recoil_multiplier(data: WeaponData, player: Player) -> float:
	return data.crouch_recoil_multiplier if player.is_crouching else 1.0
