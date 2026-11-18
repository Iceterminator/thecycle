extends SceneTree
## Outil : fabrique l'icône (image de profil, fond transparent) de chaque arme qui a un
## modèle 3D (WeaponData.model), dans assets/icons/weapons/<id>.png, puis la branche dans
## le champ hud_icon de l'arme (HUD, lobby, boutique l'affichent à la place du dessin).
## À lancer AVEC fenêtre (le mode --headless ne fait pas de rendu), depuis la racine :
##   godot --path . -s tools/render_weapon_icons.gd
##   godot --headless --path . --import          (Godot importe les nouvelles images)
##   godot --headless --path . -s tools/render_weapon_icons.gd -- --assign
## Pas de référence aux classes du projet par leur nom (script lancé avec -s).

const WEAPONS_DIR := "res://data/weapons/"
const ICONS_DIR := "res://assets/icons/weapons/"
const SIZE := Vector2i(640, 240)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var assign := "--assign" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ICONS_DIR)
	var builder: Script = load("res://systems/combat/weapon_model.gd")
	var count := 0
	for file in ResourceLoader.list_directory(WEAPONS_DIR):
		if not file.ends_with(".tres"):
			continue
		var weapon: Resource = load(WEAPONS_DIR + file)
		if weapon == null or weapon.get("model") == null:
			continue
		var path := ICONS_DIR + String(weapon.id) + ".png"
		if assign:
			if ResourceLoader.exists(path):
				weapon.set("hud_icon", load(path))
				ResourceSaver.save(weapon, WEAPONS_DIR + file)
				print("[Icônes] %s : icône branchée" % weapon.id)
				count += 1
			continue
		await _render(builder, weapon, path)
		count += 1
	print("[Icônes] %d arme(s) traitée(s)%s" % [count, "" if assign else " — lancer --import puis -- --assign"])
	quit(0)


## Vue de profil orthographique (canon vers la droite), éclairage doux, fond transparent.
func _render(builder: Script, weapon: Resource, path: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.82, 0.95)
	env.environment.ambient_light_energy = 0.9
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 60, 0)
	key.light_energy = 1.3
	viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, -120, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.7, 0.85, 1.0)
	viewport.add_child(rim)
	var model: Node3D = builder.build(weapon)
	viewport.add_child(model)
	# Boîte englobante du modèle mis à l'échelle, pour cadrer.
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var n: Node = mesh
		while n != model:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var part := xf * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect := float(SIZE.x) / float(SIZE.y)
	camera.size = maxf(box.size.y * 1.15, box.size.z * 1.12 / aspect)
	viewport.add_child(camera)
	# Caméra sur le côté droit (+X), regard vers -X : le canon (-Z) apparaît à droite.
	camera.position = box.get_center() + Vector3(2.0, 0, 0)
	camera.look_at(box.get_center(), Vector3.UP)
	for i in 4:
		await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	# Recadrage au plus près de l'arme (petite marge) : elle remplit mieux les cases.
	var used := image.get_used_rect().grow(6).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if used.has_area():
		image = image.get_region(used)
	image.save_png(path)
	print("[Icônes] %s -> %s" % [weapon.id, path])
	viewport.queue_free()
