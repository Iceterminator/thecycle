extends RefCounted
## Explosion (grenades, roquettes, capacités explosives), chez les clients : éclair de lumière,
## boule de feu lumineuse qui gonfle, débris projetés, fumée sombre qui monte et reste quelques secondes.

const Fx := preload("res://systems/combat/weapon_effects_fx.gd")
const FEU := Color(1.0, 0.55, 0.18)
const FUMEE := Color(0.22, 0.2, 0.19, 0.6)


static func build(world: Node3D, point: Vector3, radius: float) -> void:
	var tree := world.get_tree()
	# Éclair : lumière forte et brève qui éclaire le décor autour.
	var lumiere := OmniLight3D.new()
	lumiere.light_color = FEU
	lumiere.light_energy = 8.0
	lumiere.omni_range = radius * 4.0 + 4.0
	world.add_child(lumiere)
	lumiere.global_position = point + Vector3.UP * 0.5
	var t := lumiere.create_tween()
	t.tween_property(lumiere, "light_energy", 0.0, 0.35)
	t.tween_callback(lumiere.queue_free)
	# Boule de feu : plaques lumineuses qui gonflent vite et s'éteignent.
	var feu := Fx.particules(world, point, 14, 0.45, Fx.mat(FEU, true, 3.0), radius * 0.9)
	feu.direction = Vector3.UP
	feu.spread = 180.0
	feu.initial_velocity_min = radius * 1.5
	feu.initial_velocity_max = radius * 3.0
	feu.damping_min = radius * 5.0
	feu.damping_max = radius * 7.0
	feu.angle_max = 360.0
	var gonfle := Curve.new()
	gonfle.add_point(Vector2(0, 0.4))
	gonfle.add_point(Vector2(1, 1.3))
	feu.scale_amount_curve = gonfle
	# Débris sombres projetés, qui retombent.
	var debris := Fx.particules(world, point, 16, 1.1, Fx.mat(Color(0.12, 0.1, 0.09, 1.0), false), 0.12)
	debris.direction = Vector3.UP
	debris.spread = 70.0
	debris.initial_velocity_min = 4.0
	debris.initial_velocity_max = 9.0
	debris.gravity = Vector3(0, -14.0, 0)
	debris.scale_amount_min = 0.5
	debris.scale_amount_max = 1.5
	# Fumée : colonne sombre qui monte lentement et s'étale, visible ~4 s.
	var fumee := Fx.particules(world, point + Vector3.UP * 0.3, 18, 4.0, Fx.mat(FUMEE, false), radius * 1.2)
	fumee.explosiveness = 0.7
	fumee.direction = Vector3.UP
	fumee.spread = 25.0
	fumee.initial_velocity_min = 0.8
	fumee.initial_velocity_max = 2.0
	fumee.damping_min = 0.3
	fumee.damping_max = 0.6
	fumee.angle_max = 360.0
	fumee.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fumee.emission_sphere_radius = radius * 0.4
	var etale := Curve.new()
	etale.add_point(Vector2(0, 0.6))
	etale.add_point(Vector2(1, 2.2))
	fumee.scale_amount_curve = etale
	Events.camera_shake_requested.emit(point, 0.9, radius * 4.0)
