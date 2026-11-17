class_name StormPhaseData
extends Resource
## Une phase de la tempête (façon zone qui se referme). Un fichier .tres par phase dans
## data/storm/, triées par start_time. Avant la première phase : pas de tempête.
## À start_time - warning_time : annonce, la prochaine zone sûre apparaît.
## À start_time : la zone se referme vers `radius` en shrink_duration s, et les joueurs
## hors de la zone prennent damage_per_second (même à l'abri).

@export var start_time: float = 420.0          ## s depuis le début de la partie
@export var warning_time: float = 60.0         ## annonce avant la fermeture (s)
@export var shrink_duration: float = 60.0      ## durée de la fermeture (s)
@export var radius: float = 90.0               ## rayon de la zone sûre à la fin de la phase (m)
@export var damage_per_second: float = 1.0     ## hors de la zone, à partir de start_time
