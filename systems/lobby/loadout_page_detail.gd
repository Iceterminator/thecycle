extends RefCounted
## Écran 2 de l'onglet Équipement : fiche d'un objet (description, mods, statistiques).

const W := preload("res://systems/lobby/lobby_ui_widgets.gd")
const Slots := preload("res://systems/lobby/loadout_page_slots.gd")
const Info := preload("res://systems/lobby/loadout_page_info.gd")
const DIM := UiStyle.DIM


static func build(page: LoadoutPage) -> void:
	var lobby := page.lobby
	var box := page._panel_box
	W.clear(box)
	var id := Slots.slot_id(lobby, page._slot)
	if id == "":
		page.show_overview()
		return
	page._preview(id)
	var e := lobby._entry(id)
	box.add_child(W.label(String(e.get("name", id)), 40))
	box.add_child(W.label(Info.type_line(e), 17, FactionData.color_of(int(e.get("faction", 0))).lightened(0.2)))
	var text := Info.description(e)
	if text != "":
		var label := W.label(text, 15, Color(1, 1, 1, 0.8))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(label)
	# Mods.
	match int(e.get("cat", -1)):
		LobbyUi.Cat.PRIMARY, LobbyUi.Cat.SECONDARY:
			box.add_child(W.label("MOD D'ARME", 16, DIM))
			box.add_child(lobby._weapon_mod_option(id))
		LobbyUi.Cat.KIT:
			var kit: KitData = e["kit"]
			if not kit.mods.is_empty():
				box.add_child(W.label("MOD DE LA COMBINAISON", 16, DIM))
				var current := String(lobby._kit_mods.get(id, ""))
				for m: Dictionary in kit.mods:
					var mod_id := String(m["id"])
					var ok := KitController.mod_unlocked(lobby._me(), kit, mod_id)
					var label := String(m.get("effect", mod_id)) + ("" if ok else "   [%s]" % FactionData.lock_text(int(kit.faction), int(m.get("unlock_level", 0))))
					box.add_child(W.action(("✔ " if current == mod_id else "") + label, ok, func() -> void:
						lobby._kit_mods[id] = "" if current == mod_id else mod_id
						lobby._changed()))
	box.add_child(HSeparator.new())
	box.add_child(W.label("STATISTIQUES", 16, DIM))
	box.add_child(Info.stats(lobby, e))
	var buttons := page._button_bar
	buttons.add_child(W.big_button("FERMER", false, page.show_overview))
	buttons.add_child(W.big_button("CHANGER ⇄", true, func() -> void: page._open(LoadoutPage.View.PICKER, page._slot)))
