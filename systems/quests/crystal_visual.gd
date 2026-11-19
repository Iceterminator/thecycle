extends RefCounted
## Visuel du cristal et de sa foreuse, construit en code (sur tous les peers), et
## texte flottant selon l'état. Les nœuds sont ajoutés comme enfants du Crystal.

var crystal_mat: StandardMaterial3D
var drill: Node3D
var bit: Node3D
var label: Label3D
var _c: Crystal


func _init(crystal: Crystal) -> void:
	_c = crystal


func build() -> void:
	var data := _c.data
	# Prismes lumineux, couleur selon le niveau (assombris une fois épuisé).
	crystal_mat = StandardMaterial3D.new()
	crystal_mat.albedo_color = data.color
	crystal_mat.emission_enabled = true
	crystal_mat.emission = data.color
	crystal_mat.emission_energy_multiplier = 1.5
	crystal_mat.roughness = 0.2
	# Modèle (socle + grappe) : le maillage « Cristal » reçoit le matériau ci-dessus.
	if data.model:
		var model := data.model.instantiate()
		_c.add_child(model)
		var prisms := model.find_child("Cristal", true, false) as MeshInstance3D
		if prisms:
			prisms.material_override = crystal_mat

	var light := OmniLight3D.new()
	light.light_color = data.color
	light.omni_range = 5.0
	light.light_energy = 1.2
	light.position.y = 1.5
	_c.add_child(light)
	_build_drill()

	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.outline_size = 14
	label.pixel_size = 0.007
	label.position.y = 4.4
	_c.add_child(label)


## Foreuse : 4 pieds + une mèche qui tourne au-dessus du cristal (cachée en IDLE).
func _build_drill() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.8, 0.6, 0.2)
	metal.metallic = 0.6
	drill = Node3D.new()
	_c.add_child(drill)
	for i in 4:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.15, 3.4, 0.15)
		leg.mesh = leg_mesh
		leg.material_override = metal
		var a := TAU * i / 4.0 + PI / 4.0
		leg.position = Vector3(cos(a) * 1.2, 1.6, sin(a) * 1.2)
		leg.rotation = Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25)
		drill.add_child(leg)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(1.0, 0.5, 1.0)
	head.mesh = head_mesh
	head.material_override = metal
	head.position.y = 3.3
	drill.add_child(head)
	bit = Node3D.new()
	bit.position.y = 3.05
	drill.add_child(bit)
	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.25
	tip_mesh.bottom_radius = 0.0
	tip_mesh.height = 0.8
	tip_mesh.radial_segments = 5
	tip.mesh = tip_mesh
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.4, 0.4, 0.45)
	tip.material_override = tip_mat
	tip.position.y = -0.4
	bit.add_child(tip)


func update_look() -> void:
	if drill == null:
		return
	var state := _c.state
	drill.visible = state == Crystal.State.DEFENSE or state == Crystal.State.EXTRACT
	var dim := state == Crystal.State.DONE
	crystal_mat.emission_enabled = not dim
	crystal_mat.albedo_color = _c.data.color.darkened(0.7) if dim else _c.data.color
	update_label()


func update_label() -> void:
	if label == null:
		return
	var data := _c.data
	var title := "%s %s" % [data.display_name, data.difficulty_name]
	match _c.state:
		Crystal.State.IDLE:
			label.text = "%s\n+%d pts de Forage" % [title, data.objective_points]
			label.modulate = data.color.lightened(0.35)   # lisible même pour le violet foncé
		Crystal.State.DEFENSE:
			var wave_text := ""
			if _c.next_wave_in > 0.0:
				wave_text = "Vague %d/%d dans %d s" % [_c.wave_index + 1, data.waves.size(), ceili(_c.next_wave_in)]
			else:
				wave_text = "Vague %d/%d — %d monstres" % [_c.wave_index, data.waves.size(), _c.monsters_left]
			label.text = "Foreuse %d / %d\n%s" % [ceili(_c.drill_health), int(data.drill_health), wave_text]
			label.modulate = Color(1, 0.9, 0.5).lerp(Color(1, 0.3, 0.25), 1.0 - _c.drill_health / data.drill_health)
		Crystal.State.EXTRACT:
			label.text = "%s\nExtraction prête !" % title
			label.modulate = Color(0.5, 1, 0.5)
		Crystal.State.DONE:
			label.text = "%s\nÉpuisé" % title
			label.modulate = Color(1, 1, 1, 0.5)
		Crystal.State.FAILED:
			label.text = "%s\nForeuse détruite !" % title
			label.modulate = Color(1, 0.3, 0.25)
