extends SceneTree
## Découpe une planche 3×3 d'icônes de quêtes (blanc sur noir) en 9 PNG transparents
## (blanc, alpha = luminosité) dans assets/icons/quests/<id>.png, ordre de quest_draws.
## Écrit aussi un aperçu teinté (--preview=chemin.png).
## godot --headless --path . -s tools/cut_quest_icons.gd -- --src=planche.jpg [--preview=apercu.png]

const OUT_DIR := "res://assets/icons/quests/"
const SIZE := 256
const IDS := ["crystal", "biomass_collector", "drones", "extractor", "facility",
		"lumicep_collector", "relic", "storm_collector", "uplink"]
const PREVIEW_COLORS := [Color("B366FF"), Color("F28026"), Color("B3D9FF"), Color("4DF2D9"),
		Color("5999FF"), Color("80FF99"), Color("FFBF33"), Color("E05CFF"), Color("FF6A4D")]


func _init() -> void:
	var src := ""
	var preview_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--src="):
			src = arg.substr(6)
		elif arg.begins_with("--preview="):
			preview_path = arg.substr(10)
	var sheet := Image.load_from_file(src)
	if sheet == null:
		push_error("planche introuvable : " + src)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var cell := sheet.get_width() / 3
	var preview := Image.create(SIZE * 3, SIZE * 3, false, Image.FORMAT_RGBA8)
	preview.fill(Color(0.06, 0.07, 0.09))
	for k in IDS.size():
		var icon := sheet.get_region(Rect2i((k % 3) * cell, (k / 3) * cell, cell, cell))
		icon.convert(Image.FORMAT_RGBA8)
		icon.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		for y in SIZE:
			for x in SIZE:
				var a := clampf((icon.get_pixel(x, y).get_luminance() - 0.12) / 0.75, 0.0, 1.0)
				icon.set_pixel(x, y, Color(1, 1, 1, a))
		icon.save_png(OUT_DIR + IDS[k] + ".png")
		var tinted := icon.duplicate() as Image
		for y in SIZE:
			for x in SIZE:
				var c: Color = PREVIEW_COLORS[k]
				tinted.set_pixel(x, y, Color(c.r, c.g, c.b, tinted.get_pixel(x, y).a))
		preview.blend_rect(tinted, Rect2i(0, 0, SIZE, SIZE), Vector2i((k % 3) * SIZE, (k / 3) * SIZE))
	if preview_path != "":
		preview.save_png(preview_path)
	print("icônes écrites : ", IDS.size())
	quit(0)
