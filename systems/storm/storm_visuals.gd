extends RefCounted
## Visuels de la Grande Marée (StormManager, clients) : mémorise l'ambiance de la scène,
## crée la pluie et le flash d'éclair. Remplit les membres visuels de `storm`.

static func build(storm: StormManager) -> void:
	var env_node := storm._world.get_node_or_null("WorldEnvironment") as WorldEnvironment if storm._world else null
	if env_node and env_node.environment:
		storm._env = env_node.environment
		storm._base["fog_density"] = storm._env.fog_density
		storm._base["fog_color"] = storm._env.fog_light_color
		storm._base["vol_density"] = storm._env.volumetric_fog_density
		storm._base["vol_albedo"] = storm._env.volumetric_fog_albedo
		storm._sky = storm._env.sky.sky_material as ShaderMaterial if storm._env.sky else null
		if storm._sky:
			storm._base["sky_top"] = storm._sky.get_shader_parameter("couleur_haut")
			storm._base["sky_horizon"] = storm._sky.get_shader_parameter("couleur_horizon")
			storm._base["couverture"] = storm._sky.get_shader_parameter("couverture")
	storm._sun = storm._world.get_node_or_null("Sun") as DirectionalLight3D if storm._world else null
	if storm._sun:
		storm._base["sun_energy"] = storm._sun.light_energy
		storm._base["sun_color"] = storm._sun.light_color
	storm._rain = _make_rain()
	storm.add_child(storm._rain)
	var layer := CanvasLayer.new()
	layer.layer = 5
	storm.add_child(layer)
	storm._flash = ColorRect.new()
	storm._flash.color = Color(0.8, 0.7, 1.0)
	storm._flash.modulate.a = 0.0
	storm._flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(storm._flash)
	storm._flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Gouttes : fins traits verticaux qui tombent dans une boîte au-dessus de la caméra.
static func _make_rain() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(25.0, 1.0, 25.0)
	process.direction = Vector3(0.1, -1.0, 0.0)
	process.spread = 3.0
	process.initial_velocity_min = 28.0
	process.initial_velocity_max = 32.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.albedo_color = Color(0.78, 0.78, 0.95, 0.35)
	var drop := QuadMesh.new()
	drop.size = Vector2(0.02, 0.7)
	drop.material = mat
	var rain := GPUParticles3D.new()
	rain.amount = 3000
	rain.lifetime = 0.9
	rain.emitting = false
	rain.process_material = process
	rain.draw_pass_1 = drop
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.visibility_aabb = AABB(Vector3(-30, -40, -30), Vector3(60, 45, 60))
	return rain
