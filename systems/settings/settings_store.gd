extends RefCounted
## Réglages du joueur, propres à ce poste : touches et blocs du HUD affichés.
## Enregistrés dans user://reglages.cfg, appliqués au lancement par Config.
## Les touches par défaut sont celles de project.godot + Config.CODE_KEY_ACTIONS.

const PATH := "user://reglages.cfg"
const Codec := preload("res://systems/settings/settings_store_codec.gd")

## Actions modifiables, dans l'ordre du menu : action -> nom affiché.
## (Échap et le menu admin restent fixes ; l'action « gadget » de project.godot n'est pas utilisée :
## les gadgets prennent les emplacements des capacités.)
const ACTIONS := {
	&"move_forward": "Avancer",
	&"move_back": "Reculer",
	&"move_left": "Aller à gauche",
	&"move_right": "Aller à droite",
	&"jump": "Sauter",
	&"sprint": "Courir",
	&"crouch": "S'accroupir",
	&"fire": "Tirer",
	&"aim": "Viser",
	&"reload": "Recharger",
	&"melee": "Mêlée",
	&"interact": "Interagir / ramasser",
	&"ability_1": "Capacité / gadget 1",
	&"ability_2": "Capacité / gadget 2",
	&"next_weapon": "Arme suivante",
	&"prev_weapon": "Arme précédente",
	&"show_map": "Carte (maintenir)",
	&"open_shop": "Boutique",
	&"pact": "Pactes",
}

## Blocs du HUD : id -> nom affiché.
const HUD_BLOCKS := {
	"minimap": "Minimap",
	"rang": "Rang et Fame",
	"fps": "Compteur d'images (FPS)",
	"objectifs": "Objectifs",
	"horloge": "Horloge et tempête",
	"classement": "Classement",
	"infos": "Escouade, kit, objets, crédits",
	"barres": "Bouclier, PV et capacités",
	"arme": "Arme et munitions",
	"viseur": "Viseur",
}

static var _hud: Dictionary = {}  ## id -> bool (absent = affiché)
static var _qualite: int = 0  ## qualité graphique (0 Bas, 1 Moyen, 2 Haut) ; Bas par défaut (GPU intégrés)
static var _defaults: Dictionary = {}  ## action -> Array[InputEvent], copiés avant les réglages


## Au lancement : retient les touches par défaut puis applique le fichier.
static func load_and_apply() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			_defaults[action] = InputMap.action_get_events(action).duplicate()
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	for action: StringName in ACTIONS:
		if file.has_section_key("touches", action) and InputMap.has_action(action):
			_set_events(action, Codec.decode_all(file.get_value("touches", action, [])))
	for id: String in HUD_BLOCKS:
		_hud[id] = bool(file.get_value("hud", id, true))
	_qualite = clampi(int(file.get_value("graphisme", "qualite", 0)), 0, 2)


static func save() -> void:
	var file := ConfigFile.new()
	for action: StringName in ACTIONS:
		if InputMap.has_action(action) and not _same_as_default(action):
			file.set_value("touches", action, Codec.encode_all(InputMap.action_get_events(action)))
	for id: String in _hud:
		file.set_value("hud", id, _hud[id])
	file.set_value("graphisme", "qualite", _qualite)
	file.save(PATH)


# --- HUD ---

static func hud_shown(id: String) -> bool:
	return _hud.get(id, true)


static func set_hud_shown(id: String, shown: bool) -> void:
	_hud[id] = shown
	save()
	Events.hud_settings_changed.emit()


# --- Touches ---

## Remplace la touche principale de l'action ; la retire des autres actions qui l'utilisaient.
## Renvoie le nom de l'action qui l'a perdue ("" si aucune).
static func rebind(action: StringName, event: InputEvent) -> String:
	var taken := ""
	for other: StringName in ACTIONS:
		if other == action or not InputMap.has_action(other):
			continue
		for old: InputEvent in InputMap.action_get_events(other):
			if Codec.encode(old) == Codec.encode(event):
				InputMap.action_erase_event(other, old)
				taken = ACTIONS[other]
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		events.append(event)
	else:
		events[0] = event
	_set_events(action, events)
	save()
	return taken


static func reset_keys() -> void:
	for action: StringName in _defaults:
		_set_events(action, _defaults[action])
	save()


## Texte de la touche principale (« — » si aucune).
static func key_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	var events := InputMap.action_get_events(action)
	return Codec.event_text(events[0]) if not events.is_empty() else "—"


static func _set_events(action: StringName, events: Array) -> void:
	InputMap.action_erase_events(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _same_as_default(action: StringName) -> bool:
	return Codec.encode_all(InputMap.action_get_events(action)) == Codec.encode_all(_defaults.get(action, []))


# --- Qualité graphique ---

static func quality() -> int:
	return _qualite


static func set_quality(niveau: int) -> void:
	_qualite = clampi(niveau, 0, 2)
	save()
	Events.reglages_graphiques_changes.emit()
