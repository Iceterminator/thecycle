class_name WaitingScreen
extends CanvasLayer
## Écran d'attente (client sans joueur) : connecté pendant le largage ou la partie, on attend
## le lobby suivant. Affiché / masqué par le MatchManager (RPC _show_waiting).


func _ready() -> void:
	layer = 20
	visible = false
	var back := ColorRect.new()
	back.color = Color(0.03, 0.04, 0.06)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var label := Label.new()
	label.text = "Partie en cours, vous rejoindrez la prochaine"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	add_child(label)


func show_waiting(value: bool) -> void:
	visible = value
	if value:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
