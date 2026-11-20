extends StaticBody3D
## Téléporteur de la salle de test : E ramène tout le serveur au lobby (Niveaux.server_quitter_salle_test).
## Objet interactif (groupe « interactable », voir Interactor).

const COULEUR := Color(0.35, 0.85, 1.0)


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.4
	cyl.height = 0.3
	shape.shape = cyl
	shape.position.y = 0.15
	add_child(shape)
	var anneau := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.4
	mesh.bottom_radius = 1.5
	mesh.height = 0.3
	anneau.mesh = mesh
	anneau.position.y = 0.15
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COULEUR
	mat.emission_enabled = true
	mat.emission = COULEUR
	mat.emission_energy_multiplier = 2.5
	anneau.material_override = mat
	add_child(anneau)
	if DisplayServer.get_name() != "headless":
		var lumiere := OmniLight3D.new()
		lumiere.light_color = COULEUR
		lumiere.omni_range = 6.0
		lumiere.position.y = 1.0
		add_child(lumiere)


func get_prompt(_player: Player) -> String:
	return "E : Retour au lobby (tout le serveur)"


## Serveur (Interactor, distance vérifiée).
func server_interact(_player: Player) -> void:
	var niveaux := get_parent().get_parent().get_node_or_null("Niveaux") as Niveaux  # Monde/SalleTest/Sortie
	if niveaux:
		niveaux.server_quitter_salle_test()
