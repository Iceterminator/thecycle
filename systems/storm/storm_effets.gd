extends RefCounted
## Effets de la Grande Marée chez les clients (fonctions statiques) : éclairs visibles dans le
## ciel (trait brisé lumineux + lumière brève sur le décor), rafales de poussière au ras du sol.
## Appelé par StormManager ; la pluie est dans storm_visuals.gd.

const Fx := preload("res://systems/combat/weapon_effects_fx.gd")
const COULEUR_ECLAIR := Color(0.8, 0.7, 1.0)
const DISTANCE_MIN := 50.0   ## m : l'éclair tombe entre ces distances de la caméra
const DISTANCE_MAX := 160.0
const HAUTEUR := 140.0
const DUREE := 0.25


## Un éclair : zigzag du ciel au sol, à distance de la caméra, qui scintille puis s'éteint.
static func eclair(parent: Node3D, camera_pos: Vector3) -> void:
	var angle := randf() * TAU
	var dist := randf_range(DISTANCE_MIN, DISTANCE_MAX)
	var sol := camera_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	sol.y = MapTerrain.height_at(sol.x, sol.z)
	var haut := sol + Vector3(randf_range(-20.0, 20.0), HAUTEUR, randf_range(-20.0, 20.0))
	var racine := Node3D.new()
	parent.add_child(racine)
	_zigzag(racine, haut, sol, 0.45, 4)
	var lumiere := OmniLight3D.new()
	lumiere.light_color = COULEUR_ECLAIR
	lumiere.light_energy = 12.0
	lumiere.omni_range = 120.0
	lumiere.shadow_enabled = false
	racine.add_child(lumiere)
	lumiere.global_position = sol + Vector3.UP * 30.0
	var t := racine.create_tween()
	for i in 3:  # scintillement
		t.tween_property(racine, "visible", false, 0.04)
		t.tween_property(racine, "visible", true, 0.03)
	t.tween_property(lumiere, "light_energy", 0.0, DUREE)
	t.tween_callback(racine.queue_free)


## Trait brisé de `a` à `b` en segments lumineux ; quelques branches plus fines.
static func _zigzag(racine: Node3D, a: Vector3, b: Vector3, largeur: float, branches: int) -> void:
	var segments := 12
	var prec := a
	for i in range(1, segments + 1):
		var t := float(i) / segments
		var p := a.lerp(b, t)
		if i < segments:
			p += Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * a.distance_to(b) * 0.05
		_segment(racine, prec, p, largeur)
		if branches > 0 and randf() < 0.3:
			var fin := p + Vector3(randf_range(-1, 1), -randf_range(0.5, 1.0), randf_range(-1, 1)) * a.distance_to(b) * 0.2
			_zigzag(racine, p, fin, largeur * 0.5, 0)
			branches -= 1
		prec = p


static func _segment(racine: Node3D, a: Vector3, b: Vector3, largeur: float) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(largeur, largeur, a.distance_to(b))
	mi.mesh = box
	var m := Fx.mat(COULEUR_ECLAIR, true, 6.0).duplicate() as StandardMaterial3D
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m.albedo_texture = null
	m.vertex_color_use_as_albedo = false
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	racine.add_child(mi)
	var dir := (b - a).normalized()
	mi.look_at_from_position((a + b) / 2.0, b, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)


## Rafales : grandes bouffées de poussière qui balaient le sol autour de la caméra (vent de travers).
static func rafales() -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(30.0, 1.5, 30.0)
	process.direction = Vector3(1.0, 0.05, 0.3)
	process.spread = 10.0
	process.initial_velocity_min = 7.0
	process.initial_velocity_max = 12.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.6
	process.scale_max = 1.6
	process.angle_max = 360.0
	var fondu := Gradient.new()
	fondu.set_color(0, Color(1, 1, 1, 0))
	fondu.set_color(1, Color(1, 1, 1, 0))
	fondu.add_point(0.3, Color(1, 1, 1, 1))
	var rampe := GradientTexture1D.new()
	rampe.gradient = fondu
	process.color_ramp = rampe
	var quad := QuadMesh.new()
	quad.size = Vector2(5.0, 3.0)
	quad.material = Fx.mat(Color(0.55, 0.5, 0.48, 0.22), false)
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 3.5
	p.emitting = false
	p.process_material = process
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-50, -5, -50), Vector3(100, 15, 100))
	return p
