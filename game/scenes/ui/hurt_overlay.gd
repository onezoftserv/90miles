class_name HurtOverlay
extends ColorRect
## ui-shell "Hit flash at the screen edges" (damage-feedback design D5): the red edge band over the
## whole screen. It ignores the mouse and is no HUD panel, so marks never avoid it. MetersHud sets
## its strength each frame; at 0 it hides.

const SHADER: Shader = preload("res://scenes/ui/hurt_overlay.gdshader")

var _material: ShaderMaterial = ShaderMaterial.new()
var _strength: float = 0.0


func _init() -> void:
	name = &"HurtOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	visible = false
	_material.shader = SHADER
	material = _material
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_fit)


func _ready() -> void:
	var tuning := HurtCues.tuning()
	_material.set_shader_parameter(&"flash_color", tuning.flash_color)
	_material.set_shader_parameter(&"edge_px", tuning.edge_px)
	_fit()


## The band's alpha now, 0 to 1; 0 hides it.
func show_strength(alpha: float) -> void:
	_strength = maxf(alpha, 0.0)
	visible = _strength > 0.0
	_material.set_shader_parameter(&"strength", _strength)


func strength() -> float:
	return _strength


func _fit() -> void:
	_material.set_shader_parameter(&"size_px", size)
