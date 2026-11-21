class_name AlphaBoss
extends Node
## Serveur : le boss Alpha (Warden Alpha d'origine). Il apparaît à `alpha_time` s de partie sur un emplacement
## de quête libre (annonce à tous ; visible de tous sur la carte : MapViewEvenements).
## Fame, comme l'original : chaque joueur gagne `alpha_step_fame` à chaque tranche de 1 / `alpha_steps` des PV max
## de l'Alpha qu'IL a infligés (alpha_steps tranches au plus), et celui qui l'achève gagne `alpha_kill_fame` de plus.
## La Fame passe directement par Score.add_contract_fame ; la réputation de faction n'est donnée que si le contrat
## « alpha » (data/objectives/alpha.tres) est actif chez le joueur. Créé par le QuestManager.

const DATA_PATH := "res://data/monsters/alpha.tres"
const TRACK_ID := "alpha"
const ANNOUNCE_COLOR := Color(1.0, 0.5, 0.2)

var world: World
var monsters: MonsterManager
var spots_root: Node3D
var quest_root: Node
var players_root: Node3D

var _last_elapsed: float = 0.0
var _damage: Dictionary = {}  # peer_id -> PV infligés à l'Alpha
var _paid: Dictionary = {}  # peer_id -> tranches déjà payées


func _ready() -> void:
	Events.monster_damaged.connect(_on_monster_damaged)
	Events.monster_killed.connect(_on_monster_killed)
	Events.match_reset_requested.connect(_reset)
	Events.carte_liberee.connect(_reset)


func _reset() -> void:
	_last_elapsed = 0.0
	_damage.clear()
	_paid.clear()


func _physics_process(_delta: float) -> void:
	if world == null or world.match_manager == null:
		return
	var elapsed := world.match_manager.elapsed
	var time := Config.match_rules.alpha_time
	if _last_elapsed < time and elapsed >= time and elapsed < Config.match_rules.match_duration and is_instance_valid(spots_root):
		_spawn()
	_last_elapsed = elapsed


func _spawn() -> void:
	var spots := QuestFreeSpots.pick(spots_root, quest_root, players_root, 1, Config.match_rules.surge_min_player_distance)
	if spots.is_empty():
		return
	monsters.server_spawn_boss(DATA_PATH, spots[0])
	Events.announce_requested.emit("Un Alpha est apparu ! Infligez-lui des dégâts pour gagner de la Fame", ANNOUNCE_COLOR)


func _on_monster_damaged(monster: Node, amount: float, attacker_id: int) -> void:
	var boss := monster as Monster
	if boss == null or boss.data.id != &"alpha" or attacker_id <= 0:
		return
	_damage[attacker_id] = _damage.get(attacker_id, 0.0) + amount
	var rules := Config.match_rules
	var steps := mini(int(_damage[attacker_id] / (boss.max_health / rules.alpha_steps)), rules.alpha_steps)
	var due: int = steps - _paid.get(attacker_id, 0)
	if due > 0:
		_paid[attacker_id] = steps
		_give(attacker_id, due * rules.alpha_step_fame, "%d %% des PV de l'Alpha infligés" % (steps * 100 / rules.alpha_steps))


func _on_monster_killed(monster_id: StringName, killer_id: int) -> void:
	if monster_id == &"alpha" and killer_id > 0:
		_give(killer_id, Config.match_rules.alpha_kill_fame, "Alpha achevé")


func _give(peer: int, amount: int, reason: String) -> void:
	var player := players_root.get_node_or_null(str(peer)) as Player
	if player == null:
		return
	var track := ContractBoard.track_of(TRACK_ID)
	player.score.add_contract_fame(amount, track.faction, true, ContractBoard.is_active(peer, track))
	player.score.notify.rpc_id(peer, "%s (+%d Fame)" % [reason, amount], track.color)
