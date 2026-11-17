class_name BountyManager
extends Node
## Contrat « Prime » (serveur uniquement). Toutes les Config.BOUNTY_INTERVAL s, s'il y a
## au moins 2 joueurs vivants et pas de prime en cours, une prime est posée sur le joueur
## qui a le plus de points de quête : BOUNTY_BASE + BOUNTY_SHARE × ses points.
## Sa position devient visible par tous (balise). Le joueur qui le tue gagne la prime.
## S'il survit Config.BOUNTY_DURATION s, il touche la moitié de la prime.

const COLOR := Color(1, 0.35, 0.3)

@export var players_root: Node3D

var _target_id: int = 0
var _amount: int = 0
var _time_left: float = 0.0
var _cooldown: float = Config.BOUNTY_INTERVAL


func _ready() -> void:
	set_physics_process(multiplayer.is_server())
	if not multiplayer.is_server():
		return
	Events.player_died.connect(_on_player_died)
	Events.player_left.connect(func(peer: int) -> void: if peer == _target_id: _clear(""))


func _physics_process(delta: float) -> void:
	if _target_id != 0:
		_time_left -= delta
		if _time_left <= 0.0:
			var target := _find(_target_id)
			if target:
				target.score.add_quest_points(_amount / 2)
			_clear("%s a survécu à sa prime (+%d pts)" % [ContractSite.player_name(_target_id), _amount / 2])
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = Config.BOUNTY_INTERVAL
	var alive: Array[Player] = []
	for node in players_root.get_children():
		var p := node as Player
		if p and not p.health.is_dead:
			alive.append(p)
	if alive.size() < 2:
		return
	alive.shuffle()
	alive.sort_custom(func(a: Player, b: Player) -> bool: return a.score.quest_points > b.score.quest_points)
	var target := alive[0]
	_target_id = target.get_peer_id()
	_amount = Config.BOUNTY_BASE + int(target.score.quest_points * Config.BOUNTY_SHARE)
	_time_left = Config.BOUNTY_DURATION
	target.score.set_beacon(&"bounty", "☠ PRIME %d pts" % _amount)
	Events.announce_requested.emit("Prime de %d pts sur %s ! Sa position est visible." % [_amount, ContractSite.player_name(_target_id)], COLOR)


func _on_player_died(victim: int, killer: int) -> void:
	if victim != _target_id:
		return
	var hunter := _find(killer) if killer != victim else null
	if hunter:
		hunter.score.add_quest_points(_amount)
		_clear("%s a touché la prime sur %s (+%d pts)" % [ContractSite.player_name(killer), ContractSite.player_name(victim), _amount])
	else:
		_clear("La prime sur %s est annulée" % ContractSite.player_name(victim))


func _clear(message: String) -> void:
	var target := _find(_target_id)
	if target:
		target.score.set_beacon(&"bounty", "")
	_target_id = 0
	_amount = 0
	_cooldown = Config.BOUNTY_INTERVAL
	if message != "":
		Events.announce_requested.emit(message, COLOR)


func _find(peer_id: int) -> Player:
	return players_root.get_node_or_null(str(peer_id)) as Player if peer_id > 0 else null
