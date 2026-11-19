extends RefCounted
## Gadgets de l'inventaire (emplacements 2 = Q et 3 = F) : pose, retrait, recharge.
## Serveur uniquement. Appelé depuis Inventory, qui garde l'API publique.

var _inv: Inventory


func _init(inventory: Inventory) -> void:
	_inv = inventory


## Retire l'arme en main (gadget épuisé). Un gadget de Q / F libère aussi son emplacement
## de capacité ; on reprend une arme.
func remove_active() -> void:
	var slot := _inv.active_slot
	if slot >= Inventory.WEAPON_SLOTS:
		_inv.player.abilities.server_clear_slot(slot - Inventory.WEAPON_SLOTS)
		return
	var other := 1 - slot
	if _inv.slot_ids[other] != "":
		_inv.active_slot = other
	_inv.server_set_slot(slot, &"", 0)
	if _inv.slot_ids[_inv.active_slot] == "":
		_inv.reset_loadout()


## Met un gadget dans l'emplacement de Q (0) ou F (1), chargeur plein.
func set_gadget(key_slot: int, item_id: StringName) -> void:
	var slot := Inventory.WEAPON_SLOTS + key_slot
	var item := Items.get_item(item_id)
	if item == null or item.weapon == null:
		return
	_inv.server_set_slot(slot, item_id, _inv.player.magazine_for(item.weapon))


## Vide l'emplacement de gadget de Q (0) ou F (1) ; s'il était en main, on reprend l'arme 1.
func clear_gadget(key_slot: int) -> void:
	var slot := Inventory.WEAPON_SLOTS + key_slot
	if _inv.slot_ids[slot] == "":
		return
	if _inv.active_slot == slot:
		_inv.active_slot = 0 if _inv.slot_ids[0] != "" else 1
	_inv.server_set_slot(slot, &"", 0)


## Recharge le gadget de Q (0) ou F (1) (rachat en boutique).
func refill_gadget(key_slot: int) -> void:
	var slot := Inventory.WEAPON_SLOTS + key_slot
	var item := Items.get_item(StringName(_inv.slot_ids[slot]))
	if item and item.weapon:
		var a := _inv.slot_ammo
		a[slot] = _inv.player.magazine_for(item.weapon)
		_inv.slot_ammo = a
