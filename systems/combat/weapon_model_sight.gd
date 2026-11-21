extends RefCounted
## Visée du joueur local (avec les bras) d'après le repère « Viseur » de l'arme (arrière de la
## lunette ou du guidon, dans la scène held) : en visée, le corps et l'arme se décalent pour que
## le viseur tombe juste devant l'œil, quelle que soit la pose des bras. Hors visée, sans repère
## Viseur ou sans bras : position de repli (le corps reste calé sur la caméra).

const AIM_SIGHT := Vector3(0.0, 0.0, -0.12)  ## viseur en visée (repère de la caméra) : 12 cm devant l'œil
const MAX_SHIFT := 0.25  ## décalage maximal (m) : au-delà, la pose ne convient pas, on le borne
const SIGHT_MARKER := "Viseur"
## Main gauche hors visée (bras du joueur local, pose arme basse) : un peu plus bas que le repère MainGauche.
const HIP_LEFT_SHIFT := Vector3(0.0, -0.03, 0.0)


## Position visée du corps et de l'arme (repère du parent de `rig`, celui de la caméra).
## `model` : l'arme en main (null = pas de bras) ; pendant le rechargement on garde `current`.
static func target(rig: Node3D, model: Node3D, aiming: bool, reloading: bool, current: Vector3, fallback: Vector3) -> Vector3:
	var sight := model.find_child(SIGHT_MARKER, true, false) as Node3D if model and aiming else null
	if sight == null:
		return fallback
	if reloading:
		return current
	var wanted := AIM_SIGHT - rig.to_local(sight.global_position)
	return fallback + (wanted - fallback).limit_length(MAX_SHIFT)
