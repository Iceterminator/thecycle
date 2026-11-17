extends SceneTree
## Génère data/weapons/<id>.tres et data/kits/<id>.tres depuis
## data/reference/the_cycle_legacy_data.json.
##
## Lancer depuis la racine du projet (éditeur fermé) :
##   godot --headless --path . -s tools/import_legacy_data.gd
##
## Attention : réécrit les .tres générés (les retouches faites à la main dessus sont perdues).
## Les noms affichés sont les nôtres (le jeu ne reprend pas les noms de l'original) ;
## l'id (= nom de fichier) reste celui du JSON pour retrouver la source.

const JSON_PATH := "res://data/reference/the_cycle_legacy_data.json"
const WEAPON_SCRIPT := "res://resources/weapon_data.gd"
const KIT_SCRIPT := "res://resources/kit_data.gd"
const WEAPONS_DIR := "res://data/weapons/"
const KITS_DIR := "res://data/kits/"

const WEAPON_NAMES := {
	"s76_pdw": "Guêpe",
	"ar55_phase_autorifle": "Vigie",
	"c32_bolt_action": "Faucon",
	"ff4_detonator": "Bélier",
	"k28_autopistol": "Dard",
	"kor_47": "Enclume",
	"komrad": "Grêle",
	"kbr_longshot": "Héron",
	"km9_scrapper": "Éclat",
	"pkr_maelstrom": "Tornade",
	"karma_1": "Tonnerre",
	"karla": "Marteau-pilon",
	"hammer": "Barillet",
	"asp_flechette_gun": "Aiguille",
	"phasic_lancer": "Trident",
	"manticore": "Lynx",
	"gorgon": "Orage",
	"basilisk": "Épervier",
	"zeus_beam": "Fournaise",
	"scarab_pistol": "Luciole",
	"ica_guarantee": "Rempart",
	"shattergun": "Brise-roc",
	"kinetic_arbiter": "Longue-vue",
	"voltaic_brute": "Étincelle",
	"lacerator": "Lame",
	"advocate": "Sentinelle",
	"haze": "Nuée",
	"bulldog": "Tromblon",
}

const KIT_NAMES := {
	"dragonfly_flightsuit": "Combinaison Martinet",
	"aani_quicksuit": "Combinaison Furet",
	"boxer_warsuit": "Armure Bastion",
	"basic_prospector_kit": "Kit de prospecteur",
	"augment": "Kit nu",
}

const FACTIONS := { "starter": 0, "korolev": 1, "osiris": 2, "ica": 3 }
const TYPES := {
	"smg": 0, "assault_rifle": 1, "battle_rifle": 2, "sniper_rifle": 3, "shotgun": 4,
	"lmg": 5, "pistol": 6, "missile_launcher": 7, "heavy": 8,
}
const SLOTS := { "primary": 0, "secondary": 1 }
const FIRE_MODES := { "auto": 0, "semi": 1, "burst": 2, "charge": 3, "charge_burst": 4, "beam": 5 }
const PROJECTILE_TYPES := { "hitscan": 0, "projectile": 1, "explosive_projectile": 2 }
const MOBILITY := { "none": 0, "jetpack": 1, "dash": 2, "super_jump": 3, "jetboosters": 4 }

## Champs numériques copiés tels quels (null -> -1).
const WEAPON_NUMBERS := [
	"faction_level", "damage", "pellets", "pellet_damage", "spread_deg", "rpm", "fire_interval_s",
	"dps", "burst_count", "burst_interval_s", "charge_time_s", "spin_up_s", "weakspot_multiplier",
	"falloff_start_m", "falloff_end_m", "max_range_m", "damage_vs_shield_multiplier",
	"damage_vs_health_multiplier", "projectile_speed_mps", "aoe_damage", "aoe_radius_m",
	"magazine", "reload_s", "ads_time_s", "equip_time_s", "stability", "scope_zoom",
	"hipfire_spread_multiplier", "recoil_multiplier", "spawn_cost_credits", "unlock_cost",
]

