class_name StormPhaseData
extends Resource
## Une Grande Marée : tempête qui couvre toute la carte (pas de zone, pas de dégâts).
## Un fichier .tres par tempête dans data/storm/, triées par start_time.
## À start_time - warning_time : annonce. À start_time : le ciel s'assombrit en fade_time s
## (pluie, éclairs, brouillard violet), puis la tempête dure `duration` s (0 = jusqu'à la fin).

@export var start_time: float = 600.0          ## s depuis le début de la partie
@export var warning_time: float = 60.0         ## annonce avant le début (s)
@export var fade_time: float = 20.0            ## durée de la transition ciel clair <-> tempête (s)
@export var duration: float = 0.0              ## durée de la tempête (s) ; 0 = jusqu'à la fin de la partie
