class_name PixelFilter
extends RefCounted
## ui-shell "Pixel filter": how the enlarged world picture is drawn. Nítido lets the window
## enlarge the whole 640×360 picture with nearest filtering. Suave draws the root canvas at the
## window's resolution, still at a whole-number scale with black bars, and smooths only the
## world view with the Scale2x shader. The HUD and menus are never filtered.

enum Mode { SHARP, SMOOTH }

## Settings labels, in Mode order.
const LABELS: Array[String] = ["Nítido", "Suave"]
const SCALE2X_SHADER: Shader = preload("res://scenes/shell/scale2x.gdshader")


## The root window's stretch mode for `mode`.
static func stretch_mode(mode: Mode) -> Window.ContentScaleMode:
	if mode == Mode.SMOOTH:
		return Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	return Window.CONTENT_SCALE_MODE_VIEWPORT


## Whether fonts are redrawn at the window's resolution. Suave turns it off, so the HUD's pixel
## fonts are enlarged with the rest of the HUD and look exactly as they do in Nítido.
static func font_oversampling(mode: Mode) -> bool:
	return mode != Mode.SMOOTH


## The world view's material for `mode`: none for Nítido, the Scale2x shader for Suave.
static func material_for(mode: Mode) -> Material:
	if mode != Mode.SMOOTH:
		return null
	var smooth := ShaderMaterial.new()
	smooth.shader = SCALE2X_SHADER
	return smooth
