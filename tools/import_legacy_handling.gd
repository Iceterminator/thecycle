extends RefCounted
## Maniement d'une arme à l'import (vitesse de marche, recul accroupi, dispersions) d'après le jeu
## d'origine. Même logique que tools/wiki_2019/make_handling.mjs : modifier les deux ensemble.

## Champ de WeaponData -> [clé de l'arme ("" = aucune), clé de handling_raw].
const FIELDS := {
	"move_speed_multiplier": ["move_speed_multiplier", "move_speed_multiplier"],
	"ads_move_speed_multiplier": ["", "ads_move_speed_multiplier"],
	"crouch_recoil_multiplier": ["crouch_recoil_multiplier", "crouch_recoil_multiplier"],
	"crouch_spread_multiplier": ["", "crouch_spread_multiplier"],
	"moving_spread_multiplier": ["", "moving_spread_multiplier"],
	"in_air_spread_multiplier": ["", "in_air_spread_multiplier"],
}


## Remplit les champs de maniement de `res` ; `hip_by_type` = dispersion à la hanche du type.
## Les champs absents de la source prennent la moyenne du type et vont dans estimated_fields.
static func apply(res: Resource, w: Dictionary, weapons: Array, hip_by_type: float) -> void:
	var same_type: Array = weapons.filter(func(o: Dictionary) -> bool: return o.get("type") == w.get("type"))
	var estimated: PackedStringArray = res.get("estimated_fields")
	for field: String in FIELDS:
		var value: Variant = _own(w, field)
		if value == null:
			value = _type_mean(same_type, field)
			if not field in estimated:
				estimated.append(field)
		res.set(field, snappedf(float(value) if value != null else 1.0, 0.001))
	res.set("estimated_fields", estimated)
	res.set("hip_spread_deg", snappedf(hip_by_type * _spread_ratio(w, same_type), 0.001))


## Valeur propre à l'arme (clé de l'arme, sinon handling_raw), ou null.
static func _own(w: Dictionary, field: String) -> Variant:
	var keys: Array = FIELDS[field]
	if keys[0] != "" and w.get(keys[0]) is float:
		return w[keys[0]]
	var raw: Dictionary = w.get("handling_raw", {})
	return raw[keys[1]] if raw.get(keys[1]) is float else null


## Moyenne du type ; les 0 (Gorgon) sont ignorés, ils fausseraient la valeur typique.
static func _type_mean(same_type: Array, field: String) -> Variant:
	var total := 0.0
	var count := 0
	for o: Dictionary in same_type:
		var v: Variant = _own(o, field)
		if v != null and float(v) > 0.0:
			total += float(v)
			count += 1
	return snappedf(total / count, 0.001) if count > 0 else null


## base_spread_deg de l'arme / moyenne de son type (1 si l'arme n'a pas de base_spread_deg).
static func _spread_ratio(w: Dictionary, same_type: Array) -> float:
	if not w.get("base_spread_deg") is float:
		return 1.0
	var total := 0.0
	var count := 0
	for o: Dictionary in same_type:
		if o.get("base_spread_deg") is float:
			total += float(o["base_spread_deg"])
			count += 1
	return float(w["base_spread_deg"]) / (total / count)
