extends RefCounted
## Boutons d'action de la fiche Arsenal : équiper un kit, boutique, arme de départ, mods.
## Modifie l'état de l'équipement de LobbyUi puis appelle lobby._changed().

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const DIM := UiStyle.DIM


static func build(lobby: LobbyUi, box: VBoxContainer, e: Dictionary, unlocked: bool) -> void:
	var id: String = e["id"]
	var cat: int = e["cat"]
	if cat == LobbyUi.Cat.KIT:
		_kit_actions(lobby, box, e, unlocked)
		return
	var is_weapon := cat in [LobbyUi.Cat.PRIMARY, LobbyUi.Cat.SECONDARY]
	var list: Array = lobby._shop_weapons if is_weapon else lobby._shop_gadgets
	if id in list:
		box.add_child(W.action("Retirer de la boutique", true, func() -> void:
			list[list.find(id)] = ""
			lobby._changed()))
	else:
		var target := _target_case(lobby, is_weapon)
		var text := "Mettre dans la boutique (case %d)" % (target + 1) if target >= 0 else "Boutique pleine : choisissez une case (Équipement)"
		box.add_child(W.action(text, unlocked and target >= 0, func() -> void:
			list[target] = id
			var from_loadout: bool = lobby._selected_case >= 0
			lobby._selected_case = -1
			lobby._changed()
			if from_loadout:
				lobby._show_page(LobbyUi.Page.LOADOUT)))
	if cat == LobbyUi.Cat.SECONDARY:
		var is_start: bool = id == lobby._start_weapon
		box.add_child(W.action("Arme de départ ✔" if is_start else "Choisir comme arme de départ", unlocked and not is_start, func() -> void:
			lobby._start_weapon = id
			lobby._changed()))
	if is_weapon:
		box.add_child(W.label("MOD D'ARME", 14, DIM))
		box.add_child(weapon_mod_option(lobby, id))


static func _kit_actions(lobby: LobbyUi, box: VBoxContainer, e: Dictionary, unlocked: bool) -> void:
	var id: String = e["id"]
	var equipped: bool = id == lobby._kit_id
	box.add_child(W.action("Kit équipé ✔" if equipped else "Équiper ce kit", unlocked and not equipped, func() -> void:
		lobby._kit_id = id
		lobby._changed()))
	var k: KitData = e["kit"]
	if k.mods.is_empty():
		return
	box.add_child(W.label("MODS DU KIT" + ("" if equipped else " — équipez le kit pour en choisir un"), 14, DIM))
	for m: Dictionary in k.mods:
		var mod_id := String(m["id"])
		var mod_ok := KitController.mod_unlocked(lobby._me(), k, mod_id)
		var current := String(lobby._kit_mods.get(id, "")) == mod_id
		var text := "%s%s" % [String(m.get("effect", mod_id)), "" if mod_ok else "   [%s]" % FactionData.lock_text(int(k.faction), int(m.get("unlock_level", 0)))]
		box.add_child(W.action(("✔ " if current else "") + text, mod_ok and equipped, func() -> void:
			lobby._kit_mods[id] = "" if current else mod_id
			lobby._changed()))


## Case visée : celle choisie dans l'onglet Équipement, sinon la première vide du bon type.
static func _target_case(lobby: LobbyUi, is_weapon: bool) -> int:
	var selected: int = lobby._selected_case
	if selected >= 0 and (selected < Config.SHOP_WEAPON_SLOTS) == is_weapon:
		return selected if is_weapon else selected - Config.SHOP_WEAPON_SLOTS
	var list: Array = lobby._shop_weapons if is_weapon else lobby._shop_gadgets
	return list.find("")


static func weapon_mod_option(lobby: LobbyUi, weapon_id: String) -> OptionButton:
	var mods := WeaponModData.all()
	var opt := OptionButton.new()
	opt.add_item("Aucun mod")
	var current := String(lobby._weapon_mods.get(weapon_id, ""))
	for i in mods.size():
		var m := mods[i]
		var lock := lobby._lock_text(m.faction, m.faction_level)
		opt.add_item(m.display_name + ("   [%s]" % FactionData.lock_text(m.faction, m.faction_level) if lock != "" else ""))
		opt.set_item_disabled(i + 1, lock != "")
		opt.set_item_tooltip(i + 1, m.description)
		if String(m.id) == current:
			opt.select(i + 1)
	opt.item_selected.connect(func(index: int) -> void:
		if index <= 0:
			lobby._weapon_mods.erase(weapon_id)
		else:
			lobby._weapon_mods[weapon_id] = String(mods[index - 1].id)
		lobby._changed())
	return opt
