extends RefCounted
## Texte du HUD pour les emplacements Q / F d'un AbilityController.

## Texte du HUD : « [Q] Grenade à choc : prête   [F] Grenade ×2 ».
static func build(c: AbilityController) -> String:
	var parts: PackedStringArray = []
	var keys := ["Q", "F"]
	for slot in AbilityController.SLOTS:
		var id := c.loadout[slot]
		if id == "":
			parts.append("[%s] —" % keys[slot])
		elif AbilityController.is_gadget(id):
			var inv_slot := Inventory.WEAPON_SLOTS + slot
			var in_hand := c.player.inventory.active_slot == inv_slot
			parts.append("[%s] %s ×%d%s" % [keys[slot], Shop.entry_name(id), c.player.inventory.slot_ammo[inv_slot], " (en main)" if in_hand else ""])
		else:
			var a := c.get_slot(slot)
			var state := "prête" if c.cooldown_left[slot] <= 0.0 else "%d s" % ceili(c.cooldown_left[slot])
			var up := "" if c.upgrades[slot] == 0 else " +%d" % c.upgrades[slot]
			parts.append("[%s] %s%s : %s" % [keys[slot], a.get_display_name() if a else id, up, state])
	var text := "    ".join(parts)
	if c.pending != "":
		text += "\n>> %s acheté : appuyez sur Q ou F pour l'équiper" % Shop.entry_name(c.pending)
	return text

