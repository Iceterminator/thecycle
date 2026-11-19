extends RefCounted
## Emplacements de l'inventaire (serveur) : pose d'un objet, chargeur, paliers de boost,
## équipement de base, et demandes de changement d'arme du joueur propriétaire.
## Appelé depuis Inventory, qui garde l'état, les signaux et l'API publique.

var _inv: Inventory


func _init(inventory: Inventory) -> void:
	_inv = inventory


## Touches d'emplacement (1 / 2 / molette) -> demande de changement d'arme au serveur.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("slot_1"):
		_ask_switch(0)
	elif event.is_action_pressed("slot_2"):
		_ask_switch(1)
	elif event.is_action_pressed("next_weapon") or event.is_action_pressed("prev_weapon"):
		_ask_switch(1 - _inv.active_slot if _inv.active_slot < Inventory.WEAPON_SLOTS else 0)


func _ask_switch(slot: int) -> void:
	if slot != _inv.active_slot and _inv.slot_ids[slot] != "":
		_inv.request_switch.rpc_id(1, slot)


## Équipement de base (réapparition), voir Inventory.reset_loadout.
func reset_loadout() -> void:
	_inv.slot_boosts = PackedInt32Array([0, 0, 0, 0])
	_inv.weapon_upgrades = {}
	var base_id := _inv.player.start_weapon_id()
	var base := Items.get_item(base_id)
	_inv.slot_ammo = PackedInt32Array([_inv.player.magazine_for(base.weapon), 0, 0, 0])
	_inv.active_slot = 0
	_inv._last_active_id = ""
	_inv.slot_ids = PackedStringArray([String(base_id), "", "", ""])


func set_active_ammo(value: int) -> void:
	var a := _inv.slot_ammo
	a[_inv.active_slot] = value
	_inv.slot_ammo = a


func set_slot(slot: int, item_id: StringName, ammo: int, boost: int) -> void:
	var b := _inv.slot_boosts
	b[slot] = boost
	_inv.slot_boosts = b
	var a := _inv.slot_ammo
	a[slot] = ammo
	_inv.slot_ammo = a  # le chargeur d'abord : il est prêt quand l'arme change
	if slot == _inv.active_slot:
		_inv._last_active_id = ""  # même modèle d'arme échangé : on force le changement
	var ids := _inv.slot_ids
	ids[slot] = String(item_id)
	_inv.slot_ids = ids


## Monte d'un palier le boost de l'arme d'un emplacement.
func boost_slot(slot: int) -> void:
	var b := _inv.slot_boosts
	b[slot] += 1
	_inv.slot_boosts = b


## Après un changement de slot_ids / active_slot : annonce le changement d'arme active.
## Un emplacement actif vide n'est qu'un état transitoire (slot_ids et active_slot changent l'un
## après l'autre) : on attend la valeur suivante. La clé inclut l'emplacement : passer d'un
## fusil à un autre fusil est un vrai changement.
func after_change() -> void:
	_inv.changed.emit()
	if _inv.slot_ids.size() <= _inv.active_slot:
		return
	var key := "%d:%s" % [_inv.active_slot, _inv.slot_ids[_inv.active_slot]]
	if _inv.slot_ids[_inv.active_slot] != "" and key != _inv._last_active_id:
		_inv._last_active_id = key
		_inv.active_weapon_changed.emit()
