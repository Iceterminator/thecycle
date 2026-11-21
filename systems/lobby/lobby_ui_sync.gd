extends RefCounted
## Synchro de l'équipement du lobby avec le serveur : chargement du profil sauvegardé et envoi.
## L'état lui-même (_kit_id, _shop_weapons, …) reste dans LobbyUi.

const LoadoutRules := preload("res://systems/profiles/profile_loadout_rules.gd")


static func padded(list: Array, size: int) -> Array:
	var out: Array = []
	for i in size:
		out.append(String(list[i]) if i < list.size() else "")
	return out


## Équipement sauvegardé (envoyé par le serveur à l'arrivée).
static func apply_saved(lobby: LobbyUi, loadout: Dictionary) -> void:
	lobby._preferred = int(loadout.get("preferred", 0))
	lobby._appearance = String(loadout.get("appearance", ""))
	lobby._kit_id = String(loadout.get("kit", Config.start_loadout.default_kit))
	lobby._kit_mods = {}
	for kit_id: String in loadout.get("kit_mods", {}):
		lobby._kit_mods[kit_id] = LoadoutRules.kit_slots(loadout["kit_mods"][kit_id])
	lobby._weapon_mods = {}
	for weapon_id: String in loadout.get("weapon_mods", {}):
		var chosen: Variant = loadout["weapon_mods"][weapon_id]
		if chosen is Dictionary:  # ancien format (texte) : ignoré
			lobby._weapon_mods[weapon_id] = chosen.duplicate()
	lobby._start_weapon = String(loadout.get("start_weapon", Config.start_loadout.base_weapon))
	var shop: Dictionary = loadout.get("shop", ProfileManager.default_shop())
	lobby._shop_weapons = padded(shop.get("weapons", []), Config.SHOP_WEAPON_SLOTS)
	lobby._shop_gadgets = padded(shop.get("gadgets", []), Config.SHOP_GADGET_SLOTS)
	lobby._refresh()


static func send(lobby: LobbyUi) -> void:
	var profiles := lobby._world.get_node_or_null("ProfileManager") as ProfileManager
	if profiles == null:
		return
	profiles.request_set_loadout.rpc_id(1, {
		"kit": lobby._kit_id,
		"kit_mod": lobby._kit_mods.get(lobby._kit_id, {}),
		"weapon_mods": lobby._weapon_mods,
		"start_weapon": lobby._start_weapon,
		"shop": {"weapons": lobby._shop_weapons, "gadgets": lobby._shop_gadgets},
		"appearance": lobby._appearance,
	}, lobby._preferred)
	lobby._set_status("Équipement enregistré", UiStyle.ACCENT)
