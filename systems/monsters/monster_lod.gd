class_name MonsterLod
extends RefCounted
## Niveau de détail de la physique des monstres (serveur). move_and_slide d'un monstre contre
## le relief coûte ~0,17 ms : à 100+ monstres, c'est ce qui faisait tomber le serveur sous 10 FPS.
## Règle : un monstre en patrouille à plus de FAR_DISTANCE de tout joueur (au-delà de tous les
## rayons de détection) n'utilise plus de collision et ne réfléchit que 4 fois par seconde : il avance
## en ligne droite et se pose sur
## le relief (MapTerrain.height_at). Dès qu'un joueur approche, il repasse en physique normale.

const FAR_DISTANCE := 50.0      ## m : au-delà, patrouille sans collision
const CHECK_INTERVAL := 0.5     ## s : fréquence du calcul de distance aux joueurs
const FAR_AI_INTERVAL := 0.25   ## s : loin de tout joueur, l'IA de patrouille ne tourne qu'à ce rythme


## Vrai si aucun joueur n'est à moins de FAR_DISTANCE du monstre.
static func is_far(monster: Node3D, players_root: Node) -> bool:
	if players_root == null:
		return false
	var limit_sq := FAR_DISTANCE * FAR_DISTANCE
	for player in players_root.get_children():
		if (player as Node3D).global_position.distance_squared_to(monster.global_position) < limit_sq:
			return false
	return true


## Avance sans collision, posé sur le relief.
static func step_far(monster: CharacterBody3D, delta: float) -> void:
	var pos := monster.global_position + Vector3(monster.velocity.x, 0.0, monster.velocity.z) * delta
	pos.y = MapTerrain.height_at(pos.x, pos.z)
	monster.global_position = pos
