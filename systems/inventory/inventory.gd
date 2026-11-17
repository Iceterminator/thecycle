class_name Inventory
extends Node
## Inventaire d'un joueur : 2 emplacements d'arme, consommables, crédits.
## SEUL LE SERVEUR le modifie ; InventorySync (autorité 1, voir player.gd::_enter_tree)
## l'envoie à tous les clients. Le client propriétaire lit les touches
## (1 / 2 / molette, 3 = soin, 4 = recharge de bouclier) et envoie des demandes.
## Valeurs et règles provisoires : à revoir avec la boucle de partie complète.

signal changed
signal active_weapon_changed

## Ids d'objet des 2 emplacements ("" = vide). Toujours réassigner le tableau entier
## (via _set_slot) pour que le setter et la synchro voient le changement.
var slot_ids: PackedStringArray = PackedStringArray([String(Config.BASE_WEAPON), ""]):
	set(value):
		slot_ids = value
		_after_change()
## Chargeur de chaque emplacement (c'est le compteur du serveur qui fait foi).
var slot_ammo: PackedInt32Array = PackedInt32Array([0, 0]):
	set(value):
		slot_ammo = value
		changed.emit()
var active_slot: int = 0:
	set(value):
		active_slot = value
		_after_change()
var medkits: int = 0:
	set(value):
		medkits = value
		changed.emit()
var shield_cells: int = 0:
	set(value):
		shield_cells = value
		changed.emit()
var credits: int = 0:
	set(value):
		credits = value
		changed.emit()
## Ressources de contrat portées (id -> quantité), ex. biomasse, Lumicèpes.
## Toujours réassigner le dictionnaire entier pour la synchro.
var carried: Dictionary = {}:
	set(value):
		carried = value
		changed.emit()
## Consommable en cours d'utilisation ("" = aucun).
var using_item: String = "":
	set(value):
		using_item = value
		use_started_ms = Time.get_ticks_msec()
		changed.emit()

## Heure locale du début de l'utilisation (pour la barre de progression du HUD).
var use_started_ms: int = 0

@onready var player: Player = get_parent()
@onready var health: Health = $"../Health"

var _last_active_id: String = ""
var _use_end_ms: int = 0


func _ready() -> void:
	_last_active_id = "%d:%s" % [active_slot, slot_ids[active_slot]]
	if multiplayer.is_server():
		reset_loadout()
		health.dead_changed.connect(_on_dead_changed_server)
	set_physics_process(multiplayer.is_server())
	set_process_unhandled_input(player.is_multiplayer_authority())


func get_active_id() -> StringName:
	return StringName(slot_ids[active_slot])


func get_active_weapon() -> WeaponData:
	var item := Items.get_item(get_active_id())
	return item.weapon if item else null


func get_active_ammo() -> int:
	return slot_ammo[active_slot]


func get_use_duration() -> float:
	var item := Items.get_item(StringName(using_item))
	return item.use_time if item else 0.0


func _after_change() -> void:
	changed.emit()
	if slot_ids.size() <= active_slot:
		return
	# Un emplacement actif vide n'est qu'un état transitoire (slot_ids et active_slot
	# changent l'un après l'autre) : on attend la valeur suivante.
	# La clé inclut l'emplacement : passer d'un fusil à un autre fusil est un vrai changement.
	var key := "%d:%s" % [active_slot, slot_ids[active_slot]]
	if slot_ids[active_slot] != "" and key != _last_active_id:
		_last_active_id = key
		active_weapon_changed.emit()


# =========================================================================
# Client propriétaire : touches -> demandes au serveur
# =========================================================================

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or health.is_dead:
		return
	if event.is_action_pressed("slot_1"):
		_ask_switch(0)
	elif event.is_action_pressed("slot_2"):
		_ask_switch(1)
	elif event.is_action_pressed("next_weapon") or event.is_action_pressed("prev_weapon"):
		_ask_switch(1 - active_slot)
	elif event.is_action_pressed("use_heal"):
		request_use.rpc_id(1, String(Config.HEAL_ITEM))
	elif event.is_action_pressed("use_shield"):
		request_use.rpc_id(1, String(Config.SHIELD_ITEM))


func _ask_switch(slot: int) -> void:
	if slot != active_slot and slot_ids[slot] != "":
		request_switch.rpc_id(1, slot)


# =========================================================================
# Serveur
# =========================================================================

@rpc("any_peer", "call_local", "reliable")
func request_switch(slot: int) -> void:
	if not multiplayer.is_server() or not _sender_is_owner() or health.is_dead:
		return
	if slot < 0 or slot >= slot_ids.size() or slot == active_slot or slot_ids[slot] == "":
		return
	cancel_use()
	active_slot = slot


@rpc("any_peer", "call_local", "reliable")
func request_use(item_id: String) -> void:
	if not multiplayer.is_server() or not _sender_is_owner() or health.is_dead:
		return
	if using_item != "":
		return
	var item := Items.get_item(StringName(item_id))
	if item == null:
		return
	match item.kind:
		ItemData.Kind.HEAL:
			if medkits <= 0 or health.health >= health.get_max_health():
				return
		ItemData.Kind.SHIELD_RECHARGE:
			if shield_cells <= 0 or health.shield >= health.max_shield:
				return
		_:
			return
	_use_end_ms = Time.get_ticks_msec() + int(item.use_time * 1000.0)
	using_item = item_id


