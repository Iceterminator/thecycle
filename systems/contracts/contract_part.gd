class_name ContractPart
extends StaticBody3D
## Sous-objet interactif d'un contrat (nœud de station, drone…). Il transmet tout à son
## site parent avec son index : get_prompt / get_hold_time / server_interact, et sert de
## cible aux monstres (can_be_hit / server_receive_hit / get_hit_radius).
## Créé en code par le site sur tous les peers, avec un nom stable (même chemin partout).

var site: Node
var index: int = 0
var hit_radius: float = 0.8


func _ready() -> void:
	add_to_group("interactable")


func get_prompt(player: Player) -> String:
	return site.part_prompt(index, player)


func get_hold_time(player: Player) -> float:
	return site.part_hold_time(index, player)


func server_interact(player: Player) -> void:
	site.part_interact(index, player)


func can_be_hit() -> bool:
	return site.part_can_be_hit(index)


func get_hit_radius() -> float:
	return hit_radius


func server_receive_hit(amount: float, _attacker_id: int) -> bool:
	return site.part_receive_hit(index, amount)


func register_wave_monster(monster: Monster) -> void:
	site.register_wave_monster(monster)


func on_wave_monster_died(monster: Monster) -> void:
	site.on_wave_monster_died(monster)
