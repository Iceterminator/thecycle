class_name ContractSpot
extends Marker3D
## Emplacement d'un contrat dans la carte. `kind` : uplink, extractor, collector,
## facility, drones, ou lumicep (simple point de repousse de Lumicèpes, sans données).

@export var kind: StringName = &"uplink"
@export var contract_data: ContractData
