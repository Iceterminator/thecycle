extends RefCounted
## Mises à jour du HUD : annonces, kit et capacités, inventaire, barres PV, munitions, hitmarker.

const HudWidgets := preload("res://systems/combat/hud_widgets.gd")


static func on_announcement(hud: CombatHud, text: String, color: Color) -> void:
	hud._banner.text = text
	hud._banner.modulate = color
	if hud._banner_tween:
		hud._banner_tween.kill()
	hud._banner_tween = hud.create_tween()
	hud._banner_tween.tween_interval(4.0)
	hud._banner_tween.tween_property(hud._banner, "modulate:a", 0.0, 0.8)



static func update_bottom(hud: CombatHud) -> void:
	var kit := hud._player.kit
	if kit:
		var next := kit.xp_for_next_level()
		hud._kit_label.text = "%s — niv. %d" % [kit.get_display_name(), kit.level]
		hud._xp_bar.max_value = maxf(next, 1.0) if next > 0 else 1.0
		hud._xp_bar.value = kit.xp if next > 0 else 1.0
	hud._move_label.text = hud._player.movement.status_text() if hud._player.movement else ""
	hud._effects_label.text = ("Effets : " + hud._player.buffs.status_text()) if hud._player.buffs and hud._player.buffs.status_text() != "" else ""
	var abilities := hud._player.abilities
	if abilities == null:
		return
	hud._pending_label.text = ">> %s acheté : appuyez sur Q ou F pour l'équiper" % Shop.entry_name(abilities.pending) if abilities.pending != "" else ""
	for slot in hud._ability_boxes.size():
		var box: Dictionary = hud._ability_boxes[slot]
		var id := abilities.loadout[slot]
		var name_label: Label = box["name"]
		var info: Label = box["info"]
		var cooldown: ColorRect = box["cooldown"]
		cooldown.visible = false
		if box["id"] != id:
			box["id"] = id
			var slot_node: Control = box["slot"]
			for child in slot_node.get_children():
				child.queue_free()
			var visual := ItemVisual.make(id)
			if visual:
				slot_node.add_child(visual)
				visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if id == "":
			name_label.text = "—"
			info.text = ""
		elif AbilityController.is_gadget(id):
			var inv_slot := Inventory.WEAPON_SLOTS + slot
			name_label.text = Shop.entry_name(id)
			info.text = "×%d" % hud._player.inventory.slot_ammo[inv_slot]
			(box["panel"] as Panel).modulate = Color(1, 1, 1) if hud._player.inventory.active_slot != inv_slot else Color(1.2, 1.2, 0.9)
		else:
			var a := abilities.get_slot(slot)
			name_label.text = a.get_display_name() if a else id
			var left: float = abilities.cooldown_left[slot]
			if left > 0.0 and a:
				var total := maxf(a.get_cooldown(abilities.upgrades[slot], hud._player.kit.get_effect("ability_cooldown_mult")), 0.1)
				cooldown.visible = true
				cooldown.anchor_top = 1.0 - clampf(left / total, 0.0, 1.0)
				info.text = "%d s" % ceili(left)
			else:
				info.text = "+%d" % abilities.upgrades[slot] if abilities.upgrades[slot] > 0 else ""



static func on_inventory_changed(hud: CombatHud) -> void:
	var inv := hud._player.inventory
	for i in hud._slot_rows.size():
		var item := Items.get_item(StringName(inv.slot_ids[i]))
		var row: Dictionary = hud._slot_rows[i]
		var icon: WeaponIcon = row["icon"]
		icon.weapon = item.weapon if item else null
		var active := i == inv.active_slot
		icon.tint = Color(0.93, 0.95, 0.97) if active else Color(0.8, 0.82, 0.85, 0.45)
		icon.accent = Color(FactionData.color_of(int(item.weapon.faction)), 1.0 if active else 0.5) if item and item.weapon and int(item.weapon.faction) > 0 else Color(0, 0, 0, 0)
		(row["key"] as Label).add_theme_color_override("font_color", CombatHud.GOLD if active else CombatHud.DIM)
		(row["row"] as Control).visible = item != null
	var active_item := Items.get_item(inv.get_active_id())
	hud._weapon_name.text = active_item.display_name if active_item else ""
	var text := ""
	for res_id: String in inv.carried:
		var res := Items.get_item(StringName(res_id))
		text += "\n%s ×%d" % [res.display_name if res else res_id, inv.carried[res_id]]
	hud._items_label.text = text.strip_edges()
	hud._credits_label.text = "¢ %d   [T] boutique" % inv.credits



static func on_health_changed(hud: CombatHud) -> void:
	var h := hud._player.health
	hud._shield_bar.max_value = maxf(h.max_shield, 1.0)
	hud._shield_bar.value = h.shield
	hud._health_bar.max_value = maxf(h.get_max_health(), 1.0)
	hud._health_bar.value = h.health
	hud._bars_label.text = "%d  |  %d" % [ceili(h.shield), ceili(h.health)]
	var total := h.health + h.shield
	if hud._last_total >= 0.0 and total < hud._last_total - 0.01:
		flash_damage(hud)
	hud._last_total = total



static func on_ammo_changed(hud: CombatHud, ammo: int, magazine_size: int, reloading: bool) -> void:
	hud._ammo_label.text = "RECHARGEMENT" if reloading else "%d / %d" % [ammo, magazine_size]



static func on_hit_confirmed(hud: CombatHud, headshot: bool, killed: bool) -> void:
	hud._hitmarker.text = "✖" if killed else "×"
	hud._hitmarker.add_theme_font_size_override("font_size", 44 if killed else 32)
	hud._hitmarker.modulate = Color(1, 0.2, 0.15) if (headshot or killed) else Color.WHITE
	if hud._hit_tween:
		hud._hit_tween.kill()
	hud._hit_tween = hud.create_tween()
	hud._hit_tween.tween_property(hud._hitmarker, "modulate:a", 0.0, 0.3 if killed else 0.15)



static func flash_damage(hud: CombatHud) -> void:
	hud._damage_flash.color.a = 0.25
	Events.camera_shake_requested.emit(hud._player.camera.global_position, 0.35, 1.0)
	if hud._flash_tween:
		hud._flash_tween.kill()
	hud._flash_tween = hud.create_tween()
	hud._flash_tween.tween_property(hud._damage_flash, "color:a", 0.0, 0.35)
