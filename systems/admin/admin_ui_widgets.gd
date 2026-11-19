extends RefCounted
## Petits composants du menu admin : titre de section, rangée, bouton, info-bulle d'arme.


static func section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	return label


static func row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	return r


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(176, 34)
	b.pressed.connect(on_pressed)
	return b


## Résumé de l'arme au survol : type de tir et chiffres principaux.
static func weapon_tooltip(w: WeaponData) -> String:
	if w == null:
		return ""
	var modes := ["auto", "coup par coup", "rafale", "charge", "rafale chargée", "rayon"]
	var shots := ["instantané", "projectile", "projectile explosif"]
	var text := "%s — %s, %s\n%d dégâts, %d coups/min, chargeur %d" % [
		w.display_name, modes[w.fire_mode], shots[w.projectile_type], int(w.damage), int(w.rpm), w.magazine]
	if w.is_explosive():
		text += "\nExplosion : %d dégâts sur %.1f m" % [int(w.aoe_damage), w.aoe_radius_m]
	if w.role != "":
		text += "\n" + w.role
	return text
