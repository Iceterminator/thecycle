extends RefCounted
## Visuel du contrat « Sauvetage de drones » : porteur au centre et drones (ContractPart) autour.

const FLIGHT_TIME := 1.2  ## durée du vol d'un drone relancé vers le porteur (s, purement visuel)
const FLIGHT_HEIGHT := 3.0


## Construit le porteur et les drones sous `site` ; remplit site.drone_hp (drones, puis porteur en
## dernier) et retourne les parts (le porteur est le dernier).
static func build(site: DroneSite) -> Array[ContractPart]:
	var data := site.data
	var parts: Array[ContractPart] = []
	site.drone_hp = fresh_hp(data)
	for i in data.count:
		parts.append(_drone(site, i))
	parts.append(_carrier(site))
	return parts


static func _carrier(site: DroneSite) -> ContractPart:
	var part := _part(site, site.data.count, 2.4)
	part.name = "Porteur"
	part.shootable = true
	part.add_child(_box_shape(Vector3(3.0, 2.0, 5.0), 1.0))
	var hull := BoxMesh.new()
	hull.size = Vector3(3.0, 1.6, 5.0)
	var h := ContractSite.make_mesh(hull, Color(0.45, 0.47, 0.52))
	h.position.y = 1.0
	part.add_child(h)
	var lamp := ContractSite.make_mesh(SphereMesh.new(), site.data.color, true)
	lamp.scale = Vector3.ONE * 0.5
	lamp.position.y = 2.3
	part.add_child(lamp)
	site.add_child(part)
	return part


static func _drone(site: DroneSite, i: int) -> ContractPart:
	var part := _part(site, i, 0.9)
	part.name = "Drone%d" % i
	var a := TAU * i / site.data.count + 0.4
	part.position = Vector3(cos(a), 0, sin(a)) * site.data.radius
	part.rotation.y = randf() * TAU
	part.set_meta("home", part.position)
	part.add_child(_box_shape(Vector3(1.6, 0.7, 1.6), 0.35))
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
	return part


static func _part(site: DroneSite, i: int, hit_radius: float) -> ContractPart:
	var part: ContractPart = DroneSite.PART_SCRIPT.new()
	part.site = site
	part.index = i
	part.hit_radius = hit_radius
	return part


static func _box_shape(size: Vector3, height: float) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = height
	return shape


## Tous les peers, chaque frame : un drone relancé s'envole vers le porteur puis disparaît ;
## un drone détruit disparaît ; tout revient quand le site se réinitialise.
static func update_flights(site: DroneSite, parts: Array[ContractPart]) -> void:
	for i in site.data.count:
		var part := parts[i]
		var bit := 1 << i
		var sent: bool = site.sent_mask & bit != 0
		var flown: bool = site.flown_mask & bit != 0
		if sent and not flown:
			site.flown_mask |= bit
			var tween := part.create_tween()
			tween.tween_property(part, "position", Vector3(0, FLIGHT_HEIGHT, 0), FLIGHT_TIME)
			tween.tween_callback(part.hide)
		elif not sent and flown:
			site.flown_mask &= ~bit
			part.position = part.get_meta("home")
		if not sent:
			part.visible = site.drone_hp[i] > 0.0


## PV de départ : drones, puis porteur en dernier.
static func fresh_hp(data: ContractData) -> PackedFloat32Array:
	var hp := PackedFloat32Array()
	hp.resize(data.count + 1)
	hp.fill(data.target_health)
	hp[data.count] = data.carrier_health
	return hp


## Texte flottant (et de l'écran Tab) selon l'état du site.
static func label_text(site: DroneSite) -> String:
	var data := site.data
	match site.state:
		DroneSite.State.WAITING:
			return "%s\n%d drones attaqués par des monstres" % [data.display_name, data.count]
		DroneSite.State.ACTIVE:
			var hp_text := ""
			for i in data.count:
				hp_text += ("%d%% " % roundi(100.0 * site.drone_hp[i] / data.target_health)) if site.sent_mask & (1 << i) == 0 else "relancé "
			return "%s\nDrones : %s\nRelancez-les (E)" % [data.display_name, hp_text]
		DroneSite.State.LAUNCH:
			return "%s — décollage dans %d s\nPorteur : %d%%" % [data.display_name, ceili(site.time_left), roundi(100.0 * site.drone_hp[data.count] / data.carrier_health)]
	return "%s\nTerminé — de nouveau disponible bientôt" % data.display_name
