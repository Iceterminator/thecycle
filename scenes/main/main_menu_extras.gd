extends RefCounted
## Ajouts au menu principal faits en code (pseudo, Partie rapide, serveurs récents)
## et réglages de ce poste (user://settings.cfg : pseudo et derniers serveurs rejoints).

const SETTINGS_PATH := "user://settings.cfg"
const MAX_RECENT := 5

var name_edit: LineEdit
var recent_box: VBoxContainer
var recent: PackedStringArray = []


## Pseudo (en haut), serveurs récents et Partie rapide (en bas).
func build(host_button: Button, status_label: Label, on_quick: Callable) -> void:
	var vbox := host_button.get_parent()
	var name_label := Label.new()
	name_label.text = "Pseudo"
	vbox.add_child(name_label)
	vbox.move_child(name_label, 1)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Votre pseudo (16 caractères max)"
	name_edit.max_length = 16
	vbox.add_child(name_edit)
	vbox.move_child(name_edit, 2)
	var quick := Button.new()
	quick.text = "Partie rapide"
	quick.pressed.connect(on_quick)
	vbox.add_child(quick)
	vbox.move_child(quick, status_label.get_index())
	var recent_title := Label.new()
	recent_title.text = "Serveurs récents"
	vbox.add_child(recent_title)
	recent_box = VBoxContainer.new()
	vbox.add_child(recent_box)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		name_edit.text = String(cfg.get_value("player", "name", ""))
		recent = PackedStringArray(cfg.get_value("servers", "recent", []))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", name_edit.text.strip_edges())
	cfg.set_value("servers", "recent", recent)
	cfg.save(SETTINGS_PATH)


## Place l'adresse en tête des serveurs récents (sans doublon) et sauvegarde.
func remember(address: String) -> void:
	var list := Array(recent)
	list.erase(address)
	list.push_front(address)
	recent = PackedStringArray(list.slice(0, MAX_RECENT))
	save_settings()
