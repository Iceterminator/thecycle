extends RefCounted
## Textes et statistiques d'un objet du catalogue, pour la page Équipement (fonctions statiques).

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const DIM := UiStyle.DIM


static func type_line(e: Dictionary) -> String:
	var faction := int(e.get("faction", 0))
	var where := FactionData.name_of(faction) if faction > 0 else "Départ"
	match int(e.get("cat", -1)):
		LobbyUi.Cat.PRIMARY, LobbyUi.Cat.SECONDARY:
			var w: WeaponData = e["weapon"]
			var slot := "Arme secondaire" if e["cat"] == LobbyUi.Cat.SECONDARY else "Arme principale"
			return "%s | %s · %s" % [slot, LobbyUi.TYPE_NAMES[clampi(int(w.type), 0, LobbyUi.TYPE_NAMES.size() - 1)], where]
		LobbyUi.Cat.GADGET:
			return "Gadget · " + where
		LobbyUi.Cat.ABILITY:
			return "Capacité · " + where
		LobbyUi.Cat.KIT:
			return "Combinaison · " + where
	return where


static func description(e: Dictionary) -> String:
	match int(e.get("cat", -1)):
		LobbyUi.Cat.PRIMARY, LobbyUi.Cat.SECONDARY, LobbyUi.Cat.GADGET:
			var w: WeaponData = e["weapon"]
			return w.role if w.role != "" else w.behavior
		LobbyUi.Cat.ABILITY:
			return AbilityController.get_ability(e["id"]).behavior
		LobbyUi.Cat.KIT:
			return (e["kit"] as KitData).playstyle
	return ""


## Grands chiffres à gauche, barres à droite (armes) ; chiffres seuls sinon.
static func stats(lobby: LobbyUi, e: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	var numbers := VBoxContainer.new()
	numbers.add_theme_constant_override("separation", 2)
	row.add_child(numbers)
	match int(e.get("cat", -1)):
		LobbyUi.Cat.PRIMARY, LobbyUi.Cat.SECONDARY:
			var w: WeaponData = e["weapon"]
			_number(numbers, "Dégâts", str(roundi(w.damage)))
			_number(numbers, "Taille du chargeur", str(lobby._player.magazine_for(w)))
			var bars := VBoxContainer.new()
			bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bars.add_theme_constant_override("separation", 4)
			row.add_child(bars)
			var range_m := w.falloff_end_m if w.falloff_end_m > 0.0 else (w.max_range_m if w.max_range_m > 0.0 else 100.0)
			_bar(bars, "Cadence de tir", clampf(w.rpm / 1000.0, 0.03, 1.0))
			_bar(bars, "Vitesse de rechargement", clampf(1.0 - (w.reload_s - 1.0) / 5.0, 0.05, 1.0))
			_bar(bars, "Portée", clampf(range_m / 150.0, 0.05, 1.0))
			_bar(bars, "Stabilité", clampf(1.0 - w.recoil_deg / 3.0, 0.05, 1.0))
		LobbyUi.Cat.GADGET:
			var w: WeaponData = e["weapon"]
			_number(numbers, "Charges", str(w.magazine))
			_number(numbers, "Prix", "%d ¢" % e["price"])
		LobbyUi.Cat.ABILITY:
			var a := AbilityController.get_ability(e["id"])
			_number(numbers, "Recharge", "%d s" % roundi(a.cooldown_s))
			var more := VBoxContainer.new()
			row.add_child(more)
			if a.duration_s > 0.0:
				_number(more, "Durée", "%d s" % roundi(a.duration_s))
			if a.damage > 0.0:
				_number(more, "Dégâts", str(roundi(a.damage)))
			_number(numbers, "Prix", "%d ¢" % e["price"])
		LobbyUi.Cat.KIT:
			var k: KitData = e["kit"]
			_number(numbers, "PV", str(roundi(k.health if k.health > 0 else Config.combat.kit_default_health)))
			var more := VBoxContainer.new()
			row.add_child(more)
			_number(more, "Bouclier", str(roundi(k.shield if k.shield > 0 else Config.combat.kit_default_shield)))
			var speed := VBoxContainer.new()
			row.add_child(speed)
			_number(speed, "Vitesse", "%.1f m/s" % (k.move_speed_mps if k.move_speed_mps > 0 else Config.combat.kit_default_speed))
	return row


static func _number(box: VBoxContainer, name: String, value: String) -> void:
	box.add_child(W.label(name, 15, DIM))
	box.add_child(W.label(value, 36, UiStyle.ICE))


static func _bar(box: VBoxContainer, name: String, ratio: float) -> void:
	box.add_child(W.label(name, 14, DIM))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220, 6)
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = ratio
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.92, 0.95, 0.97)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	box.add_child(bar)
