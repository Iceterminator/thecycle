class_name CentralPower
extends Node
## Ouvre la station centrale (serveur seulement). L'emplacement est tiré au début de la partie
## (QuestDraw) ; quand `central_unlock_count` stations de recherche ont été réactivées
## (Events.facility_reactivated), la station apparaît (une seule fois par partie) et on l'annonce.

const DATA_PATH := "res://data/contracts/central.tres"
const ANNOUNCE_COLOR := Color(0.45, 0.8, 1.0)

var spawn_callable: Callable  ## reçoit {kind, data, pos} et crée le contrat

var _spot: Variant = null  ## Vector3 ou null (pas de station de recherche tirée)
var _count: int = 0
var _opened: bool = false


func _ready() -> void:
	Events.facility_reactivated.connect(_on_facility_reactivated)


## Nouvelle partie : emplacement tiré (null = aucune station centrale), compteur remis à zéro.
func reset(spot: Variant) -> void:
	_spot = spot
	_count = 0
	_opened = false


func _on_facility_reactivated() -> void:
	if _spot == null or _opened:
		return
	_count += 1
	var data := load(DATA_PATH) as ContractData
	if _count < data.central_unlock_count:
		return
	_opened = true
	spawn_callable.call({"kind": &"central", "data": DATA_PATH, "pos": _spot})
	Events.announce_requested.emit("La station centrale s'ouvre : tenez la zone !", ANNOUNCE_COLOR)
