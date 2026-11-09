class_name PaletteSwap
extends RefCounted
## The player look's palette swaps (art-pass "Clothing colours" and "Layered player look"; design.md
## D6 and C1). A ramp image holds one 4-shade ramp per row, highlight, base, shade and line. A swap
## recolours each texel equal to a colour of one row to the same shade of another row, with one
## lookup per texel, so a colour that sits in several rows (#8f563b is a line, a shade and a
## highlight in skin_ramps.png) is never recoloured twice.
## - `map_color` is the reference for what player_look.gdshader does to each texel: the clothing
##   key ramp, row 0 of player_ramps.png, to the look slot's row.
## - `swap_rows` is the image form the look composer uses to move a body sheet from skin row 0 to
##   the look's skin row. Transparent texels are skipped, because import rewrites their RGB.

## Row 0 of player_ramps.png: the clothing key ramp the outfits are drawn in.
const KEY_ROW: int = 0
const SHADES: int = 4
const CHANNELS: int = 4
const ALPHA: int = 3


## Each colour of row `from_row` of `ramps`, as an RGB key, to the same shade of `to_row`. A colour
## repeated in `from_row` keeps its first shade.
static func key_map(ramps: Image, from_row: int, to_row: int) -> Dictionary[int, int]:
	var mapping: Dictionary[int, int] = {}
	for shade: int in SHADES:
		var key: int = rgb_key(ramps.get_pixel(shade, from_row))
		if not mapping.has(key):
			mapping[key] = rgb_key(ramps.get_pixel(shade, to_row))
	return mapping


## What player_look.gdshader draws for a texel of `color` in the look slot drawn from `slot_row`
## of `ramps` (player_ramps.png; the slot's row is its look slot + 1): a key-ramp colour becomes
## the same shade of that row, any other colour stays; alpha is kept.
static func map_color(color: Color, ramps: Image, slot_row: int) -> Color:
	var mapping: Dictionary[int, int] = key_map(ramps, KEY_ROW, slot_row)
	var key: int = rgb_key(color)
	if not mapping.has(key):
		return color
	var mapped: Color = key_color(mapping[key])
	mapped.a = color.a
	return mapped


## A copy of `image` (as RGBA8) whose texels equal to a colour of row `from_row` of `ramps` take
## the same shade of row `to_row`, keeping their alpha. Transparent texels and every other colour
## are unchanged, and so is `image`.
static func swap_rows(image: Image, ramps: Image, from_row: int, to_row: int) -> Image:
	var mapping: Dictionary[int, int] = key_map(ramps, from_row, to_row)
	var source: Image = image.duplicate() as Image
	if source.get_format() != Image.FORMAT_RGBA8:
		source.convert(Image.FORMAT_RGBA8)
	if source.has_mipmaps():
		source.clear_mipmaps()
	var data: PackedByteArray = source.get_data()
	for i: int in range(0, data.size(), CHANNELS):
		if data[i + ALPHA] == 0:
			continue
		var key: int = (data[i] << 16) | (data[i + 1] << 8) | data[i + 2]
		if not mapping.has(key):
			continue
		var to: int = mapping[key]
		data[i] = (to >> 16) & 0xff
		data[i + 1] = (to >> 8) & 0xff
		data[i + 2] = to & 0xff
	return Image.create_from_data(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8, data)


## A colour's 8-bit RGB as one int, alpha ignored.
static func rgb_key(color: Color) -> int:
	return (color.r8 << 16) | (color.g8 << 8) | color.b8


static func key_color(key: int) -> Color:
	return Color8((key >> 16) & 0xff, (key >> 8) & 0xff, key & 0xff)
