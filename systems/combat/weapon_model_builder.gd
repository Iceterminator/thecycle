extends RefCounted
## Construction du modèle d'arme tenu en main (WeaponModel.build) : rotation, teinte,
## mise à l'échelle et repère Poignee posé sur l'origine.

## Matériaux teintés partagés (matériau d'origine + teinte → copie) : une copie par arme
## libérée avec elle provoquait des erreurs du moteur (« material is null »).
static var _tint_cache: Dictionary = {}


static func _tinted(source: BaseMaterial3D, tint: Color) -> BaseMaterial3D:
	var key := [source, tint]
	if not _tint_cache.has(key):
		var mat := source.duplicate() as BaseMaterial3D
		mat.albedo_color *= tint
		_tint_cache[key] = mat
	return _tint_cache[key]


## Modèle de l'arme prêt à poser : tourné, mis à l'échelle, poignée sur l'origine, sans ombre.
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
		if weapon.model_tint != Color.WHITE:
			for s in mesh.mesh.get_surface_count():
				var mat := mesh.get_active_material(s) as BaseMaterial3D
				if mat:
					mesh.set_surface_override_material(s, _tinted(mat, weapon.model_tint))
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
	# Le repère Poignee de la scène du modèle sur l'origine : c'est lui qui est posé dans la main.
	var marker := instance.find_child("Poignee", true, false) as Node3D
	var grip := box.get_center()
	if marker:
		grip = Basis.from_euler(instance.rotation) * _local_in(instance, marker)
	instance.position = -grip * scale_factor
	return pivot


## Position de `node` dans le repère de `ancestor` (exclu : sa propre transformation n'est pas comptée).
static func _local_in(ancestor: Node3D, node: Node3D) -> Vector3:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != ancestor:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf.origin
