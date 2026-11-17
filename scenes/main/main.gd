extends Node
## Scène principale : menu Héberger / Rejoindre, puis charge le monde.
## Le monde est toujours ajouté sous /root/Main/World, sur le serveur
## comme sur les clients : les chemins réseau doivent être identiques.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")

@onready var menu: CanvasLayer = $Menu
@onready var address_edit: LineEdit = %AddressEdit
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	Net.hosting_started.connect(_load_world)
	Net.connected_to_server.connect(func(): status_label.text = "Connecté !")
	Net.connection_failed.connect(_back_to_menu.bind("Échec de connexion."))
	Net.server_disconnected.connect(_back_to_menu.bind("Le serveur s'est arrêté."))
	if Net.is_dedicated_server:
		menu.hide()
		return
	# Raccourcis de test : godot -- --host   ou   godot -- --join=127.0.0.1
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			_on_host_pressed.call_deferred()
		elif arg.begins_with("--join="):
			address_edit.text = arg.trim_prefix("--join=")
			_on_join_pressed.call_deferred()


func _on_host_pressed() -> void:
	status_label.text = "Lancement du serveur..."
	Net.host()


func _on_join_pressed() -> void:
	var address := address_edit.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	status_label.text = "Connexion à %s..." % address
	# On charge le monde tout de suite : le serveur y fera apparaître les joueurs.
	if Net.join(address) == OK:
		_load_world()


func _load_world() -> void:
	if has_node("World"):
		return
	menu.hide()
	var world := WORLD_SCENE.instantiate()
	world.name = "World"
	add_child(world)


func _back_to_menu(message: String) -> void:
	if has_node("World"):
		$World.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.show()
	status_label.text = message
