class_name SeaShaderChecks
extends RefCounted
## What a test can know about `world_sea.gdshader` and the materials that use it without a window
## (art-pass "Scrolling sea"; design.md D12, K47): its source, the drift a material gives it, and the
## shader's own cut rule evaluated in GDScript on the depth mask's bytes.

## design.md D12: the water drifts 5 px/s east.
const DRIFT_PX_PER_S: float = 5.0
const SHADER_PATH: String = "res://scenes/art/sea/world_sea.gdshader"


static func source() -> String:
	return (load(SHADER_PATH) as Shader).code


## The drift of `material` in px/s: the parameter it sets, or the shader's own default.
static func drift_of(material: ShaderMaterial) -> Vector2:
	var set_to: Variant = material.get_shader_parameter(&"drift")
	if set_to is Vector2:
		return set_to
	var found := RegEx.create_from_string("uniform\\s+vec2\\s+drift\\s*=\\s*vec2\\(\\s*([-\\d.]+)\\s*,\\s*([-\\d.]+)\\s*\\)").search(source())
	if found == null:
		return Vector2.ZERO
	return Vector2(float(found.get_string(1)), float(found.get_string(2)))


## The ramp row the shader's fragment() picks for a texel of the mask with the sway at zero, so the
## cut is 0.5: the shallows row when r is above the cut, the brackish row when g is too, else deep.
static func row_for(mask: Color, deep: int, shallows: int, brackish: int) -> int:
	if mask.r > 0.5:
		return brackish if mask.g > 0.5 else shallows
	return deep
