extends RefCounted
## Visuels et collisions d'un AbilityObject (fonctions statiques) : maillages, barre de PV,
## formes de collision, synchronisation des PV. Les nœuds créés sont ajoutés à l'objet.

const PORTAL_RADIUS := 1.3


static func build(o: AbilityObject) -> void:
	if Net.is_dedicated_server:
		return
	var color := color_of(o.ability)
	match o.kind:
		"frag":
			o._ball = mesh(o, sphere(0.12), Color(0.35, 0.4, 0.3), false)
		"beacon":
			var post := mesh(o, box(Vector3(0.4, 1.0, 0.4)), color, false)
			post.position.y = 0.5
			# Colonne de lumière visible de loin.
			var column := mesh(o, box(Vector3(0.15, 12.0, 0.15)), Color(color, 0.35), true)
			column.position.y = 6.0
			add_bar(o, 1.5)
		"grenade":
			o._ball = mesh(o, sphere(0.15), color, false)
			o._field = mesh(o, sphere(maxf(o.ability.radius_m, 1.0)), Color(color, 0.22), true)
			o._field.position = o._land_pos() - o.global_position_from_data()
			o._field.visible = false
		"turret":
			var base := mesh(o, box(Vector3(1.2, 1.2, 1.2)), color.darkened(0.3), false)
			base.position.y = 0.6
			var barrel := mesh(o, box(Vector3(0.25, 0.25, 1.2)), color, false)
			barrel.position = Vector3(0, 1.4, -0.4)
			add_bar(o, 2.2)
		"barrier":
			var w := o.ability.width_m
			var h := o.ability.height_m
			var wall := mesh(o, box(Vector3(w, h, 0.3)), Color(color, 0.45), true)
			wall.position.y = h / 2.0
		"strike":
			var disc := CylinderMesh.new()
			disc.top_radius = maxf(o.ability.radius_m, 1.0)
			disc.bottom_radius = disc.top_radius
			disc.height = 0.05
			var marker := mesh(o, disc, Color(color, 0.35), true)
			marker.position.y = 0.05
		"portal":
			var ring_in := mesh(o, ring(), color, false)
			ring_in.position.y = 1.0
			var ring_out := mesh(o, ring(), color, false)
			ring_out.position = Vector3(o.spawn_data["exit"]) - o.global_position_from_data() + Vector3.UP
		"ward":
			var pylon := mesh(o, box(Vector3(0.3, 1.4, 0.3)), color, false)
			pylon.position.y = 0.7
			add_bar(o, 1.8)


static func color_of(ability: AbilityData) -> Color:
	if ability == null:
		return Color(0.95, 0.8, 0.4)  # gadgets
	match ability.faction:
		WeaponData.Faction.LOURDE:
			return Color(1.0, 0.5, 0.2)
		WeaponData.Faction.TECHNO:
			return Color(0.4, 1.0, 0.55)
		WeaponData.Faction.EQUILIBRE:
			return Color(0.4, 0.7, 1.0)
	return Color(0.5, 0.75, 1.0)


static func mesh(o: AbilityObject, m: Mesh, color: Color, transparent: bool) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o.add_child(mi)
	return mi


static func sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	return s


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func ring() -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = PORTAL_RADIUS * 0.8
	t.outer_radius = PORTAL_RADIUS
	return t


static func add_bar(o: AbilityObject, height: float) -> void:
	var bar := Label3D.new()
	bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.font_size = 32
	bar.outline_size = 8
	bar.pixel_size = 0.004
	bar.position.y = height
	bar.text = "%d PV" % ceili(o.health)
	o.add_child(bar)
	o._bar = bar


static func add_box_shape(o: AbilityObject, size: Vector3, layer: int) -> void:
	o.collision_layer = layer
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	shape.position.y = size.y / 2.0
	o.add_child(shape)


static func build_sync(o: AbilityObject) -> void:
	var config := SceneReplicationConfig.new()
	var path := NodePath(".:health")
	config.add_property(path)
	config.property_set_spawn(path, true)
	config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "AbilitySync"
	sync.replication_config = config
	o.add_child(sync)
