class_name MonsterCamp
extends Marker3D
## Camp de monstres (meute) posé dans la carte. Sa composition vient d'un CampData.
## Serveur : garde la liste des monstres vivants, prévient toute la meute quand l'un
## d'eux repère ou se fait attaquer par un joueur, et signale quand le camp est vidé.
## Plus tard : vider un camp rapportera des points de quête (Events.camp_cleared).

signal cleared(camp: MonsterCamp, killer_id: int)

@export var camp_data: CampData
@export var radius: float = 8.0  ## zone de patrouille autour du marqueur (m)

var alive: Array[Monster] = []


## Toute la meute prend `player` pour cible.
func alert(player: Player, source: Monster) -> void:
	for monster in alive:
		if monster != source and is_instance_valid(monster):
			monster.aggro(player, false)


func on_monster_died(monster: Monster, killer_id: int) -> void:
	alive.erase(monster)
	if alive.is_empty():
		print("[Monstres] Camp %s vidé par %d" % [name, killer_id])
		Events.camp_cleared.emit(StringName(name), killer_id)
		cleared.emit(self, killer_id)
