extends RefCounted
## Effets visuels de Weapon : impacts (éclats, point rouge sur une cible) et explosions.
## Utilise les outils de dessin de WeaponEffects (matières, formes temporaires).

const Fx := preload("res://systems/combat/weapon_effects_fx.gd")
const Explosion := preload("res://systems/combat/weapon_effects_explosion.gd")

var _w: Weapon
var _fx: RefCounted  # WeaponEffects


func _init(weapon: Weapon, effects: RefCounted) -> void:
	_w = weapon
	_fx = effects


func spawn_impact(world: Node3D, point: Vector3, kind: int) -> void:
	if kind == Weapon.HitKind.NONE:
		return
	var data := _w.data
	var sphere := SphereMesh.new()
	sphere.radius = 0.06 * data.impact_scale
	sphere.height = sphere.radius * 2.0
	var color := Color(1.0, 0.15, 0.1) if kind == Weapon.HitKind.TARGET else data.tracer_color
	_fx._spawn_mesh(world, sphere, color, point, 0.15)
	# Éclats qui jaillissent puis retombent.
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 10
	sparks.lifetime = 0.35
	var chip := BoxMesh.new()
	chip.size = Vector3.ONE * 0.025 * data.impact_scale
	sparks.mesh = chip
	sparks.material_override = Fx.mat(color.lightened(0.3), true, 3.0)  # étincelles lumineuses
	sparks.gravity = Vector3(0, -12.0, 0)
	sparks.direction = Vector3.UP
	sparks.spread = 80.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 5.0
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.5
	sparks.finished.connect(sparks.queue_free)
	world.add_child(sparks)
	sparks.global_position = point
	sparks.emitting = true
	if kind == Weapon.HitKind.WORLD:  # sol, roche, décor : un peu de poussière
		Fx.poussiere(world, point, data.impact_scale)


## Explosion : boule de feu, éclair, débris et fumée (weapon_effects_explosion.gd).
func show_explosion(point: Vector3, radius: float) -> void:
	var world: Node3D = _fx._effects_parent()
	if world:
		Explosion.build(world, point, radius)
