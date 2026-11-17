class_name DropPod
extends Node3D
## Capsule de largage (purement visuelle). Créée par le serveur via le LootSpawner
## à sa position d'atterrissage ; chaque peer anime la chute localement pendant
## Config.DROP_POD_FALL_TIME, puis la capsule s'ouvre en pétales.
## L'objet acheté est un Pickup séparé, posé par le LootManager à l'atterrissage.

const PETALS := 4

var _elapsed: float = 0.0
var _landed: bool = false
var _body: Node3D
var _trail: MeshInstance3D
var _nose: MeshInstance3D
var _petals: Array[Node3D] = []
var _flash: OmniLight3D


func _ready() -> void:
	_build()
	_body.position.y = Config.DROP_POD_HEIGHT


func _process(delta: float) -> void:
	if _landed:
		return
	_elapsed += delta
	var t := clampf(_elapsed / Config.DROP_POD_FALL_TIME, 0.0, 1.0)
	# Accélère en tombant (t²) : arrive vite au sol, on la voit venir de loin.
	_body.position.y = Config.DROP_POD_HEIGHT * (1.0 - t * t)
	if t >= 1.0:
		_land()


func _land() -> void:
	_landed = true
	_body.position.y = 0.0
	_trail.visible = false
	_nose.visible = false
	var tween := create_tween().set_parallel()
	for petal in _petals:
		tween.tween_property(petal, "rotation:x", deg_to_rad(-75.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_flash.light_energy = 6.0
	tween.tween_property(_flash, "light_energy", 0.0, 0.6)


func _build() -> void:
	var shell_mat := StandardMaterial3D.new()
	shell_mat.albedo_color = Color(0.85, 0.87, 0.9)
	shell_mat.metallic = 0.4
	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = Color(0.95, 0.55, 0.15)
	accent_mat.emission_enabled = true
	accent_mat.emission = Color(0.95, 0.45, 0.1)

	_body = Node3D.new()
	add_child(_body)

	# Socle.
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.65
	base_mesh.bottom_radius = 0.75
	base_mesh.height = 0.2
	base_mesh.radial_segments = 8
	base.mesh = base_mesh
	base.material_override = accent_mat
	base.position.y = 0.1
	_body.add_child(base)

	# 4 pétales : pivot au bas de la paroi, ils s'ouvrent vers l'extérieur.
	for i in PETALS:
		var pivot := Node3D.new()
		pivot.rotation.y = TAU * i / PETALS
		var hinge := Node3D.new()
		hinge.position = Vector3(0, 0.2, -0.55)
		pivot.add_child(hinge)
		var panel := MeshInstance3D.new()
		var panel_mesh := BoxMesh.new()
		panel_mesh.size = Vector3(0.8, 1.3, 0.08)
		panel.mesh = panel_mesh
		panel.material_override = shell_mat
		panel.position.y = 0.65
		hinge.add_child(panel)
		_body.add_child(pivot)
		_petals.append(hinge)

	# Nez conique (disparaît à l'ouverture).
	_nose = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.6
	cone.height = 0.6
	cone.radial_segments = 8
	_nose.mesh = cone
	_nose.material_override = accent_mat
	_nose.position.y = 1.8
	_body.add_child(_nose)

	# Traînée lumineuse au-dessus pendant la chute.
	_trail = MeshInstance3D.new()
	var trail_mesh := CylinderMesh.new()
	trail_mesh.top_radius = 0.05
	trail_mesh.bottom_radius = 0.35
	trail_mesh.height = 8.0
	trail_mesh.radial_segments = 6
	_trail.mesh = trail_mesh
	var trail_mat := StandardMaterial3D.new()
	trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mat.albedo_color = Color(1.0, 0.75, 0.3, 0.45)
	_trail.material_override = trail_mat
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.position.y = 2.1 + trail_mesh.height / 2.0
	_body.add_child(_trail)

	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.7, 0.3)
	_flash.omni_range = 6.0
	_flash.light_energy = 0.0
	_flash.position.y = 1.0
	add_child(_flash)
