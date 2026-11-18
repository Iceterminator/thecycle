class_name WeaponModel
extends Node3D
## Arme tenue en main (modèle 3D de WeaponData.model), créée par le Player sur tous les
## peers, enfant de la tête : le joueur local la voit en bas à droite de l'écran (au centre
## quand il vise), les autres joueurs la voient devant lui, orientée comme son regard
## (rotation de la tête synchronisée). Suit l'arme en main (Inventory.active_weapon_changed).
## Sans modèle pour l'arme en main, rien n'est affiché.
## Le modèle est tourné (model_rotation_deg), mis à l'échelle (model_length) et centré.

const HIP_POSITION := Vector3(0.24, -0.21, -0.48)
const AIM_POSITION := Vector3(0.0, -0.13, -0.38)
const AIM_SPEED := 12.0

var player: Player
var _current: WeaponData
var _offset: Vector3 = Vector3.ZERO


func setup(owner_player: Player) -> void:
	player = owner_player
	position = HIP_POSITION
	player.inventory.active_weapon_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var weapon := player.inventory.get_active_weapon()
	if weapon == _current:
		return
	_current = weapon
	for child in get_children():
		child.queue_free()
	if weapon and weapon.model:
		_offset = weapon.model_offset
		add_child(build(weapon))


func _process(delta: float) -> void:
	if player == null:
		return
	var local := player.is_multiplayer_authority()
	visible = not player.health.is_dead and not player.is_evacuated and (local or player.body_mesh.visible)
	var aiming := local and player.weapon.is_aiming
	var target := (AIM_POSITION if aiming else HIP_POSITION) + _offset
	position = position.lerp(target, clampf(delta * AIM_SPEED, 0.0, 1.0))


## Modèle de l'arme prêt à poser : tourné, mis à l'échelle, centré sur l'origine, sans ombre.
static func build(weapon: WeaponData) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Model"
	var instance := weapon.model.instantiate() as Node3D
	pivot.add_child(instance)
	instance.rotation_degrees = weapon.model_rotation_deg
	# Boîte englobante de tous les maillages, dans le repère du pivot (avant mise à l'échelle).
	var box := AABB()
	var first := true
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var xf := Transform3D.IDENTITY
		var n: Node = mesh
		while n != pivot:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var part := xf * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	if first:
		return pivot
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var scale_factor := weapon.model_length / maxf(longest, 0.001)
	instance.scale = Vector3.ONE * scale_factor
	instance.position = -box.get_center() * scale_factor
	return pivot
