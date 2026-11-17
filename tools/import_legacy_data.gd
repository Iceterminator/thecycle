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
const ABILITIES_DIR := "res://data/abilities/"
const ABILITY_SCRIPT := "res://resources/ability_data.gd"

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

## Bonus de niveau des kits : texte de la référence -> effets chiffrés (voir KitData).
const PERK_EFFECTS := {
	"Défense contre les créatures +20 %": {"creature_defense": 0.2},
	"Résistance aux créatures +20 %": {"creature_defense": 0.2},
	"Santé et bouclier +50": {"max_health_add": 50.0, "max_shield_add": 50.0},
	"Dégâts de plongée +50": {"dive_damage_add": 50.0},
	"Régénération du carburant +25 %": {"fuel_regen_mult": 0.25},
	"Régénération du carburant +15 %": {"fuel_regen_mult": 0.15},
	"Dégâts contre les créatures +20 %": {"creature_damage": 0.2},
	"Dégâts contre les monstres +30 %": {"creature_damage": 0.3},
	"Énergie +1 charge": {"energy_charges_add": 1.0},
	"Triple saut": {"air_jumps_add": 1.0},
	"Super saut +10 %": {"super_jump_mult": 0.1},
	"Dégâts de charge +25 %": {"punch_damage_mult": 0.25},
	"Délai de régénération de santé -25 % et vitesse de charge +25 %": {"health_regen_delay_mult": -0.25, "charge_speed_mult": 0.25},
	"Vitesse +10 %": {"move_speed_mult": 0.1},
	"Recharge des capacités -20 %": {"ability_cooldown_mult": -0.2},
	"Régénération de santé +20 % et poussée +20 %": {"health_regen_mult": 0.2, "thrust_mult": 0.2},
}

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
	DirAccess.make_dir_recursive_absolute(ABILITIES_DIR)
	for a: Dictionary in root.get("abilities", []):
		if _save_ability(a):
			count += 1
	for g: Dictionary in root.get("gadgets", []):
		count += _save_gadget(g)
	print("[Import] %d fichiers écrits" % count)
	quit(0)


func _save_weapon(w: Dictionary, falloff_min: float) -> bool:
	var id: String = w["id"]
	var res: Resource = load(WEAPON_SCRIPT).new()
	res.set("id", StringName(id))
	res.set("display_name", WEAPON_NAMES.get(id, id))
	res.set("reference_name", w.get("name", ""))
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
	_apply_detailed(res, w.get("detailed", {}))
	_apply_feel(res, w)
	var notes: PackedStringArray = []
	for key: String in ["data_fix", "note"]:
		if w.has(key):
			notes.append(w[key])
	res.set("notes", "\n".join(notes))
	return _save(res, WEAPONS_DIR + id + ".tres")


## Fiche « detailed » de la référence (rôle, ressenti, visuels, son, portée idéale…).
func _apply_detailed(res: Resource, d: Dictionary) -> void:
	for pair: Array in [["role", "role"], ["shot_feel", "shot_feel"], ["projectile_visual", "projectile_visual"],
			["impact", "impact"], ["recoil", "recoil_feel"], ["sound", "sound"], ["counter", "counter"]]:
		res.set(pair[1], d.get(pair[0], ""))
	var best: Array = d.get("best_range_m", [])
	if best.size() == 2:
		res.set("best_range_m", Vector2(best[0], best[1]))
	res.set("strengths", PackedStringArray(d.get("strengths", [])))
	res.set("weaknesses", PackedStringArray(d.get("weaknesses", [])))


## Ressenti visuel déduit de la fiche et des chiffres : couleur par faction (orange Korolev,
## vert Osiris, bleu ICA), traçants plus épais et plus longs pour les grosses armes, fumée
## pour les explosifs. Valeurs de départ, réglables dans chaque .tres.
const FACTION_TRACER := [Color(1.0, 0.85, 0.45), Color(1.0, 0.55, 0.2), Color(0.45, 1.0, 0.55), Color(0.45, 0.75, 1.0)]
const TYPE_WIDTH := [0.015, 0.02, 0.025, 0.04, 0.012, 0.025, 0.015, 0.1, 0.08]


func _apply_feel(res: Resource, w: Dictionary) -> void:
	var type: int = res.get("type")
	var damage: float = res.get("damage")
	var explosive: bool = w.get("projectile_type") == "explosive_projectile"
	var beam: bool = w.get("fire_mode") == "beam"
	res.set("tracer_color", FACTION_TRACER[clampi(res.get("faction"), 0, 3)])
	res.set("tracer_width", 0.07 if beam else TYPE_WIDTH[type])
	var time := 0.06
	if type == 3:
		time = 0.25  # sniper : traînée qui reste
	elif type == 2:
		time = 0.12
	if beam:
		time = float(res.get("fire_interval_s")) * 2.5
	res.set("tracer_time", time)
	var flash := clampf(damage / 40.0, 0.6, 2.5) * (1.5 if type == 4 else 1.0)
	res.set("muzzle_flash_scale", flash)
	var aoe_radius: float = res.get("aoe_radius_m")
	res.set("impact_scale", aoe_radius if explosive and aoe_radius > 0.0 else clampf(damage / 45.0, 0.7, 2.5))
	res.set("projectile_size", 0.15 if explosive else 0.05)
	res.set("smoke_trail", explosive)


