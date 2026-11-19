extends Node
## Scène principale : menu (pseudo, Héberger / Rejoindre, serveurs récents, Partie rapide),
## puis charge le monde.
## Le monde est toujours ajouté sous /root/Main/World, sur le serveur
## comme sur les clients : les chemins réseau doivent être identiques.
## Le pseudo et les derniers serveurs rejoints sont gardés dans user://settings.cfg (ce
## poste) ; le profil (réputation, équipement) est gardé par le serveur (ProfileManager).

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
const MainMenuExtras := preload("res://scenes/main/main_menu_extras.gd")

@onready var menu: CanvasLayer = $Menu
@onready var address_edit: LineEdit = %AddressEdit
@onready var host_button: Button = %HostButton
@onready var join_button: Button = %JoinButton
@onready var status_label: Label = %StatusLabel

var name_edit: LineEdit
var _extras := MainMenuExtras.new()
var _quick_queue: Array = []   # Partie rapide : adresses encore à essayer


func _ready() -> void:
	UiStyle.apply_fonts()  # police de toute l'interface (Barlow Condensed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	Net.hosting_started.connect(_load_world)
	Net.connected_to_server.connect(func():
		status_label.text = "Connecté !"
		_quick_queue.clear()
		_remember(Net.last_address))
	Net.connection_failed.connect(_on_connection_failed)
	Net.server_disconnected.connect(_back_to_menu.bind("Le serveur s'est arrêté."))
	if Net.is_dedicated_server:
		menu.hide()
		return
	_build_extra_menu()
	_load_settings()
	# Raccourcis de test : godot -- --host   ou   godot -- --join=127.0.0.1   (--name=Pseudo)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--name="):
			name_edit.text = arg.trim_prefix("--name=")
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			_on_host_pressed.call_deferred()
		elif arg.begins_with("--join="):
			address_edit.text = arg.trim_prefix("--join=")
			_on_join_pressed.call_deferred()


func _build_extra_menu() -> void:
	_extras.build(host_button, status_label, _on_quick_play)
	name_edit = _extras.name_edit


func _load_settings() -> void:
	_extras.load_settings()
	_refresh_recent()


func _save_settings() -> void:
	_extras.save_settings()


func _remember(address: String) -> void:
	if address == "":
		return
	_extras.remember(address)
	_refresh_recent()


func _refresh_recent() -> void:
	if _extras.recent_box == null:
		return
	for child in _extras.recent_box.get_children():
		child.queue_free()
	for address in _extras.recent:
		var b := Button.new()
		b.text = address
		b.pressed.connect(func() -> void:
			address_edit.text = address
			_on_join_pressed())
		_extras.recent_box.add_child(b)


func _use_name() -> void:
	Net.player_name = name_edit.text.strip_edges() if name_edit else ""
	if name_edit:
		_save_settings()


func _on_host_pressed() -> void:
	_use_name()
	status_label.text = "Lancement du serveur..."
	Net.host()


func _on_join_pressed() -> void:
	_use_name()
	var address := address_edit.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	_join(address)


func _join(address: String) -> void:
	status_label.text = "Connexion à %s..." % address
	# On charge le monde tout de suite : le serveur y fera apparaître les joueurs.
	if Net.join(address) == OK:
		_load_world()


## Partie rapide : le dernier serveur rejoint, puis les adresses de Config.QUICK_PLAY_ADDRESSES.
func _on_quick_play() -> void:
	_use_name()
	_quick_queue = Array(_extras.recent).slice(0, 1)
	for address in Config.QUICK_PLAY_ADDRESSES:
		if not address in _quick_queue:
			_quick_queue.append(address)
	_try_next_quick()


func _try_next_quick() -> void:
	if _quick_queue.is_empty():
		_back_to_menu("Partie rapide : aucun serveur trouvé.")
		return
	_join(String(_quick_queue.pop_front()))


func _on_connection_failed() -> void:
	if not _quick_queue.is_empty():
		if has_node("World"):
			$World.free()
		_try_next_quick()
		return
	_back_to_menu("Échec de connexion.")


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