func _physics_process(_delta: float) -> void:
	if using_item == "" or Time.get_ticks_msec() < _use_end_ms:
		return
	var item := Items.get_item(StringName(using_item))
	using_item = ""
	if item == null or health.is_dead:
		return
	if item.kind == ItemData.Kind.HEAL and medkits > 0:
		medkits -= 1
		health.heal(item.effect)
	elif item.kind == ItemData.Kind.SHIELD_RECHARGE and shield_cells > 0:
		shield_cells -= 1
		health.restore_shield(item.effect)


## Serveur : interrompt le consommable en cours (tir, changement d'arme, mort).
func cancel_use() -> void:
	if using_item != "":
		using_item = ""


## Serveur : équipement de base (réapparition). Les crédits sont conservés.
func reset_loadout() -> void:
	var base := Items.get_item(Config.BASE_WEAPON)
	slot_ammo = PackedInt32Array([base.weapon.magazine, 0])
	active_slot = 0
	slot_ids = PackedStringArray([String(Config.BASE_WEAPON), ""])
	medkits = 0
	shield_cells = 0
	cancel_use()


## Serveur : met à jour le chargeur de l'arme en main.
func set_active_ammo(value: int) -> void:
	var a := slot_ammo
	a[active_slot] = value
	slot_ammo = a


## Serveur : essaie de prendre un objet ramassé. Renvoie false si impossible (plein).
func server_take(item: ItemData, amount: int, ammo: int) -> bool:
	match item.kind:
		ItemData.Kind.WEAPON:
			var mag := ammo if ammo >= 0 else item.weapon.magazine
			var free := slot_ids.find("")
			if free >= 0:
				_set_slot(free, item.id, mag)
			else:
				# Emplacements pleins : l'arme en main est lâchée et remplacée.
				Events.loot_drop_requested.emit(get_active_id(), 1, get_active_ammo(), _drop_position(), false)
				_set_slot(active_slot, item.id, mag)
		ItemData.Kind.HEAL:
			if medkits >= Config.MAX_MEDKITS:
				return false
			medkits += 1
		ItemData.Kind.SHIELD_RECHARGE:
			if shield_cells >= Config.MAX_SHIELD_CELLS:
				return false
			shield_cells += 1
		ItemData.Kind.CREDITS:
			add_credits(amount)
		ItemData.Kind.SHIELD_UPGRADE:
			return false  # ancien système : le bouclier vient du kit (étape 8b)
		ItemData.Kind.RESOURCE:
			var have := get_resource(item.id)
			var room := (item.max_carry - have) if item.max_carry > 0 else amount
			if room <= 0:
				return false
			var c := carried.duplicate()
			c[String(item.id)] = have + mini(amount, room)
			carried = c
	return true


func get_resource(item_id: StringName) -> int:
	return carried.get(String(item_id), 0)


## Serveur : retire toute une ressource portée (dépôt à un collecteur). Renvoie la quantité.
func take_resource(item_id: StringName) -> int:
	var n := get_resource(item_id)
	if n > 0:
		var c := carried.duplicate()
		c.erase(String(item_id))
		carried = c
	return n


## Serveur : dépense des crédits (achat). Renvoie false si pas assez.
func spend_credits(amount: int) -> bool:
	if amount < 0 or credits < amount:
		return false
	credits -= amount
	Events.credits_changed.emit(player.get_peer_id(), credits)
	return true


func add_credits(amount: int) -> void:
	credits += amount
	Events.credits_changed.emit(player.get_peer_id(), credits)


func _set_slot(slot: int, item_id: StringName, ammo: int) -> void:
	var a := slot_ammo
	a[slot] = ammo
	slot_ammo = a  # le chargeur d'abord : il est prêt quand l'arme change
	if slot == active_slot:
		_last_active_id = ""  # même modèle d'arme échangé : on force le changement
	var ids := slot_ids
	ids[slot] = String(item_id)
	slot_ids = ids


## Serveur : à la mort, on lâche tout ce qui dépasse l'équipement de base,
## et la moitié des crédits va au tueur (au sol s'il n'y a pas de tueur joueur).
func _on_dead_changed_server(dead: bool) -> void:
	if not dead:
		return
	cancel_use()
	var pos := player.global_position + Vector3(0, 0.5, 0)
	for i in slot_ids.size():
		if slot_ids[i] != "" and StringName(slot_ids[i]) != Config.BASE_WEAPON:
			Events.loot_drop_requested.emit(StringName(slot_ids[i]), 1, slot_ammo[i], pos, true)
	for i in medkits:
		Events.loot_drop_requested.emit(Config.HEAL_ITEM, 1, -1, pos, true)
	for i in shield_cells:
		Events.loot_drop_requested.emit(Config.SHIELD_ITEM, 1, -1, pos, true)
	for res_id: String in carried:
		Events.loot_drop_requested.emit(StringName(res_id), carried[res_id], -1, pos, true)
	carried = {}

	var lost := int(credits * Config.DEATH_CREDITS_LOSS)
	if lost > 0:
		credits -= lost
		Events.credits_changed.emit(player.get_peer_id(), credits)
		var killer := player.get_parent().get_node_or_null(str(health.killer_id)) as Player
		if killer and killer != player:
			killer.inventory.add_credits(lost)
		else:
			Events.loot_drop_requested.emit(&"credits", lost, -1, pos, true)
	reset_loadout()


func _drop_position() -> Vector3:
	return player.global_position - player.global_basis.z * 1.0 + Vector3(0, 0.5, 0)


func _sender_is_owner() -> bool:
	return multiplayer.get_remote_sender_id() == player.get_peer_id()


## Serveur : nouvelle partie. Équipement de base, plus de crédits ni de ressources.
func server_reset() -> void:
	reset_loadout()
	carried = {}
	credits = 0
	Events.credits_changed.emit(player.get_peer_id(), credits)
