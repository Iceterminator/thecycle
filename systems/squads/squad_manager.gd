class_name SquadManager
extends Node
## Escouades (étape 9), jusqu'à Config.SQUAD_MAX joueurs. Créé en code par World sur tous
## les peers. Formées dans le lobby (créer / rejoindre / quitter) ; elles restent d'une
## partie à l'autre. « members » (joueur -> numéro d'escouade) est envoyé à tous.
## Coéquipiers : pas de dégâts entre eux, visibles sur la carte, largués ensemble, ils se
## relèvent à terre (voir Allies).

static var _current: SquadManager

var members: Dictionary = {}
var _next_squad: int = 1


func _init() -> void:
	var config := SceneReplicationConfig.new()
	var path := NodePath(".:members")
	config.add_property(path)
	config.property_set_spawn(path, true)
	config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "SquadSync"
	sync.replication_config = config
	add_child(sync)


func _ready() -> void:
	_current = self
	if multiplayer.is_server():
		Events.player_left.connect(_leave)


func _exit_tree() -> void:
	if _current == self:
		_current = null


static func squad_of(peer: int) -> int:
	return int(_current.members.get(peer, 0)) if _current else 0


static func same_squad(a: int, b: int) -> bool:
	var s := squad_of(a)
	return s != 0 and a != b and s == squad_of(b)


## Membres d'une escouade (ids des joueurs).
static func members_of(squad: int) -> Array[int]:
	var result: Array[int] = []
	if _current == null or squad == 0:
		return result
	for peer: int in _current.members:
		if int(_current.members[peer]) == squad:
			result.append(peer)
	result.sort()
	return result


## Escouades existantes : numéro -> membres.
static func all_squads() -> Dictionary:
	var result := {}
	if _current:
		for peer: int in _current.members:
			var s := int(_current.members[peer])
			if not result.has(s):
				result[s] = members_of(s)
	return result


# =========================================================================
# Serveur (demandes du lobby)
# =========================================================================

func _allowed() -> bool:
	return multiplayer.is_server() and MatchManager.is_lobby()


@rpc("any_peer", "call_local", "reliable")
func request_create() -> void:
	if not _allowed():
		return
	var peer := multiplayer.get_remote_sender_id()
	var d := members.duplicate()
	d[peer] = _next_squad
	_next_squad += 1
	members = d


@rpc("any_peer", "call_local", "reliable")
func request_join(squad: int) -> void:
	if not _allowed() or members_of(squad).is_empty() or members_of(squad).size() >= Config.SQUAD_MAX:
		return
	var d := members.duplicate()
	d[multiplayer.get_remote_sender_id()] = squad
	members = d


@rpc("any_peer", "call_local", "reliable")
func request_leave() -> void:
	if _allowed():
		_leave(multiplayer.get_remote_sender_id())


func _leave(peer: int) -> void:
	if not members.has(peer):
		return
	var d := members.duplicate()
	d.erase(peer)
	members = d
