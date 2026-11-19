extends Node
## Base des tests réseau automatisés (lancés par tools/run_tests.sh).
## Le même script de test tourne deux fois :
##   hôte   : godot --headless --path . -s tests/runner.gd -- --test=test_x --host --name=ZzTestHote
##   client : godot --headless --path . -s tests/runner.gd -- --test=test_x --join=127.0.0.1 --name=ZzTestClient
## Chaque côté vérifie sa part (l'hôte = le serveur, vérité du jeu ; le client = ce qu'il reçoit),
## puis quitte avec 0 (affiche « TEST OK ») ou 1 (« TEST ECHEC : raison »).
## Les sous-classes écrivent run_host() et run_client() (coroutines).
## Accélération : les durées de largage, de réapparition et de fin sont raccourcies ici,
## en mémoire seulement (les .tres ne sont pas modifiés, le jeu normal ne change pas).

const MAIN_SCENE := "res://scenes/main/main.tscn"
const TEST_TIMEOUT := 120.0
const PROFILE_PREFIX := "zztest"

var is_host: bool = false
var events: Node
var config: Node
var net: Node
var _done: bool = false


func _ready() -> void:
	is_host = "--host" in OS.get_cmdline_user_args()
	_start.call_deferred()


func _start() -> void:
	events = get_tree().root.get_node("Events")
	config = get_tree().root.get_node("Config")
	net = get_tree().root.get_node("Net")
	if is_host:
		_clean_profiles()
	_speed_up()
	var main := (load(MAIN_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	get_tree().create_timer(TEST_TIMEOUT).timeout.connect(func() -> void: fail("délai global dépassé"))
	if is_host:
		await run_host()
	else:
		await run_client()
	succeed()


## À surcharger : partie serveur du test.
func run_host() -> void:
	pass


## À surcharger : partie client du test.
func run_client() -> void:
	pass


## Raccourcis de test (mémoire seulement).
func _speed_up() -> void:
	var rules: MatchRules = config.match_rules
	rules.drop_screen_time = 2.0
	rules.drop_pod_fall_time = 1.0
	rules.drop_pod_open_delay = 0.5
	rules.respawn_delay = 1.0
	rules.match_restart_delay = 3.0


# =========================================================================
# Fin du test
# =========================================================================

func succeed() -> void:
	if _done:
		return
	_done = true
	print("TEST OK (%s)" % _role())
	_finish(0)


func fail(reason: String) -> void:
	if _done:
		return
	_done = true
	print("TEST ECHEC (%s) : %s" % [_role(), reason])
	_finish(1)


func _finish(code: int) -> void:
	if is_host:
		# On laisse le temps au client de finir avant de couper le serveur.
		await get_tree().create_timer(2.0).timeout
		_clean_profiles()
	get_tree().quit(code)


func _role() -> String:
	return "hôte" if is_host else "client"


## Profils de test (user://profiles/zztest*.json) : effacés au début et à la fin.
func _clean_profiles() -> void:
	var dir := "user://profiles/"
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file in DirAccess.get_files_at(dir):
		if file.to_lower().begins_with(PROFILE_PREFIX):
			DirAccess.remove_absolute(dir + file)


# =========================================================================
# Aides
# =========================================================================

## Vérifie une condition ; en cas d'échec, le test s'arrête. Renvoie la condition.
func check(condition: bool, reason: String) -> bool:
	if not condition:
		fail(reason)
	return condition


## Attend que `condition` soit vraie (au plus `timeout` s). Échec du test sinon.
func wait_until(condition: Callable, timeout: float, what: String) -> bool:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not condition.call():
		if _done:
			return false
		if Time.get_ticks_msec() > end:
			fail("attente trop longue : " + what)
			return false
		await get_tree().process_frame
	return true


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func world() -> World:
	return get_tree().root.get_node_or_null("Main/World") as World


func match_manager() -> MatchManager:
	var w := world()
	return w.match_manager if w else null


func my_id() -> int:
	return multiplayer.get_unique_id()


func player(peer: int) -> Player:
	var w := world()
	return w.get_player(peer) if w else null


func local_player() -> Player:
	return player(my_id())


## Hôte : id du client (premier joueur qui n'est pas l'hôte).
func client_id() -> int:
	var w := world()
	if w == null:
		return 0
	for node in w.players.get_children():
		if (node as Player).get_peer_id() != 1:
			return (node as Player).get_peer_id()
	return 0


func players_count() -> int:
	var w := world()
	return w.players.get_child_count() if w else 0


func phase() -> int:
	var mm := match_manager()
	return mm.phase if mm else -1


## Les deux côtés : attend 2 joueurs, chacun se déclare prêt, attend la fin du largage.
## Après ça : phase PLAYING, capsules ouvertes, joueurs vulnérables.
func start_match() -> bool:
	if not await wait_until(func() -> bool: return players_count() == 2 and local_player() != null, 30.0, "2 joueurs dans le monde"):
		return false
	# Le profil doit être chargé avant le départ (sinon l'équipement arrive pendant la partie).
	await wait(1.0)
	match_manager().request_lobby_ready.rpc_id(1, true)
	if not await wait_until(func() -> bool: return phase() == MatchManager.Phase.PLAYING, 30.0, "début de partie"):
		return false
	# L'horloge (PLAYING) peut arriver avant le début de la capsule : on attend aussi que le
	# temps de chute + ouverture soit écoulé, sinon la capsule replace le joueur ensuite.
	var rules: MatchRules = config.match_rules
	var drop_time := rules.drop_pod_fall_time + rules.drop_pod_open_delay
	return await wait_until(func() -> bool: return match_manager().elapsed >= drop_time and not local_player().is_dropping(), 15.0, "fin du largage")


## Hôte : place un joueur à une position (le client décide de son déplacement : on passe
## par le RPC teleport, comme le jeu).
func place(peer: int, pos: Vector3) -> void:
	var p := player(peer)
	if p:
		p.teleport.rpc(pos)
