class_name GripTuner
extends CanvasLayer
## Outil de dev local : règle en jeu la prise (position) et la taille de l'arme en main.
## Touches : ← → (x), ↑ ↓ (avant / arrière), Ctrl + ↑ ↓ ou Page ↑ / ↓ (hauteur), + / − (taille),
## F1 / F2 / F3 / F4 = vue 1re personne / côté droit / côté gauche / dessus,
## G = bascule la cible réglée (Arme / Main gauche : mêmes touches, la taille reste sur l'arme),
## Maj = pas fin, Entrée = enregistrer, Retour arrière = annuler (les deux), Fin = quitter.
## Enregistre (GripTunerSave) : « MainGauche » (si réglé) et « Poignee » dans la scène *_held.tscn (donc toutes les armes
## qui partagent ce modèle) et, si la taille a changé, `model_length` de l'arme.

const STEP := 0.003         ## 3 mm
const STEP_FINE := 0.001    ## 1 mm (Maj)
const SCALE_STEP := 1.01
const SCALE_STEP_FINE := 1.002
const MOVE_KEYS := [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN]
const HELP := "G : régler l'arme / la main gauche\n← → : x   ↑ ↓ : avant/arrière   Ctrl+↑↓ ou Page ↑/↓ : hauteur   + − : taille\nF1-F4 : vue (1re pers./droite/gauche/dessus)\nMaj : pas fin (3 mm → 1 mm)   Entrée : enregistrer   Retour arrière : annuler   Fin : quitter"

var _player: Player
var _label: Label
var _message := ""
var _message_ok := true
var _last_weapon: WeaponData
var _camera: GripTunerCamera
var _hand_mode := false  ## vrai : les touches règlent la main gauche au lieu de l'arme


func setup(player: Player) -> void:
	_player = player
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	add_child(panel)
	_label = Label.new()
	panel.add_child(_label)
	_last_weapon = _player.held_weapon.current_weapon()
	_camera = GripTunerCamera.new()
	_player.get_parent().add_child(_camera)
	_camera.setup(_player)
	_update_label()


func _exit_tree() -> void:
	if is_instance_valid(_camera):
		_camera.set_view(GripTunerCamera.View.FPS)
		_camera.queue_free()


func _process(_delta: float) -> void:
	var held := _player.held_weapon
	if held.current_weapon() != _last_weapon:
		_last_weapon = held.current_weapon()
		_reset()
		_message = ""
		_update_label()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var held := _player.held_weapon
	var step := STEP_FINE if key.shift_pressed else STEP
	var factor := SCALE_STEP_FINE if key.shift_pressed else SCALE_STEP
	var v := held.tune_left if _hand_mode else held.tune_offset  # décalage réglé (arme ou main gauche)
	match key.keycode:
		KEY_LEFT: v.x -= step
		KEY_RIGHT: v.x += step
		KEY_UP:
			if key.ctrl_pressed: v.y += step
			else: v.z -= step
		KEY_DOWN:
			if key.ctrl_pressed: v.y -= step
			else: v.z += step
		KEY_PAGEUP: v.y += step
		KEY_PAGEDOWN: v.y -= step
		KEY_G: _hand_mode = not _hand_mode
		KEY_KP_ADD, KEY_EQUAL: held.tune_scale *= factor
		KEY_KP_SUBTRACT, KEY_MINUS: held.tune_scale /= factor
		KEY_ENTER, KEY_KP_ENTER: _save()
		KEY_F1: _camera.set_view(GripTunerCamera.View.FPS)
		KEY_F2: _camera.set_view(GripTunerCamera.View.DROITE)
		KEY_F3: _camera.set_view(GripTunerCamera.View.GAUCHE)
		KEY_F4: _camera.set_view(GripTunerCamera.View.DESSUS)
		KEY_BACKSPACE: _reset()
		KEY_END:
			_reset()
			queue_free()
		_: return
	if key.keycode in MOVE_KEYS:
		if _hand_mode:
			held.tune_left = v
		else:
			held.tune_offset = v
	get_viewport().set_input_as_handled()
	_update_label()


func _reset() -> void:
	_player.held_weapon.tune_offset = Vector3.ZERO
	_player.held_weapon.tune_left = Vector3.ZERO
	_player.held_weapon.tune_scale = 1.0


func _update_label() -> void:
	var held := _player.held_weapon
	var weapon := held.current_weapon()
	var text := "Aucune arme en main"
	var view_line := "Vue : " + _camera.view_name() + "\n"
	if weapon:
		var scene_name := weapon.model.resource_path.get_file() if weapon.model else "(aucun modèle)"
		var d := (held.tune_left if _hand_mode else held.tune_offset) * 100.0
		text = view_line + "%s - %s\nRéglage : %s\nDécalage (cm) : x %.1f  y %.1f  avant %.1f\nTaille : %d %%  (longueur %.3f m)\n%s" % [
			weapon.display_name, scene_name, "Main gauche" if _hand_mode else "Arme", d.x, d.y, -d.z,
			roundi(held.tune_scale * 100.0), weapon.model_length * held.tune_scale, HELP]
	if _message != "":
		text += "\n" + _message
	_label.text = text
	if _message == "":
		_label.remove_theme_color_override("font_color")
	else:
		_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5) if _message_ok else Color(1.0, 0.45, 0.4))


func _say(message: String, ok: bool) -> void:
	_message = message
	_message_ok = ok


## Enregistre les repères de la scène held et la longueur de l'arme (voir GripTunerSave).
func _save() -> void:
	var held := _player.held_weapon
	var error := GripTunerSave.save(held)
	if error != "":
		_say(error, false)
		return
	var path := held.current_weapon().model.resource_path
	_reset()
	held.rebuild()
	_say("Enregistré : %s (toutes les armes de ce modèle sont touchées)" % path, true)
