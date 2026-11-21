class_name DroneSite
extends ContractSite
## Contrat « Sauvetage de drones » (Drone Salvage d'origine). Un porteur au centre, data.count
## drones en panne autour. Quand un joueur approche (data.trigger_radius), une meute (data.pack)
## apparaît et attaque les drones. Maintenir E (Config.match_rules.collect_hold_time) sur un drone
## le relance : il s'envole et rapporte des points selon son état (data.condition_*).
## Celui qui relance le dernier drone déclenche le décollage (data.launch_time) : des vagues
## attaquent le porteur (data.carrier_health PV), les autres joueurs peuvent aussi tirer dessus.
## Il tient jusqu'au bout : +data.launch_fame Fame au déclencheur ; détruit : rien.
## Le site redevient utilisable après Config.match_rules.contract_reset_delay.
## Champs utilisés : count, radius, target_health, trigger_radius, pack, waves, launch_*, carrier_health,
## condition_*, monster_*_mult, color.

enum State { WAITING, ACTIVE, LAUNCH, DONE }

const PART_SCRIPT := preload("res://systems/contracts/contract_part.gd")
const DroneSiteVisual := preload("res://systems/contracts/drone_site_visual.gd")
const DroneSiteLaunch := preload("res://systems/contracts/drone_site_launch.gd")
const DroneSiteWaves := preload("res://systems/contracts/drone_site_waves.gd")

var state: int = State.WAITING        ## synchronisé
var time_left: float = 0.0            ## synchronisé : temps de décollage restant
var drone_hp: PackedFloat32Array = PackedFloat32Array()  ## synchronisé : PV des drones, puis du porteur
var sent_mask: int = 0                ## synchronisé : drones relancés
var flown_mask: int = 0               ## local : drones dont le vol est lancé (visuel)

var _parts: Array[ContractPart] = []
var _alive: Array[Monster] = []
var waves_spawned: int = 0  ## serveur : vagues du décollage déjà lancées
var last_sender_id: int = 0   ## serveur : dernier joueur à avoir relancé un drone
var launcher_id: int = 0      ## serveur : joueur qui a déclenché le décollage


func _sync_props() -> Array[String]:
	return ["state", "time_left", "drone_hp", "sent_mask"]


func _build_visual() -> void:
	_parts = DroneSiteVisual.build(self)


func _refresh() -> void:
	DroneSiteVisual.update_flights(self, _parts)
	_label.text = DroneSiteVisual.label_text(self)


# --- Accès pour les helpers -----------------------------------------------

func carrier_part() -> ContractPart:
	return _parts[data.count]


func alive_drone_parts() -> Array[ContractPart]:
	var result: Array[ContractPart] = []
	for i in data.count:
		if _drone_available(i):
			result.append(_parts[i])
	return result


func alive_monsters() -> Array[Monster]:
	var result: Array[Monster] = []
	for m in _alive:
		if is_instance_valid(m):
			result.append(m)
	return result


func forget_monsters() -> void:
	_alive.clear()


func register_wave_monster(monster: Monster) -> void:
	_alive.append(monster)


func on_wave_monster_died(monster: Monster) -> void:
	_alive.erase(monster)


# --- Déroulé (serveur) ----------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.WAITING:
		var player := DroneSiteWaves.player_near(self)
		if player:
			state = State.ACTIVE
			announce("%s approche : des monstres attaquent des drones en panne !" % player_name(player.get_peer_id()))
			DroneSiteWaves.spawn_pack(self)
	elif state == State.LAUNCH:
		DroneSiteLaunch.tick(self, delta)


func finish() -> void:
	state = State.DONE
	await get_tree().create_timer(Config.match_rules.contract_reset_delay).timeout
	if not is_inside_tree():
		return
	drone_hp = DroneSiteVisual.fresh_hp(data)
	sent_mask = 0
	state = State.WAITING


# --- Drones et porteur (ContractPart) ---------------------------------------

func _drone_available(i: int) -> bool:
	return drone_hp[i] > 0.0 and sent_mask & (1 << i) == 0


func _can_send(i: int) -> bool:
	return state == State.ACTIVE and i < data.count and _drone_available(i)


## Rang d'état du drone : 0 = intact, puis de plus en plus abîmé (data.condition_*).
func _condition(i: int) -> int:
	var ratio := drone_hp[i] / data.target_health
	var rank := 0
	while rank < data.condition_thresholds.size() and ratio <= data.condition_thresholds[rank]:
		rank += 1
	return rank


func part_prompt(i: int, _player: Player) -> String:
	if not _can_send(i):
		return ""
	var rank := _condition(i)
	return "Maintenir E : relancer le drone (%s, +%d pts d'objectif)" % [data.condition_names[rank], data.condition_points[rank]]


func part_hold_time(i: int, _player: Player) -> float:
	return Config.match_rules.collect_hold_time if _can_send(i) else 0.0


func part_interact(i: int, player: Player) -> void:
	if not _can_send(i):
		return
	player.score.add_objective_points(data.track, data.condition_points[_condition(i)])
	sent_mask |= 1 << i
	last_sender_id = player.get_peer_id()
	DroneSiteLaunch.after_drone_change(self, last_sender_id)


func part_can_be_hit(i: int) -> bool:
	if i == data.count:
		return state == State.LAUNCH and drone_hp[i] > 0.0
	return state == State.ACTIVE and _drone_available(i)


func part_receive_hit(i: int, amount: float, attacker_id: int) -> bool:
	if not part_can_be_hit(i) or (i == data.count and attacker_id == launcher_id):
		return false
	var hp := drone_hp
	hp[i] = maxf(hp[i] - amount, 0.0)
	drone_hp = hp
	if hp[i] > 0.0:
		return false
	if i == data.count:
		DroneSiteLaunch.carrier_destroyed(self)
	else:
		DroneSiteLaunch.after_drone_change(self, last_sender_id)
	return true
