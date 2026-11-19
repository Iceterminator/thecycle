extends SceneTree
## Lanceur d'un test réseau (voir tools/run_tests.sh) :
##   godot --headless --path . -s tests/runner.gd -- --test=test_01_connexion_largage --host --name=ZzTestHote
## Un script lancé avec -s est compilé avant les autoloads : il ne peut pas citer les classes
## du jeu. On charge donc le test (un Node) seulement ici, une fois les autoloads en place.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var test_name := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test="):
			test_name = arg.trim_prefix("--test=")
	var path := "res://tests/%s.gd" % test_name
	if test_name == "" or not ResourceLoader.exists(path):
		print("TEST ECHEC : test introuvable (%s)" % path)
		quit(1)
		return
	var test := (load(path) as GDScript).new() as Node
	test.name = "Test"
	root.add_child(test)
