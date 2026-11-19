extends RefCounted
## Visuel du contrat « Sauvetage de drones » : balise et drones (ContractPart) autour.


## Construit la balise et les drones sous `site` ; remplit site.drone_hp et retourne les parts.
static func build(site: DroneSite) -> Array[ContractPart]:
	var data := site.data
	var parts: Array[ContractPart] = []
	site.add_cylinder_collision(0.4, 2.5)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.1
	pole.bottom_radius = 0.3
	pole.height = 2.5
	var p := ContractSite.make_mesh(pole, Color(0.6, 0.6, 0.65))
	p.position.y = 1.25
	site.add_child(p)
	var lamp := ContractSite.make_mesh(SphereMesh.new(), data.color, true)
	lamp.scale = Vector3.ONE * 0.5
	lamp.position.y = 2.7
	site.add_child(lamp)
	site.drone_hp.resize(data.count)
	for i in data.count:
		site.drone_hp[i] = data.target_health
		var part: ContractPart = DroneSite.PART_SCRIPT.new()
		part.name = "Drone%d" % i
		part.site = site
		part.index = i
		part.hit_radius = 0.9
		var a := TAU * i / data.count + 0.4
		part.position = Vector3(cos(a), 0, sin(a)) * data.radius
		part.rotation.y = randf() * TAU
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 0.7, 1.6)
		shape.shape = box
		shape.position.y = 0.35
		part.add_child(shape)
		var body := BoxMesh.new()
		body.size = Vector3(0.9, 0.5, 0.9)
		var b := ContractSite.make_mesh(body, Color(0.75, 0.75, 0.8))
		b.position.y = 0.35
		part.add_child(b)
		for k in 4:
			var arm := BoxMesh.new()
			arm.size = Vector3(0.7, 0.08, 0.1)
			var m := ContractSite.make_mesh(arm, Color(0.3, 0.3, 0.35))
			m.rotation.y = TAU * k / 4.0
			m.position = Vector3(cos(TAU * k / 4.0) * 0.6, 0.55, -sin(TAU * k / 4.0) * 0.6)
			part.add_child(m)
		site.add_child(part)
		parts.append(part)
	return parts
