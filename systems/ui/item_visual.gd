class_name ItemVisual
extends RefCounted
## Crée le bon visuel pour un id d'objet : arme ou gadget (WeaponIcon), capacité
## (AbilityIcon) ou kit (KitIcon), en métal clair avec le liseré de sa faction.
## Les trois ont les propriétés `tint` et `accent` (voir set_colors).

const METAL := Color(0.88, 0.9, 0.93)
const KITS_DIR := "res://data/kits/"


## Visuel de l'objet `id`, ou null si l'id est inconnu.
static func make(id: String) -> Control:
	if id == "":
		return null
	var faction := 0
	var visual: Control = null
	var item := Items.get_item(StringName(id))
	if item and item.weapon:
		var icon := WeaponIcon.new()
		icon.weapon = item.weapon
		faction = int(item.weapon.faction)
		visual = icon
	else:
		var ability := AbilityController.get_ability(id)
		if ability:
			var icon := AbilityIcon.new()
			icon.ability = ability
			faction = int(ability.faction)
			visual = icon
		elif ResourceLoader.exists(KITS_DIR + id + ".tres"):
			var kit := load(KITS_DIR + id + ".tres") as KitData
			if kit:
				var icon := KitIcon.new()
				icon.kit = kit
				faction = int(kit.faction)
				visual = icon
	if visual:
		visual.set_meta("faction", faction)
		set_colors(visual, false)
	return visual


## Couleurs normales (métal + faction) ou verrouillées (rouge terne, sans liseré).
static func set_colors(visual: Control, locked: bool) -> void:
	if visual == null:
		return
	var faction: int = visual.get_meta("faction", 0)
	visual.set("tint", Color(0.75, 0.45, 0.45, 0.8) if locked else METAL)
	visual.set("accent", FactionData.color_of(faction) if faction > 0 and not locked else Color(0, 0, 0, 0))
