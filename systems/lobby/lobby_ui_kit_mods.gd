extends RefCounted
## Mods d'un kit dans le lobby : une liste déroulante par emplacement (Cœur, Niveau 1 à 3),
## « Aucun » + les mods possibles, description en infobulle. Le cœur est propre au kit
## (verrouillé par la réputation), les niveaux sont ouverts à tous les kits.

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")


## Bloc de listes pour le kit `kit_id`. `editable` faux : listes grisées (kit non équipé).
static func options(lobby: LobbyUi, kit_id: String, editable: bool = true) -> Control:
	var box := VBoxContainer.new()
	var kit: KitData = lobby._kit_data(kit_id)
	if kit == null:
		return box
	for i in KitModData.SLOTS.size():
		var key: String = KitModData.SLOTS[i]
		var choices := _choices(lobby, kit, key)
		if key == "core" and choices.is_empty():
			continue  # Kit de prospecteur, Kit nu : pas de cœur
		box.add_child(_slot_row(lobby, kit_id, key, KitModData.SLOT_LABELS[i], choices, editable))
	return box


## Mods d'un emplacement : [{ id, name, text, locked }].
static func _choices(lobby: LobbyUi, kit: KitData, key: String) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if key == "core":
		for m: Dictionary in kit.mods:
			var ok := KitController.mod_unlocked(lobby._me(), kit, String(m["id"]))
			var text := String(m.get("effect", ""))
			if not ok:
				text += "   [%s]" % FactionData.lock_text(int(kit.faction), int(m.get("unlock_level", 0)))
			list.append({"id": String(m["id"]), "name": String(m.get("name", m["id"])), "text": text, "locked": not ok})
	else:
		for m in KitModData.for_tier(int(key)):
			list.append({"id": String(m.id), "name": m.display_name, "text": m.description, "locked": false})
	return list


static func _slot_row(lobby: LobbyUi, kit_id: String, key: String, label_text: String,
		choices: Array[Dictionary], editable: bool) -> Control:
	var row := HBoxContainer.new()
	var label := W.label(label_text, 15, Color(1, 1, 1, 0.8))
	label.custom_minimum_size.x = 90
	row.add_child(label)
	var opt := OptionButton.new()
	opt.disabled = not editable
	opt.add_item("Aucun")
	var current := String(lobby._kit_mods.get(kit_id, {}).get(key, ""))
	for i in choices.size():
		opt.add_item(String(choices[i]["name"]))
		opt.set_item_tooltip(i + 1, String(choices[i]["text"]))
		opt.set_item_disabled(i + 1, bool(choices[i]["locked"]))
		if String(choices[i]["id"]) == current:
			opt.select(i + 1)
	opt.tooltip_text = "" if opt.selected <= 0 else String(choices[opt.selected - 1]["text"])
	opt.item_selected.connect(func(index: int) -> void:
		var picked: Dictionary = lobby._kit_mods.get(kit_id, {}).duplicate()
		if index <= 0:
			picked.erase(key)
		else:
			picked[key] = String(choices[index - 1]["id"])
		lobby._kit_mods[kit_id] = picked
		lobby._changed())
	row.add_child(opt)
	return row


## Résumé des mods équipés d'un kit (cartes de l'équipement) : « Catapulte, Festin ».
static func summary(lobby: LobbyUi, kit_id: String) -> String:
	var kit: KitData = lobby._kit_data(kit_id)
	var names: Array[String] = []
	var chosen: Dictionary = lobby._kit_mods.get(kit_id, {})
	for key: String in KitModData.SLOTS:
		var id := String(chosen.get(key, ""))
		if id == "":
			continue
		if key == "core":
			names.append(id)
			for m: Dictionary in kit.mods if kit else []:
				if String(m["id"]) == id:
					names[-1] = String(m.get("name", id))
		else:
			var mod := KitModData.get_mod(id)
			names.append(mod.display_name if mod else id)
	return ", ".join(names)
