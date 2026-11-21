extends "res://tests/net_test_aides.gd"
## Monstre tué : l'hôte fait apparaître un Rôdeur à une position fixe
## (Events.wave_spawn_requested, objectif = le client) ; le client le tue à coups de
## Weapon.request_fire. Serveur : Events.monster_killed(rodeur, client) ; client : crédits
## du monstre reçus (Inventory.credits synchronisé).

const MONSTER_DATA := "res://data/monsters/rodeur.tres"
const MONSTER_SPOT := Vector2(14.0, 6.0)

var _killed: Array = []


func run_host() -> void:
	if not await wait_until(func() -> bool: return players_count() == 2, 30.0, "client connecté"):
		return
	var cid := client_id()
	# killer 0 = un monstre d'un camp tombé sous la carte (Monster._physics_process) : sans rapport avec le test.
	events.monster_killed.connect(func(id: StringName, killer: int) -> void:
		if killer != 0:
			_killed.append([id, killer]))
	if not await start_match():
		return
	place(1, ground(Vector2(-14.0, -6.0)))  # l'hôte à l'écart
	if not await wait_step("place"):
		return
	var before := monsters().size()
	var data := load(MONSTER_DATA) as MonsterData
	events.wave_spawn_requested.emit(player(cid), data, ground(MONSTER_SPOT, 0.0), 1.0, 1.0)
	var spawned := monsters_near(ground(MONSTER_SPOT), 3.0)
	if not check(monsters().size() == before + 1 and spawned.size() == 1, "un Rôdeur apparu en %s" % MONSTER_SPOT):
		return
	send_step("monstre", String(spawned[0].name))
	if not await wait_until(func() -> bool: return not _killed.is_empty(), 20.0, "Events.monster_killed (Rôdeur tué par le client)"):
		return
	if not check(_killed[0] == [&"rodeur", cid], "monster_killed(rodeur, client) : reçu %s" % [_killed[0]]):
		return
	check(player(cid).inventory.credits == data.credits, "crédits du Rôdeur au client (%d)" % player(cid).inventory.credits)
	await wait_step("fin_client")


func run_client() -> void:
	if not await start_match():
		return
	await move_self_and_settle(ground(SPOT_CLIENT))
	send_step("place")
	if not await wait_step("monstre"):
		return
	var path := "Monsters/" + step_value("monstre")
	if not await wait_until(func() -> bool: return world().has_node(path), 5.0, "monstre reçu (%s)" % path):
		return
	var monster := world().get_node(path) as Monster
	var credits_before := local_player().inventory.credits
	# Tirs jusqu'à la mort du monstre (il fonce vers moi), cadence de l'arme respectée.
	for i in 12:
		if not is_instance_valid(monster) or monster.health <= 0.0:
			break
		print("[Test] tir sur le monstre en %s (%.0f PV), moi en %s" % [monster.global_position, monster.health, local_player().global_position])
		fire_at(monster.global_position + Vector3.UP * monster.data.height * 0.5)
		await wait(0.4)
	if not await wait_until(func() -> bool: return not world().has_node(path), 5.0, "monstre retiré chez le client"):
		return
	var expected := credits_before + (load(MONSTER_DATA) as MonsterData).credits
	if not await wait_until(func() -> bool: return local_player().inventory.credits == expected, 5.0, "crédits du monstre reçus (%d attendus)" % expected):
		return
	send_step("fin_client")
