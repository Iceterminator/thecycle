class_name WeaponModApply
extends RefCounted
## Applique des mods d'arme à une WeaponData : renvoie une COPIE modifiée (la base reste intacte).
## Même résultat sur le serveur et chez les clients (les mods viennent du profil public).

## Champs multipliés dans tous les cas.
const MULT_ALWAYS: Array[String] = ["fire_interval_s", "reload_s", "ads_time_s", "equip_time_s",
		"hip_spread_deg", "recoil_deg", "burst_interval_s", "weakspot_multiplier"]
## Champs multipliés seulement s'ils valent plus de 0 (-1 = inconnu).
const MULT_IF_POSITIVE: Array[String] = ["projectile_speed_mps", "aoe_damage", "aoe_radius_m",
		"spin_up_s", "charge_time_s"]
const RANGE_FIELDS: Array[String] = ["falloff_start_m", "falloff_end_m", "max_range_m"]
const SPIN_UP_FIELDS: Array[String] = ["spin_up_s", "charge_time_s"]
## Clés de mult qui multiplient un champ de même nom + « _multiplier ».
const MULT_RENAMED := {
	"damage_vs_creatures": "damage_vs_creatures_multiplier",
	"damage_vs_players": "damage_vs_players_multiplier",
	"move_speed": "move_speed_multiplier",
}


static func apply(base: WeaponData, mods: Array[WeaponModData]) -> WeaponData:
	var w := base.duplicate() as WeaponData
	w.set_meta("modded", true)
	for mod in mods:
		_apply_mult(w, mod.mult)
		_apply_add(w, mod.add)
		if mod.overrides.has("scope_zoom"):
			w.scope_zoom = float(mod.overrides["scope_zoom"])
		if "piercing" in mod.flags:
			w.piercing = true
		if "explode_on_impact" in mod.flags:
			w.explode_on_impact = true
	return w


static func _apply_mult(w: WeaponData, mult: Dictionary) -> void:
	for key: String in mult:
		var f := float(mult[key])
		if key == "damage":
			w.damage *= f
			if w.pellet_damage > 0.0:
				w.pellet_damage *= f
		elif key == "magazine":
			w.magazine = maxi(roundi(w.magazine * f), 1)
		elif key == "range":
			_scale_positive(w, RANGE_FIELDS, f)
		elif key == "spin_up":
			_scale_positive(w, SPIN_UP_FIELDS, f)
		elif key in MULT_ALWAYS:
			w.set(key, float(w.get(key)) * f)
		elif key in MULT_IF_POSITIVE:
			_scale_positive(w, [key], f)
		elif MULT_RENAMED.has(key):
			var field: String = MULT_RENAMED[key]
			w.set(field, float(w.get(field)) * f)


static func _scale_positive(w: WeaponData, fields: Array[String], f: float) -> void:
	for field in fields:
		if float(w.get(field)) > 0.0:
			w.set(field, float(w.get(field)) * f)


static func _apply_add(w: WeaponData, add: Dictionary) -> void:
	for key: String in add:
		match key:
			"aoe_damage":
				w.aoe_damage = maxf(w.aoe_damage, 0.0) + float(add[key])
			"aoe_radius_m":
				w.aoe_radius_m = maxf(w.aoe_radius_m, 0.0) + float(add[key])
			"burst_count":
				w.burst_count = maxi(w.burst_count + int(add[key]), 1)
				# Mods « mode rafale » / « coup par coup » : le mode de tir suit le nombre de tirs.
				if w.burst_count > 1 and w.fire_mode == WeaponData.FireMode.SEMI:
					w.fire_mode = WeaponData.FireMode.BURST
					if w.burst_interval_s <= 0.0:
						w.burst_interval_s = 0.07
				elif w.burst_count == 1 and w.fire_mode == WeaponData.FireMode.BURST:
					w.fire_mode = WeaponData.FireMode.SEMI
