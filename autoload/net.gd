extends Node
## Gestion du réseau : héberger, rejoindre, serveur dédié.
## Le serveur a toujours l'id 1. Chaque client reçoit un id unique.
##
## Serveur dédié (sans fenêtre ni joueur) :
##   godot --headless -- --server
##   godot --headless -- --server --port=7777

signal hosting_started
signal connected_to_server
signal connection_failed
signal server_disconnected

var is_dedicated_server := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		is_dedicated_server = true
		var port := Config.DEFAULT_PORT
		for arg in args:
			if arg.begins_with("--port="):
				port = int(arg.trim_prefix("--port="))
		# On attend une frame pour que la scène principale soit prête.
		host.call_deferred(port)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func(): connected_to_server.emit())
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host(port: int = Config.DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, Config.MAX_PLAYERS)
	if err != OK:
		push_error("Impossible de créer le serveur sur le port %d (erreur %d)" % [port, err])
		return err
	multiplayer.multiplayer_peer = peer
	print("[Net] Serveur lancé sur le port %d%s" % [port, " (dédié)" if is_dedicated_server else ""])
	hosting_started.emit()
	return OK


func join(address: String, port: int = Config.DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("Impossible de se connecter à %s:%d (erreur %d)" % [address, port, err])
		return err
	multiplayer.multiplayer_peer = peer
	print("[Net] Connexion à %s:%d..." % [address, port])
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func is_server() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func _on_peer_connected(id: int) -> void:
	print("[Net] Joueur connecté : %d" % id)
	Events.player_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	print("[Net] Joueur déconnecté : %d" % id)
	Events.player_left.emit(id)


func _on_connection_failed() -> void:
	push_warning("[Net] Échec de connexion")
	leave()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	push_warning("[Net] Serveur perdu")
	leave()
	server_disconnected.emit()
