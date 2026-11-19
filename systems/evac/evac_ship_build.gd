extends RefCounted
## Construction du vaisseau d'évacuation (EvacShip) : formes simples, collisions sur la couche
## « monde ». Remplit `ship._bay_floor_mat` et `ship._beacon` du vaisseau `ship`.

static func build(ship: EvacShip) -> void:
	var body := StaticBody3D.new()
	body.name = "Hull"
	body.collision_layer = 1
	body.collision_mask = 0
	ship.add_child(body)
	var hull := StandardMaterial3D.new()
	hull.albedo_color = EvacShip.HULL_COLOR
	ship._bay_floor_mat = StandardMaterial3D.new()
	ship._bay_floor_mat.albedo_color = EvacShip.BAY_COLOR.darkened(0.5)
	ship._bay_floor_mat.emission = EvacShip.BAY_COLOR
	ship._bay_floor_mat.emission_energy_multiplier = 0.6

	# Plancher de la soute (dessus à 1,5 m) : on passe dessous accroupi.
	_box(ship, body, Vector3(8, 0.3, 10), Vector3(0, 1.35, 0), 0.0, ship._bay_floor_mat)
	# Murs gauche, droit, arrière, toit.
	_box(ship, body, Vector3(0.5, 4.2, 10.5), Vector3(-4.25, 3.6, 0), 0.0, hull)
	_box(ship, body, Vector3(0.5, 4.2, 10.5), Vector3(4.25, 3.6, 0), 0.0, hull)
	_box(ship, body, Vector3(9.0, 4.2, 0.5), Vector3(0, 3.6, -5.25), 0.0, hull)
	_box(ship, body, Vector3(9.5, 0.5, 11.5), Vector3(0, 5.95, 0), 0.0, hull)
	# Façade avant avec une seule porte de 3 m (de 1,5 m à 4 m de haut).
	_box(ship, body, Vector3(3.0, 4.2, 0.5), Vector3(-2.75, 3.6, 5.25), 0.0, hull)
	_box(ship, body, Vector3(3.0, 4.2, 0.5), Vector3(2.75, 3.6, 5.25), 0.0, hull)
	_box(ship, body, Vector3(2.5, 1.7, 0.5), Vector3(0, 4.85, 5.25), 0.0, hull)
	# Rampe : du seuil de la porte (z = 5,5, y = 1,5) jusqu'au sol (z = 10,5, y = 0).
	# Rotation positive autour de X = le bout côté +z (loin de la porte) descend.
	var ramp_angle := atan2(1.5, 5.0)
	# Un peu plus longue que la pente : le bas s'enfonce dans le sol (pas de marche).
	_box(ship, body, Vector3(3.0, 0.25, 5.6), Vector3(0, 0.62, 8.0), ramp_angle, hull)
	# Pieds sous le plancher, aux quatre coins.
	for corner: Vector2 in [Vector2(-3.6, -4.6), Vector2(3.6, -4.6), Vector2(-3.6, 4.6), Vector2(3.6, 4.6)]:
		_box(ship, body, Vector3(0.4, 1.2, 0.4), Vector3(corner.x, 0.6, corner.y), 0.0, hull)

	ship._beacon = Label3D.new()
	ship._beacon.text = "ÉVAC"
	ship._beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ship._beacon.no_depth_test = true
	ship._beacon.fixed_size = true
	ship._beacon.pixel_size = 0.0012
	ship._beacon.font_size = 36
	ship._beacon.outline_size = 10
	ship._beacon.modulate = Color(0.6, 0.85, 1.0)
	ship._beacon.position = Vector3(0, 8.5, 0)
	ship.add_child(ship._beacon)


static func _box(ship: EvacShip, body: StaticBody3D, size: Vector3, pos: Vector3, rot_x: float, mat: Material) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	shape.rotation.x = rot_x
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = mat
	mesh.mesh = box_mesh
	mesh.position = pos
	mesh.rotation.x = rot_x
	ship.add_child(mesh)
