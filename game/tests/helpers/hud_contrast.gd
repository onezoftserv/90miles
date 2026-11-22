class_name HudContrast
extends RefCounted
## ui-shell "Readable HUD and menu text" (hud-window-kit design D12): the WCAG contrast ratio of two
## colours from their relative luminance, the formula tools/art/palette.py `luminance` uses, and the
## fill colour of a window piece read from its built PNG, so a test never restates a kit colour.

## The minimum for steady text, and for the alert red on the dark window.
const STEADY: float = 4.5
const ALERT: float = 4.0


## WCAG relative luminance of `color` (its alpha is ignored).
static func luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


## The contrast ratio of `a` and `b`, 1 to 21, in either order.
static func ratio(a: Color, b: Color) -> float:
	var la: float = luminance(a)
	var lb: float = luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## The colour at the centre of the PNG at `path` (a window piece's fill), opaque; magenta when the
## file cannot be read, which no contrast check passes against.
static func centre_color(path: String) -> Color:
	var image: Image = ArtChecks.read_png(path)
	if image == null:
		return Color.MAGENTA
	var color: Color = image.get_pixel(image.get_width() / 2, image.get_height() / 2)
	color.a = 1.0
	return color


static func _channel(value: float) -> float:
	if value <= 0.04045:
		return value / 12.92
	return pow((value + 0.055) / 1.055, 2.4)