## Réglages propres au remake, par type d'arme : [dispersion hanche, dispersion visée, recul].
const HANDLING_BY_TYPE := {
	0: [2.5, 0.9, 0.5],   # SMG
	1: [1.5, 0.4, 0.8],   # fusil d'assaut
	2: [1.5, 0.3, 1.2],   # fusil de combat
	3: [4.0, 0.0, 3.0],   # sniper
	4: [1.0, 0.5, 2.5],   # fusil à pompe
	5: [2.5, 0.5, 0.7],   # mitrailleuse
	6: [1.0, 0.3, 1.6],   # pistolet
	7: [1.0, 0.3, 2.0],   # lance-roquettes
	8: [1.0, 0.3, 2.0],   # arme lourde
}


func _init() -> void:
	var text := FileAccess.get_file_as_string(JSON_PATH)
	var root: Variant = JSON.parse_string(text)
	if not root is Dictionary:
		push_error("[Import] JSON illisible : %s" % JSON_PATH)
		quit(1)
		return
	var falloff_min: float = root["combat_rules"]["falloff_min_multiplier"]
	DirAccess.make_dir_recursive_absolute(KITS_DIR)
	var count := 0
	for w: Dictionary in root["weapons"]:
		if _save_weapon(w, falloff_min):
			count += 1
	for k: Dictionary in root["kits"]:
		if _save_kit(k):
			count += 1
	print("[Import] %d fichiers écrits" % count)
	quit(0)


func _save_weapon(w: Dictionary, falloff_min: float) -> bool:
	var id: String = w["id"]
	var res: Resource = load(WEAPON_SCRIPT).new()
	res.set("id", StringName(id))
	res.set("display_name", WEAPON_NAMES.get(id, id))
	res.set("faction", FACTIONS.get(w.get("faction"), 0))
	res.set("type", TYPES.get(w.get("type"), 1))
	res.set("slot", SLOTS.get(w.get("slot"), 0))
	res.set("fire_mode", FIRE_MODES.get(w.get("fire_mode"), 0))
	res.set("projectile_type", PROJECTILE_TYPES.get(w.get("projectile_type"), 0))
	for field: String in WEAPON_NUMBERS:
		if not w.has(field):
			continue
		var value: Variant = w[field]
		if value == null:
			value = -1
		# Les champs int de WeaponData reçoivent un int (JSON donne des float).
		if res.get(field) is int:
			value = int(value)
		res.set(field, value)
	# Pistolets : baisse de dégâts jusqu'à 0,2 (patch du jeu d'origine).
	var weapon_type: int = res.get("type")
	res.set("falloff_min_multiplier", 0.2 if weapon_type == 6 else falloff_min)
	var handling: Array = HANDLING_BY_TYPE[weapon_type]
	res.set("hip_spread_deg", handling[0])
	res.set("ads_spread_deg", handling[1])
	res.set("recoil_deg", handling[2])
	res.set("estimated_fields", PackedStringArray(w.get("estimated_fields", [])))
	res.set("behavior", w.get("behavior", ""))
	var notes: PackedStringArray = []
	for key: String in ["data_fix", "note"]:
		if w.has(key):
			notes.append(w[key])
	res.set("notes", "\n".join(notes))
	return _save(res, WEAPONS_DIR + id + ".tres")


func _save_kit(k: Dictionary) -> bool:
	var id: String = k["id"]
	var res: Resource = load(KIT_SCRIPT).new()
	res.set("id", StringName(id))
	res.set("display_name", KIT_NAMES.get(id, id))
	res.set("faction", FACTIONS.get(k.get("faction"), 0))
	for field: String in ["faction_level", "health", "shield", "move_speed_mps"]:
		var value: Variant = k.get(field)
		res.set(field, -1.0 if value == null else float(value))
	res.set("faction_level", int(res.get("faction_level")))
	res.set("mobility_type", MOBILITY.get(k.get("mobility_type"), 0))
	res.set("movement", k.get("movement", {}))
	var perks: PackedStringArray = []
	for p: Dictionary in k.get("level_perks", []):
		perks.append(p["perk"])
	res.set("level_perks", perks)
	var mods: Array[Dictionary] = []
	for m: Dictionary in k.get("mods", []):
		mods.append(m)
	res.set("mods", mods)
	res.set("estimated_fields", PackedStringArray(k.get("estimated_fields", [])))
	res.set("history", k.get("history", ""))
	res.set("playstyle", k.get("playstyle", ""))
	return _save(res, KITS_DIR + id + ".tres")


func _save(res: Resource, path: String) -> bool:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("[Import] Échec d'écriture %s (%s)" % [path, error_string(err)])
		return false
	return true
