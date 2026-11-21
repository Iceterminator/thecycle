extends RefCounted
## Boutons d'action de la fiche Arsenal : équiper un kit, boutique, arme de départ, mods.
## Modifie l'état de l'équipement de LobbyUi puis appelle lobby._changed().

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const KitMods := preload("res://systems/lobby/lobby_ui_kit_mods.gd")
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
	box.add_child(W.label("MODS DU KIT" + ("" if equipped else " — équipez le kit pour les choisir"), 14, DIM))
	box.add_child(KitMods.options(lobby, id, equipped))


## Case visée : celle choisie dans l'onglet Équipement, sinon la première vide du bon type.
static func _target_case(lobby: LobbyUi, is_weapon: bool) -> int:
	var selected: int = lobby._selected_case
	if selected >= 0 and (selected < Config.SHOP_WEAPON_SLOTS) == is_weapon:
		return selected if is_weapon else selected - Config.SHOP_WEAPON_SLOTS
	var list: Array = lobby._shop_weapons if is_weapon else lobby._shop_gadgets
	return list.find("")


## Une liste déroulante par emplacement qui a des mods (« Aucun » + mods), infobulle = description.
static func weapon_mod_option(lobby: LobbyUi, weapon_id: String) -> Control:
	var box := VBoxContainer.new()
	var mods := WeaponModData.for_weapon(StringName(weapon_id))
	if mods.is_empty():
		box.add_child(W.label("Aucun mod pour cette arme", 15, Color(1, 1, 1, 0.5)))
		return box
	for slot in WeaponModData.SLOT_NAMES.size():
		var slot_mods := mods.filter(func(m: WeaponModData) -> bool: return int(m.slot) == slot)
		if not slot_mods.is_empty():
			box.add_child(_slot_option(lobby, weapon_id, slot, slot_mods))
	return box


static func _slot_option(lobby: LobbyUi, weapon_id: String, slot: int, slot_mods: Array) -> Control:
	var row := HBoxContainer.new()
	var label := W.label(WeaponModData.SLOT_NAMES[slot], 15, Color(1, 1, 1, 0.8))
	label.custom_minimum_size.x = 90
	row.add_child(label)
	var opt := OptionButton.new()
	opt.add_item("Aucun")
	var chosen: Dictionary = lobby._weapon_mods.get(weapon_id, {})
	var current := String(chosen.get(str(slot), ""))
	for i in slot_mods.size():
		var m: WeaponModData = slot_mods[i]
		opt.add_item(m.display_name)
		opt.set_item_tooltip(i + 1, m.description)
		if String(m.id) == current:
			opt.select(i + 1)
	opt.tooltip_text = "" if opt.selected <= 0 else (slot_mods[opt.selected - 1] as WeaponModData).description
	opt.item_selected.connect(func(index: int) -> void:
		var picked: Dictionary = lobby._weapon_mods.get(weapon_id, {}).duplicate()
		if index <= 0:
			picked.erase(str(slot))
		else:
			picked[str(slot)] = String((slot_mods[index - 1] as WeaponModData).id)
		if picked.is_empty():
			lobby._weapon_mods.erase(weapon_id)
		else:
			lobby._weapon_mods[weapon_id] = picked
		lobby._changed())
	row.add_child(opt)
	return row
