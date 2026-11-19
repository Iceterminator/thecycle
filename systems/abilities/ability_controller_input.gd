extends RefCounted
## Entrées Q / F du client propriétaire (AbilityController._process) : assigner l'achat en
## attente, prendre / rendre un gadget, ou demander l'usage d'une capacité.

var c: AbilityController
var player: Player
## Dernière arme en main avant de prendre un gadget (pour la rendre).
var _weapon_before_gadget: int = 0


func _init(controller: AbilityController) -> void:
	c = controller
	player = controller.player


func update() -> void:
	if player.health.is_dead or player.health.is_downed or player.is_evacuated or player.is_dropping() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	for slot in AbilityController.SLOTS:
		if not Input.is_action_just_pressed("ability_%d" % (slot + 1)):
			continue
		if c.pending != "":
			c.request_assign.rpc_id(1, slot)
		elif AbilityController.is_gadget(c.loadout[slot]):
			# Gadget : la touche le prend en main, ou rend l'arme d'avant.
			var inv := player.inventory
			var gadget_slot := Inventory.WEAPON_SLOTS + slot
			if inv.active_slot == gadget_slot:
				inv.request_switch.rpc_id(1, _weapon_before_gadget if inv.slot_ids[_weapon_before_gadget] != "" else 0)
			else:
				if inv.active_slot < Inventory.WEAPON_SLOTS:
					_weapon_before_gadget = inv.active_slot
				inv.request_switch.rpc_id(1, gadget_slot)
		elif c.loadout[slot] != "" and c.cooldown_left[slot] <= 0.0:
			c.request_use.rpc_id(1, slot, player.camera.global_position, -player.camera.global_basis.z)
