extends SceneTree
## Outil : compile tous les scripts .gd du projet et n'affiche que ceux qui échouent.
## `--quit` seul ne charge que les scripts de la scène principale : il laisse passer des erreurs.
##   godot --headless --path . -s tools/check_scripts.gd
## Sortie : une ligne « ECHEC <chemin> » par script cassé, puis « scripts : N, échecs : M ».


func _initialize() -> void:
	var files: Array[String] = []
	_walk("res://", files)
	var failed := 0
	for path in files:
		var script := load(path) as Script
		if script == null or not (script.can_instantiate() or script.is_abstract()):
			print("ECHEC ", path)
			failed += 1
	print("scripts : %d, échecs : %d" % [files.size(), failed])
	quit(1 if failed > 0 else 0)


func _walk(dir: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if not sub.begins_with(".") and sub != "addons" and sub != "graphify-out":
			_walk(dir.path_join(sub), out)
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