func _save_kit(k: Dictionary) -> bool:
	var id: String = k["id"]
	var res: Resource = load(KIT_SCRIPT).new()
	res.set("id", StringName(id))
	res.set("display_name", KIT_NAMES.get(id, id))
	res.set("reference_name", k.get("name", ""))
	res.set("faction", FACTIONS.get(k.get("faction"), 0))
	for field: String in ["faction_level", "health", "shield", "move_speed_mps"]:
		var value: Variant = k.get(field)
		res.set(field, -1.0 if value == null else float(value))
	res.set("faction_level", int(res.get("faction_level")))
	res.set("mobility_type", MOBILITY.get(k.get("mobility_type"), 0))
	res.set("movement", k.get("movement", {}))
	var perks: PackedStringArray = []
	var effects: Array[Dictionary] = []
	for p: Dictionary in k.get("level_perks", []):
		perks.append(p["perk"])
		if not PERK_EFFECTS.has(p["perk"]):
			push_warning("[Import] Bonus de niveau non traduit : %s" % p["perk"])
		effects.append(PERK_EFFECTS.get(p["perk"], {}))
	res.set("level_perks", perks)
	res.set("level_perk_effects", effects)
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


# =========================================================================
# Capacités (étape 8c)
# =========================================================================

const ABILITY_NAMES := {
	"shock_grenade": "Grenade à choc",
	"stim_boost": "Stimulant",
	"heavy_turret": "Tourelle lourde",
	"kinetic_barrier": "Mur cinétique",
	"evasion_cloak": "Voile de fuite",
	"orbital_bombardment": "Pluie orbitale",
	"stand_your_ground": "Pied ferme",
	"skirmish_sphere": "Sphère hostile",
	"warp_bomb": "Bombe de distorsion",
	"triage_sphere": "Sphère de soin",
	"adrenaline_shot": "Montée d'adrénaline",
	"directional_warp": "Saut de phase",
	"precision_strike": "Frappe ciblée",
	"protective_shell": "Coque",
	"surveillance_ward": "Balise d'écoute",
	"concealment_cloak": "Voile d'ombre",
	"healing_aura": "Aura de soin",
	"snare_trap": "Entrave",
	"safeguard": "Paravent",
	"orbital_barrage": "Averse orbitale",
	"cloaking_device": "Camouflage total",
}

const CATEGORIES := {
	"grenade": 0, "stim": 1, "deployable": 2, "barrier": 3, "cloak": 4, "strike": 5,
	"field": 6, "mobility": 7, "shield": 8, "scanner": 9, "trap": 10, "heal": 11,
}

const ABILITY_NUMBERS := [
	"faction_level", "cooldown_s", "duration_s", "delay_s", "radius_m", "damage", "damage_per_s",
	"damage_per_missile", "missiles", "heal_instant", "heal_per_s", "health", "rpm", "range_m",
	"width_m", "height_m", "distance_m", "slow_percent", "scan_interval_s", "max_active",
]

## Effets sur soi, chiffrés d'après le texte « effects » de la référence (valeurs de la
## référence quand elle en donne, sinon estimées). Voir AbilityData.buff.
const ABILITY_BUFFS := {
	"stim_boost": {"damage_taken_mult": 0.8, "health_regen_mult": 2.0, "regen_now": 1.0, "speed_mult": 1.1},
	"evasion_cloak": {"cloak": 0.8, "speed_mult": 1.3, "damage_taken_mult": 1.25},
	"stand_your_ground": {"max_health_add": 150.0, "recoil_mult": 0.5, "speed_mult": 0.8, "no_health_regen": 1.0},
	"adrenaline_shot": {"speed_mult": 1.25, "damage_taken_mult": 1.2, "no_health_regen": 1.0},
	"protective_shell": {"invulnerable": 1.0},
	"concealment_cloak": {"cloak": 0.9, "cloak_moving": 0.4},
	"healing_aura": {"heal_per_s": 15.0},
	"cloaking_device": {"cloak": 0.95, "cloak_breaks_on_fire": 1.0},
}
## Effet à la fin : [effet, durée].
const ABILITY_AFTER_BUFFS := {
	"evasion_cloak": [{"speed_mult": 0.7}, 3.0],
}


