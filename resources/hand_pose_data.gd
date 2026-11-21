class_name HandPoseData
extends Resource
## Pose des doigts pour tenir une arme : rotation locale de chaque phalange (os du squelette des
## personnages, ex. « index_02_r »), appliquée par-dessus l'animation (HandPoseModifier).
## Générée par tools/hand_pose/ (doigts refermés jusqu'au contact avec l'arme), retouchable à la main.
## Une fiche par arme dans data/hand_poses/ (id = nom du fichier).

@export var rotations: Dictionary[StringName, Quaternion] = {}
