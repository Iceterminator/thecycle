extends RefCounted
## Fichiers de profil de ProfileManager : pseudo nettoyé, profil par défaut, lecture / écriture JSON.

const PROFILES_DIR := "user://profiles/"


static func sanitize(raw: String) -> String:
	var out := ""
	for c in raw.strip_edges():
		if c.is_valid_identifier() or c.is_valid_int() or c in ["-", "_"] or c.to_lower() != c.to_upper():
			out += c
	return out.left(16)


static func path_of(name: String) -> String:
	return PROFILES_DIR + name.to_lower() + ".json"


static func default_profile(name: String) -> Dictionary:
	return {
		"name": name,
		"rep": {"1": 0, "2": 0, "3": 0},
		"preferred": 0,
		"loadout": {
			"kit": String(Config.start_loadout.default_kit),
			"kit_mods": {},
			"weapon_mods": {},
			"start_weapon": String(Config.start_loadout.base_weapon),
			"shop": ProfileManager.default_shop(),
			"appearance": "",
		},
		"stats": {"matches": 0, "evacs": 0, "kills": 0, "best_fame": 0},
	}


## Profil par défaut, complété par le fichier du joueur s'il existe.
static func load_or_default(name: String) -> Dictionary:
	var profile := default_profile(name)
	if FileAccess.file_exists(path_of(name)):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path_of(name)))
		if data is Dictionary:
			profile.merge(data, true)
			profile["name"] = name
	return profile


static func save_profile(profile: Dictionary) -> void:
	var file := FileAccess.open(path_of(profile["name"]), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(profile, "\t"))