func _save_ability(a: Dictionary) -> bool:
	var id: String = a["id"]
	var res: Resource = load(ABILITY_SCRIPT).new()
	res.set("id", StringName(id))
	res.set("display_name", ABILITY_NAMES.get(id, id))
	res.set("reference_name", a.get("name", ""))
	res.set("faction", FACTIONS.get(a.get("faction"), 0))
	res.set("category", CATEGORIES.get(a.get("category"), 1))
	for field: String in ABILITY_NUMBERS:
		if not a.has(field):
			continue
		var value: Variant = a[field]
		if value == null:
			value = -1
		if res.get(field) is int:
			value = int(value)
		res.set(field, value)
	res.set("buff", ABILITY_BUFFS.get(id, {}))
	if ABILITY_AFTER_BUFFS.has(id):
		res.set("after_buff", ABILITY_AFTER_BUFFS[id][0])
		res.set("after_duration_s", ABILITY_AFTER_BUFFS[id][1])
	for key: String in ["activation", "visual", "counterplay", "behavior"]:
		res.set(key, a.get(key, ""))
	res.set("effects", PackedStringArray(a.get("effects", [])))
	res.set("estimated_fields", PackedStringArray(a.get("estimated_fields", [])))
	res.set("notes", a.get("note", ""))
	return _save(res, ABILITIES_DIR + id + ".tres")


# =========================================================================
# Gadgets (étape 8d) : des « armes » spéciales (WeaponData) + leur objet en boutique
# =========================================================================

const GADGET_NAMES := {
	"kheper_revitalizer": "Rayon vital",
	"recall_teleporter": "Balise de rappel",
	"trench_grenade": "Grenade à fragmentation",
}

## Réglages qui ne viennent pas de la référence (valeurs de départ, à équilibrer).
const GADGET_EXTRA := {
	"kheper_revitalizer": {"gadget": 2, "fire_mode": 5, "spin_up_s": 0.0, "fire_interval_s": 0.1, "rpm": 600.0,
		"reload_s": 2.0, "damage": 0.0, "tracer_width": 0.06, "tracer_time": 0.25,
		"tracer_color": Color(0.4, 1.0, 0.55), "estimated_fields": ["reload_s", "coût de l'auto-soin (Config)"]},
	"recall_teleporter": {"gadget": 3, "fire_mode": 3, "charge_time_s": 3.3, "place_time_s": 1.0, "fire_interval_s": 1.0,
		"magazine": 1, "consumable": true, "damage": 0.0, "estimated_fields": ["place_time_s", "magazine"]},
	"trench_grenade": {"gadget": 1, "fire_mode": 1, "projectile_type": 2, "fire_interval_s": 1.0, "magazine": 3,
		"consumable": true, "aoe_damage": 400.0, "estimated_fields": ["fire_interval_s", "magazine (grenades par achat)"]},
}

## Champs de la référence -> champs de WeaponData.
const GADGET_FIELDS := {
	"range_m": "max_range_m", "heal_per_tick": "heal_per_tick", "tick_interval_s": "fire_interval_s",
	"magazine": "magazine", "self_heal": "self_heal", "spin_up_s": "spin_up_s",
	"beacon_health": "beacon_health", "damage": "damage", "radius_m": "aoe_radius_m",
	"falloff_start_m": "falloff_start_m", "fuse_s": "fuse_s", "spawn_cost_credits": "spawn_cost_credits",
	"faction_level": "faction_level",
}


## Renvoie le nombre de fichiers écrits (arme + objet), 0 pour un gadget sans objet.
func _save_gadget(g: Dictionary) -> int:
	var id: String = g["id"]
	if not GADGET_EXTRA.has(id):
		return 0  # Scanner directionnel : fonction toujours disponible, pas un objet
	var res: Resource = load(WEAPON_SCRIPT).new()
	res.set("id", StringName(id))
	res.set("display_name", GADGET_NAMES.get(id, id))
	res.set("reference_name", g.get("name", ""))
	res.set("faction", FACTIONS.get(g.get("faction"), 0))
	res.set("type", 9)  # GADGET
	res.set("slot", 0)
	for src: String in GADGET_FIELDS:
		if g.has(src) and g[src] != null:
			var value: Variant = g[src]
			var field: String = GADGET_FIELDS[src]
			res.set(field, int(value) if res.get(field) is int else float(value))
	var extra: Dictionary = GADGET_EXTRA[id]
	for key: String in extra:
		var value: Variant = extra[key]
		if key == "estimated_fields":
			value = PackedStringArray(g.get("estimated_fields", []) + value)
		res.set(key, value)
	res.set("boosts", [])  # pas de boost sur les gadgets
	res.set("behavior", g.get("behavior", ""))
	res.set("role", g.get("activation", ""))
	res.set("notes", g.get("note", ""))
	if not _save(res, WEAPONS_DIR + id + ".tres"):
		return 0
	var item: Resource = load("res://resources/item_data.gd").new()
	item.set("id", StringName(id))
	item.set("display_name", GADGET_NAMES.get(id, id))
	item.set("kind", 0)  # WEAPON : prend un emplacement d'arme
	item.set("weapon", load(WEAPONS_DIR + id + ".tres"))
	item.set("color", Color(0.4, 1.0, 0.55) if id == "kheper_revitalizer" else Color(0.95, 0.8, 0.4))
	var price: Variant = g.get("spawn_cost_credits")
	item.set("price", int(price) if price != null else 0)
	return 2 if _save(item, "res://data/items/" + id + ".tres") else 1
