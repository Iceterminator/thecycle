extends RefCounted
## Visuel du cristal et de sa foreuse, construit en code (sur tous les peers), et
## texte flottant selon l'état. Les nœuds sont ajoutés comme enfants du Crystal.

const FOREUSE_MODEL: PackedScene = preload("res://assets/models/props/foreuse.gltf")
const DROP_HEIGHT := 18.0   ## hauteur de départ de la descente (m)
const DROP_TIME := 1.4      ## durée de la chute avec rebond (s)
const BIT_RAISE := 0.8      ## mèche relevée pendant la chute (m)
const BIT_TIME := 0.6       ## durée de l'abaissement de la mèche (s)

var crystal_mat: StandardMaterial3D
var drill: Node3D
var bit: Node3D
var label: Label3D
var _c: Crystal
var _tween: Tween
var _bit_rest_y := 0.0
var _prev_state: int = -1


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


## Foreuse : modèle 3D posé sur le cristal (cachée en IDLE), mèche « Meche » qui tourne.
func _build_drill() -> void:
	drill = FOREUSE_MODEL.instantiate()
	_c.add_child(drill)
	bit = drill.find_child("Meche", true, false) as Node3D
	if bit == null:   # modèle sans mèche : on garde un pivot vide
		bit = Node3D.new()
		drill.add_child(bit)
	_bit_rest_y = bit.position.y


## Descente : la foreuse tombe du ciel, rebondit au sol, puis la mèche s'abaisse.
func _play_drop() -> void:
	if _tween:
		_tween.kill()
	drill.position.y = DROP_HEIGHT
	bit.position.y = _bit_rest_y + BIT_RAISE
	_tween = _c.create_tween()
	_tween.tween_property(drill, "position:y", 0.0, DROP_TIME).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(bit, "position:y", _bit_rest_y, BIT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func update_look() -> void:
	if drill == null:
		return
	var state := _c.state
	var shown := state == Crystal.State.DEFENSE or state == Crystal.State.EXTRACT
	drill.visible = shown
	# Animation seulement au lancement vu en direct (pas pour un joueur qui arrive en cours).
	if state == Crystal.State.DEFENSE and _prev_state == Crystal.State.IDLE:
		_play_drop()
	elif not shown and _tween:
		_tween.kill()
		drill.position.y = 0.0
		bit.position.y = _bit_rest_y
	_prev_state = state
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
