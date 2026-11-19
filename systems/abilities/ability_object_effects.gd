extends RefCounted
## Effets visuels ponctuels d'un AbilityObject (traceur de tourelle, explosion), appelés par ses RPC.
## Les effets sont ajoutés au monde, pas au conteneur du spawner.

const Visuals := preload("res://systems/abilities/ability_object_visuals.gd")


## Trait lumineux bref entre `from` et `to`.
static func show_tracer(o: AbilityObject, from: Vector3, to: Vector3) -> void:
	var bar := BoxMesh.new()
	bar.size = Vector3(0.05, 0.05, from.distance_to(to))
	var mi := MeshInstance3D.new()
	mi.mesh = bar
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Visuals.color_of(o.ability)
	mi.material_override = mat
	o.get_parent().get_parent().add_child(mi)
	mi.global_position = (from + to) / 2.0
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	o.get_tree().create_timer(0.06).timeout.connect(mi.queue_free)


## Boule d'explosion qui grossit puis s'efface, avec secousse de caméra.
static func show_boom(o: AbilityObject, point: Vector3, radius: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.55, 0.15, 0.7)
	var ball := MeshInstance3D.new()
	ball.mesh = Visuals.sphere(1.0)
	ball.material_override = mat
	o.get_parent().get_parent().add_child(ball)
	ball.global_position = point
	ball.scale = Vector3.ONE * 0.2
	Events.camera_shake_requested.emit(point, 0.9, radius * 4.0)
	var tween := ball.create_tween().set_parallel()
	tween.tween_property(ball, "scale", Vector3.ONE * radius, 0.25)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.chain().tween_callback(ball.queue_free)
