class_name AmbianceParticules
extends Node3D
## Particules d'ambiance autour de la caméra, selon le biome où elle se trouve (visuel local) :
## Prairies = pollen et spores lumineuses, Désert = poussière soufflée, Neige = flocons,
## Marais = lucioles. Chaque nuée suit la caméra ; sa densité suit le poids du biome (fondu aux
## frontières). Moitié moins en qualité Bas. Créé par Niveaux avec la carte de partie.

const Fx := preload("res://systems/combat/weapon_effects_fx.gd")
const VERIF := 0.5  ## s entre deux lectures du biome sous la caméra

## Par biome (ordre de MapBiomes) : [nombre, vie (s), boîte (demi-taille), taille, couleur, additif,
## énergie, vitesse (direction * m/s), turbulence]
const REGLAGES := [
	[160, 9.0, Vector3(10, 4, 10), 0.09, Color(1.0, 0.92, 0.6, 0.9), true, 3.0, Vector3(0.3, 0.15, 0.1), 0.6],
	[180, 5.0, Vector3(12, 2, 12), 0.5, Color(0.8, 0.68, 0.52, 0.22), false, 1.0, Vector3(3.5, 0.2, 1.0), 1.2],
	[500, 7.0, Vector3(10, 6, 10), 0.11, Color(1.0, 1.0, 1.0, 1.0), false, 1.3, Vector3(0.4, -1.1, 0.2), 0.8],
	[60, 7.0, Vector3(10, 2, 10), 0.12, Color(0.75, 1.0, 0.45, 1.0), true, 5.0, Vector3(0.0, 0.1, 0.0), 1.5],
]

var _nuees: Array[GPUParticles3D] = []
var _attente := 0.0


func _ready() -> void:
	for r: Array in REGLAGES:
		var p := _nuee(r)
		add_child(p)
		_nuees.append(p)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for p in _nuees:
		p.global_position = cam.global_position
	_attente -= delta
	if _attente > 0.0:
		return
	_attente = VERIF
	var poids := MapBiomes.weights_at(cam.global_position.x, cam.global_position.z)
	var qualite := 0.5 if Config.SettingsStore.quality() == 0 else 1.0
	for i in _nuees.size():
		var w: float = poids[i] if i < poids.size() else 0.0
		_nuees[i].emitting = w > 0.05
		_nuees[i].amount_ratio = clampf(w, 0.0, 1.0) * qualite


func _nuee(r: Array) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = r[2]
	var vitesse: Vector3 = r[7]
	process.direction = vitesse.normalized() if vitesse.length() > 0.01 else Vector3.UP
	process.spread = 25.0
	process.initial_velocity_min = vitesse.length() * 0.7
	process.initial_velocity_max = vitesse.length() * 1.3
	process.gravity = Vector3.ZERO
	process.turbulence_enabled = true
	process.turbulence_noise_strength = r[8]
	process.turbulence_noise_scale = 4.0
	process.scale_min = 0.6
	process.scale_max = 1.4
	var fondu := Gradient.new()
	fondu.set_color(0, Color(1, 1, 1, 0))
	fondu.set_color(1, Color(1, 1, 1, 0))
	fondu.add_point(0.2, Color(1, 1, 1, 1))
	fondu.add_point(0.8, Color(1, 1, 1, 1))
	var rampe := GradientTexture1D.new()
	rampe.gradient = fondu
	process.color_ramp = rampe
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(r[3])
	quad.material = Fx.mat(r[4], r[5], r[6])
	var p := GPUParticles3D.new()
	p.amount = r[0]
	p.lifetime = r[1]
	p.preprocess = r[1]  # déjà en place au chargement
	p.local_coords = false
	p.emitting = false
	p.process_material = process
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var b: Vector3 = r[2]
	p.visibility_aabb = AABB(-b * 2.0, b * 4.0)
	return p
