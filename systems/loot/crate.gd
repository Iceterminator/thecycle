class_name Crate
extends StaticBody3D
## Caisse de loot. Créée par le serveur (LootManager), répliquée par le LootSpawner.
## `opened` est synchronisé par le serveur (CrateSync, autorité 1 par défaut).
## Interface d'interaction : get_prompt(player) côté client, server_interact(player) côté serveur.

@export var loot_table: LootTable

@onready var lid: MeshInstance3D = $Lid
@onready var body_mesh: MeshInstance3D = $BodyMesh

var opened: bool = false:
	set(value):
		opened = value
		if is_node_ready():
			_update_look()


func _ready() -> void:
	add_to_group("interactable")
	_update_look()


func get_prompt(_player: Player) -> String:
	return "" if opened else "E : Ouvrir la caisse"


## Serveur uniquement (appelé par Interactor après vérification de distance).
func server_interact(player: Player) -> void:
	if opened:
		return
	opened = true
	for item in loot_table.roll():
		Events.loot_drop_requested.emit(item.id, item.amount, -1, global_position + Vector3(0, 0.6, 0), true)
	Events.crate_opened.emit(player.get_peer_id())


func _update_look() -> void:
	lid.visible = not opened
	var mat := body_mesh.get_active_material(0) as StandardMaterial3D
	if mat:
		mat.albedo_color = Color(0.3, 0.27, 0.22) if opened else Color(0.75, 0.5, 0.15)
