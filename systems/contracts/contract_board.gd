class_name ContractBoard
extends Node
## Tableau de contrats. Au début de la partie, chaque joueur se voit proposer
## Config.match_rules.contracts_offered contrats (un objectif de data/objectives/ chacun, tirés parmi
## les objectifs de la partie, sans doublon, différents d'un joueur à l'autre) et en active au plus
## Config.match_rules.max_active_contracts. Le serveur tire et vérifie ; chaque client ne reçoit que
## SA liste (offered / active). Sans contrat actif pour un objectif, ses paliers donnent Fame, crédits
## et XP à tous mais pas de réputation de faction. Prime (Bounty) : un joueur éliminé par un tueur qui a
## le contrat « prime » actif lui rapporte Config.economy.bounty_kill_fame de Fame + la réputation.
## Créé en code par World sur tous les peers (nom stable : les RPC se résolvent par chemin).

const OBJECTIVES_DIR := "res://data/objectives/"
const PRIME_ID := "prime"

static var current: ContractBoard

## Client (et hôte) : ids d'objectifs proposés / actifs du joueur local.
var offered: PackedStringArray = PackedStringArray()
var active: PackedStringArray = PackedStringArray()

var _pool: PackedStringArray = PackedStringArray()  # serveur : objectifs de la partie
var _offers: Dictionary = {}  # serveur : pair -> PackedStringArray
var _active: Dictionary = {}  # serveur : pair -> PackedStringArray


func _ready() -> void:
	current = self
	if not multiplayer.is_server():
		return
	Events.objectives_drawn.connect(_on_objectives_drawn)
	Events.match_reset_requested.connect(_on_match_reset)
	Events.player_left.connect(_forget)
	Events.player_died.connect(_on_player_died)


func _exit_tree() -> void:
	if current == self:
		current = null


static func track_of(id: String) -> ObjectiveTrack:
	return load(OBJECTIVES_DIR + id + ".tres") as ObjectiveTrack


## Serveur : cet objectif fait-il partie des contrats actifs du joueur ?
static func is_active(peer: int, track: ObjectiveTrack) -> bool:
	if current == null or track == null:
		return false
	var list: PackedStringArray = current._active.get(peer, PackedStringArray())
	return list.has(String(track.id))


func _on_match_reset() -> void:
	_pool = PackedStringArray()
	_offers.clear()
	_active.clear()


func _forget(peer: int) -> void:
	_offers.erase(peer)
	_active.erase(peer)


## Les objectifs de la partie sont connus : chaque joueur reçoit sa propre sélection.
func _on_objectives_drawn(ids: PackedStringArray) -> void:
	_pool = ids
	_offers.clear()
	_active.clear()
	for node in get_parent().get_node("Players").get_children():
		var player := node as Player
		if player == null:
			continue
		var peer := player.get_peer_id()
		var shuffled := Array(_pool)
		shuffled.shuffle()
		_offers[peer] = PackedStringArray(shuffled.slice(0, Config.match_rules.contracts_offered))
		_active[peer] = PackedStringArray()
		_send_state(peer)


func _send_state(peer: int) -> void:
	_sync_state.rpc_id(peer, _offers.get(peer, PackedStringArray()), _active.get(peer, PackedStringArray()))


@rpc("authority", "call_local", "reliable")
func _sync_state(new_offered: PackedStringArray, new_active: PackedStringArray) -> void:
	offered = new_offered
	active = new_active
	Events.contracts_changed.emit()


## Le client demande à activer un contrat proposé (2 actifs au plus).
@rpc("any_peer", "call_local", "reliable")
func request_activate(id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var list: PackedStringArray = _active.get(peer, PackedStringArray())
	if not _offers.get(peer, PackedStringArray()).has(id) or list.has(id) \
			or list.size() >= Config.match_rules.max_active_contracts:
		return
	list.append(id)
	_active[peer] = list
	_send_state(peer)


## Le client abandonne un contrat actif : la place est libre, le contrat reste proposé.
@rpc("any_peer", "call_local", "reliable")
func request_abandon(id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var list: PackedStringArray = _active.get(peer, PackedStringArray())
	var index := list.find(id)
	if index < 0:
		return
	list.remove_at(index)
	_active[peer] = list
	_send_state(peer)


## Prime : élimination (mort, pas « à terre ») d'un joueur par un tueur qui a la Prime active.
func _on_player_died(victim_id: int, killer_id: int) -> void:
	if killer_id <= 0 or killer_id == victim_id:
		return
	var track := track_of(PRIME_ID)
	var killer := get_parent().get_node("Players").get_node_or_null(str(killer_id)) as Player
	if killer == null or not is_active(killer_id, track):
		return
	var fame := Config.economy.bounty_kill_fame
	killer.score.add_contract_fame(fame, track.faction)
	killer.score.notify.rpc_id(killer_id, "Prime : %s éliminé (+%d Fame)" % [ProfileManager.name_of(victim_id), fame], track.color)
