extends RefCounted
## Secousse de la caméra du joueur local (explosions, dégâts reçus, recul des tirs).
## Passe par h_offset / v_offset / roulis : la direction du tir ne change pas.
## Les constantes de réglage restent dans WeaponModel.

var _trauma := 0.0
var _time := 0.0


## Ajoute de la secousse (plafonnée à 1).
func add(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


## Secousse d'une explosion, atténuée par la distance à la caméra.
func add_from_point(camera: Camera3D, point: Vector3, strength: float, reach: float) -> void:
	var falloff := 1.0 - camera.global_position.distance_to(point) / maxf(reach, 0.01)
	if falloff > 0.0:
		add(strength * falloff)


func update(delta: float, cam: Camera3D) -> void:
	_trauma = maxf(_trauma - delta * WeaponModel.SHAKE_DECAY, 0.0)
	_time += delta * 30.0
	var s := _trauma * _trauma
	cam.h_offset = sin(_time * 1.3) * WeaponModel.SHAKE_OFFSET * s
	cam.v_offset = sin(_time * 1.7 + 1.0) * WeaponModel.SHAKE_OFFSET * s
	cam.rotation.z = sin(_time * 1.1 + 2.0) * deg_to_rad(WeaponModel.SHAKE_ROLL_DEG) * s
