extends RefCounted
## Lecture du dictionnaire « public » de ProfileManager (pseudo, réputation, équipement visible).
## Chaque fonction reçoit ce dictionnaire ({} si le gestionnaire n'existe pas encore).


static func name_of(pub: Dictionary, peer: int) -> String:
	if pub.has(peer):
		return String(pub[peer].get("name", "Joueur %d" % peer))
	return "Joueur %d" % peer


static func rep_points(pub: Dictionary, peer: int, faction: int) -> int:
	if not pub.has(peer):
		return 0
	var rep: Dictionary = pub[peer].get("rep", {})
	return int(rep.get(faction, 0))


static func preferred_faction(pub: Dictionary, peer: int) -> int:
	return int(pub[peer].get("preferred", 0)) if pub.has(peer) else 0


static func weapon_mods(pub: Dictionary, peer: int) -> Dictionary:
	return pub[peer].get("weapon_mods", {}) if pub.has(peer) else {}


static func start_weapon(pub: Dictionary, peer: int) -> StringName:
	if pub.has(peer):
		var id := String(pub[peer].get("start_weapon", ""))
		if id != "" and Items.get_item(StringName(id)) != null:
			return StringName(id)
	return Config.start_loadout.base_weapon


## Boutique du joueur, ou {} si elle n'est pas encore connue.
static func shop_of(pub: Dictionary, peer: int) -> Dictionary:
	if pub.has(peer) and pub[peer].has("shop"):
		return pub[peer]["shop"]
	return {}


## Entrée publique d'un profil complet. Réputation avec des clés entières (le JSON les rend en texte).
static func public_entry(profile: Dictionary) -> Dictionary:
	var rep := {}
	for key: String in profile["rep"]:
		rep[int(key)] = int(profile["rep"][key])
	return {
		"name": profile["name"],
		"rep": rep,
		"preferred": int(profile["preferred"]),
		"weapon_mods": profile["loadout"].get("weapon_mods", {}),
		"start_weapon": String(profile["loadout"].get("start_weapon", Config.start_loadout.base_weapon)),
		"shop": profile["loadout"].get("shop", ProfileManager.default_shop()),
	}
