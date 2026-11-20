class_name PostTraitement
extends CanvasLayer
## Post-traitement plein écran (aberration chromatique, vignette, grain).
## Placé sous le HUD (layer 1) : le HUD reste net. Désactivable avec set_actif().

const SHADER := preload("res://systems/rendu/post_traitement.gdshader")

var _rect: ColorRect


func _ready() -> void:
	layer = 0
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_rect.material = mat
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_actif(actif: bool) -> void:
	visible = actif
