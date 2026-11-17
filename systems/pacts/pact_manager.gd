class_name PactManager
extends Node
## Pactes entre deux joueurs (étape 8e). Créé en code par World sur tous les peers.
## - Serveur : propositions, acceptation, rupture (trahison : l'autre est prévenu) ;
##   « pairs » et « proposals » sont envoyés à tous (PactSync).
## - Deux partenaires ne peuvent pas se blesser (Health.apply_damage), et la Fame des
##   contrats est partagée moitié / moitié (Score.add_contract_fame).
## - En attendant les escouades (étape 9), un partenaire compte comme coéquipier pour
##   l'état « à terre » et le Rayon vital (Config.PACT_PARTNER_IS_ALLY).
## Les pactes sont effacés à chaque nouvelle partie et quand un joueur part.

const COLOR := Color(0.55, 1.0, 0.75)

static var _current: PactManager

## Synchronisés : joueur -> partenaire (dans les deux sens), cible -> auteur de la proposition.
var pairs: Dictionary = {}
var proposals: Dictionary = {}


func _init() -> void:
	var config := SceneReplicationConfig.new()
	for key in ["pairs", "proposals"]:
		var path := NodePath(".:" + key)
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "PactSync"
	sync.replication_config = config
	add_child(sync)


func _ready() -> void:
	_current = self
	if multiplayer.is_server():
		Events.player_left.connect(func(peer: int) -> void: _server_break(peer, false))
		Events.match_reset_requested.connect(func() -> void:
			pairs = {}
			proposals = {})


func _exit_tree() -> void:
	if _current == self:
		_current = null


## Partenaire de pacte de `peer` (0 = aucun).
static func partner_of(peer: int) -> int:
	if _current == null:
		return 0
	return int(_current.pairs.get(peer, 0))


## Alliés : deux joueurs différents liés par un pacte.
static func allied(a: int, b: int) -> bool:
	return a > 0 and b > 0 and a != b and partner_of(a) == b


## Proposition reçue par `peer` (auteur, 0 = aucune).
static func proposal_for(peer: int) -> int:
	return int(_current.proposals.get(peer, 0)) if _current else 0


func _player(peer: int) -> Player:
	var players := get_parent().get_node_or_null("Players")
	return players.get_node_or_null(str(peer)) as Player if players and peer > 0 else null


func _notify(peer: int, text: String) -> void:
	var p := _player(peer)
	if p:
		p.score.notify.rpc_id(peer, text, COLOR)


# =========================================================================
# Serveur (demandes du menu Pactes, touche P)
# =========================================================================

@rpc("any_peer", "call_local", "reliable")
func request_propose(target: int) -> void:
	var from := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or from == target or _player(from) == null or _player(target) == null:
		return
	if partner_of(from) != 0 or partner_of(target) != 0:
		_notify(from, "Pacte impossible : l'un de vous a déjà un pacte")
		return
	var d := proposals.duplicate()
	d[target] = from
	proposals = d
	_notify(target, "Joueur %d vous propose un pacte (touche P)" % from)
	_notify(from, "Proposition de pacte envoyée à Joueur %d" % target)


@rpc("any_peer", "call_local", "reliable")
func request_answer(from: int, accept: bool) -> void:
	var target := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or int(proposals.get(target, 0)) != from:
		return
	var d := proposals.duplicate()
	d.erase(target)
	proposals = d
	if not accept:
		_notify(from, "Joueur %d a refusé le pacte" % target)
		return
	if partner_of(from) != 0 or partner_of(target) != 0 or _player(from) == null:
		return
	var p := pairs.duplicate()
	p[from] = target
	p[target] = from
	pairs = p
	_notify(from, "Pacte conclu avec Joueur %d : vous ne pouvez plus vous blesser, Fame des contrats partagée" % target)
	_notify(target, "Pacte conclu avec Joueur %d : vous ne pouvez plus vous blesser, Fame des contrats partagée" % from)


## Rompre son pacte (trahison) : l'autre est prévenu.
@rpc("any_peer", "call_local", "reliable")
func request_break() -> void:
	if multiplayer.is_server():
		_server_break(multiplayer.get_remote_sender_id(), true)


func _server_break(peer: int, betrayal: bool) -> void:
	var partner := partner_of(peer)
	var d := proposals.duplicate()
	d.erase(peer)
	for target: int in proposals:
		if int(proposals[target]) == peer:
			d.erase(target)
	proposals = d
	if partner == 0:
		return
	var p := pairs.duplicate()
	p.erase(peer)
	p.erase(partner)
	pairs = p
	if betrayal:
		_notify(partner, "TRAHISON : Joueur %d a rompu votre pacte !" % peer)
		_notify(peer, "Vous avez rompu le pacte avec Joueur %d" % partner)
	else:
		_notify(partner, "Votre partenaire de pacte est parti : pacte terminé")
