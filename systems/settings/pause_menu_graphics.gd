extends RefCounted
## Onglet « Graphismes » du menu Échap : choix de la qualité (Bas / Moyen / Haut).

const Store := preload("res://systems/settings/settings_store.gd")
const Qualite := preload("res://systems/rendu/qualite_graphique.gd")


static func build() -> Control:
	var list := VBoxContainer.new()
	list.name = "Graphismes"
	list.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = "Qualité graphique"
	list.add_child(label)
	var choix := OptionButton.new()
	for nom: String in Qualite.NOMS:
		choix.add_item(nom)
	choix.selected = Store.quality()
	choix.item_selected.connect(func(index: int) -> void: Store.set_quality(index))
	list.add_child(choix)
	return list
