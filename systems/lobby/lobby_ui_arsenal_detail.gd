extends RefCounted
## Fiche détaillée de l'onglet Arsenal (à droite) : titre, visuel, chiffres, actions.
## a : le LobbyUiArsenal (untyped pour éviter un préchargement circulaire) ; lit a.sel, remplit a.detail_box.

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const Actions := preload("res://systems/lobby/lobby_ui_arsenal_actions.gd")
const ACCENT := UiStyle.ACCENT
const GOLD := UiStyle.GOLD
const RED := UiStyle.RED
const DIM := UiStyle.DIM


static func rebuild(lobby: LobbyUi, a: RefCounted) -> void:
	var box: VBoxContainer = a.detail_box
	for child in box.get_children():
		child.queue_free()
	if a.sel.is_empty():
		return
	var e: Dictionary = a.sel
	var id: String = e["id"]
	var faction: int = e["faction"]
	var color := FactionData.color_of(faction)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := W.label(e["name"], 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title)
	if e["cat"] != LobbyUi.Cat.KIT:
		head.add_child(W.label("%d ¢" % e["price"], 26, GOLD))
	var kind_text: String = LobbyUi.CAT_NAMES[e["cat"]]
	if e["weapon"]:
		kind_text = LobbyUi.TYPE_NAMES[clampi(int((e["weapon"] as WeaponData).type), 0, LobbyUi.TYPE_NAMES.size() - 1)]
	box.add_child(W.label("%s   ·   %s" % [kind_text, FactionData.name_of(faction) if faction > 0 else "Départ"], 15, color))
	var lock := lobby._lock_text(faction, e["level"])
	if lock != "":
		box.add_child(W.label(lock, 16, RED))
	var visual := ItemVisual.make(id)
	if visual:
		visual.custom_minimum_size = Vector2(0, 120 if e["weapon"] else 140)
		ItemVisual.set_colors(visual, lock != "")
		box.add_child(visual)
	match int(e["cat"]):
		LobbyUi.Cat.PRIMARY, LobbyUi.Cat.SECONDARY:
			_weapon(box, e["weapon"])
		LobbyUi.Cat.GADGET:
			var w: WeaponData = e["weapon"]
			_text(box, w.role if w.role != "" else w.behavior)
			_numbers(box, [["Charges", str(w.magazine)], ["Usage", "limité" if w.consumable else "rechargeable"]])
		LobbyUi.Cat.ABILITY:
			var ab := AbilityController.get_ability(id)
			_text(box, ab.behavior)
			var numbers: Array = [["Recharge", "%d s" % roundi(ab.cooldown_s)]]
			if ab.duration_s > 0.0:
				numbers.append(["Durée", "%d s" % roundi(ab.duration_s)])
			if ab.damage > 0.0:
				numbers.append(["Dégâts", str(roundi(ab.damage))])
			if ab.radius_m > 0.0:
				numbers.append(["Rayon", "%d m" % roundi(ab.radius_m)])
			_numbers(box, numbers)
		LobbyUi.Cat.KIT:
			var k: KitData = e["kit"]
			_text(box, k.playstyle)
			_numbers(box, [["PV", str(roundi(k.health if k.health > 0 else Config.combat.kit_default_health))],
					["Bouclier", str(roundi(k.shield if k.shield > 0 else Config.combat.kit_default_shield))],
					["Vitesse", "%.1f m/s" % (k.move_speed_mps if k.move_speed_mps > 0 else Config.combat.kit_default_speed)]])
	box.add_child(HSeparator.new())
	Actions.build(lobby, box, e, lock == "")


static func _weapon(box: VBoxContainer, w: WeaponData) -> void:
	_text(box, w.role)
	_numbers(box, [["Dégâts", str(roundi(w.damage))], ["Chargeur", str(w.magazine)]])
	var range_m := w.falloff_end_m if w.falloff_end_m > 0.0 else (w.max_range_m if w.max_range_m > 0.0 else 100.0)
	_stat(box, "Cadence de tir", clampf(w.rpm / 1000.0, 0.03, 1.0))
	_stat(box, "Vitesse de rechargement", clampf(1.0 - (w.reload_s - 1.0) / 5.0, 0.05, 1.0))
	_stat(box, "Portée", clampf(range_m / 150.0, 0.05, 1.0))
	_stat(box, "Stabilité", clampf(1.0 - w.recoil_deg / 3.0, 0.05, 1.0))


static func _text(box: VBoxContainer, text: String) -> void:
	if text == "":
		return
	var label := W.label(text, 14, Color(1, 1, 1, 0.75))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)


static func _numbers(box: VBoxContainer, numbers: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	box.add_child(row)
	for pair: Array in numbers:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -4)
		col.add_child(W.label(pair[0], 14, DIM))
		col.add_child(W.label(pair[1], 30))
		row.add_child(col)


static func _stat(box: VBoxContainer, name: String, ratio: float) -> void:
	box.add_child(W.label(name, 14, DIM))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 6)
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = ratio
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	box.add_child(bar)
