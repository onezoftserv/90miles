class_name ArtChecks
extends RefCounted
## The art-pass checks (task 1.2; design.md D9, D21 and K11), shared by test_art_checks.gd (on
## fixtures) and test_art_tracked.gd (on res://assets/art). Every check returns its failures,
## each naming the file (and the pixel, colour, ground or animation), and an empty array when the
## rule holds. Image checks read the raw PNG, so the import's fix_alpha_border cannot change what
## they see, and never judge the RGB of a fully transparent texel. A palette is a Dictionary whose
## keys are 0xRRGGBB ints.

const OWN_WORK_SOURCE: String = "90 Millas (own work)"
const LICENCE_FILE: String = "License.txt"
## Partial alpha is allowed only in files under these folders, in the darkest palette colour.
const PARTIAL_ALPHA_DIRS: PackedStringArray = ["shadows", "decals"]
## A source on one of these hosts is a licence deed, never a pack's page.
const LICENCE_HOSTS: PackedStringArray = ["creativecommons.org", "opensource.org", "gnu.org", "spdx.org", "opendatacommons.org"]
const REFERRER_EXTENSIONS: PackedStringArray = ["tscn", "tres"]
## How many offending pixels a check lists per file before it only counts them.
const MAX_LISTED: int = 3
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


# --- Files ---------------------------------------------------------------------------------------

## The PNG at `path` as RGBA8, read from its bytes rather than its import; null if unreadable.
static func read_png(path: String) -> Image:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var image: Image = Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


static func pngs_under(root: String) -> PackedStringArray:
	return files_under(root, ["png"])


## Every file under `root` (recursively) with one of `extensions`, sorted; folders in `skipped`
## (full paths) and hidden folders are not entered.
static func files_under(root: String, extensions: PackedStringArray, skipped: PackedStringArray = []) -> PackedStringArray:
	var found: PackedStringArray = _collect(root, extensions, skipped)
	found.sort()
	return found


static func _collect(dir_path: String, extensions: PackedStringArray, skipped: PackedStringArray) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		var sub_path: String = dir_path.path_join(sub)
		if not skipped.has(sub_path) and not sub.begins_with("."):
			found.append_array(_collect(sub_path, extensions, skipped))
	for file: String in dir.get_files():
		if extensions.has(file.get_extension()):
			found.append(dir_path.path_join(file))
	return found


# --- Colours -------------------------------------------------------------------------------------

static func rgb_key(color: Color) -> int:
	return (color.r8 << 16) | (color.g8 << 8) | color.b8


static func key_color(key: int) -> Color:
	return Color8((key >> 16) & 0xff, (key >> 8) & 0xff, key & 0xff)


static func hex(color: Color) -> String:
	return "#" + color.to_html(false)


static func palette_from_colors(colors: PackedColorArray) -> Dictionary:
	var palette: Dictionary = {}
	for color: Color in colors:
		palette[rgb_key(color)] = true
	return palette


## Every colour of an opaque texel of `image` (a palette strip or a ramp sheet).
static func palette_from_image(image: Image) -> Dictionary:
	var palette: Dictionary = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a8 > 0:
				palette[rgb_key(color)] = true
	return palette


## The palette colour with the lowest relative luminance.
static func darkest(palette: Dictionary) -> Color:
	var best: Color = Color.WHITE
	var best_luminance: float = INF
	for key: int in palette:
		var color: Color = key_color(key)
		var lum: float = luminance(color)
		if lum < best_luminance:
			best_luminance = lum
			best = color
	return best


## WCAG relative luminance of an sRGB colour.
static func luminance(color: Color) -> float:
	return 0.2126 * _linear(color.r) + 0.7152 * _linear(color.g) + 0.0722 * _linear(color.b)


static func _linear(channel: float) -> float:
	return channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4)


## WCAG contrast ratio, at least 1.0, the same whichever colour comes first.
static func contrast_ratio(a: Color, b: Color) -> float:
	var la: float = luminance(a)
	var lb: float = luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


# --- Licences ------------------------------------------------------------------------------------

## The blocks of a License.txt: each starts at a line beginning "Pack:" or "Work:" and holds the
## "Key: value" lines up to the next block. Vendor text above the first block is ignored, and a
## block's keys come only from its own lines (design.md K11).
static func licence_blocks(text: String) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var current: Dictionary = {}
	var key_line: RegEx = RegEx.create_from_string("^([A-Z][A-Za-z]*):(?:\\s+(.*))?$")
	for raw: String in text.split("\n"):
		var found: RegExMatch = key_line.search(raw.strip_edges(false, true))
		if found == null:
			continue
		var key: String = found.get_string(1)
		var value: String = found.get_string(2).strip_edges()
		if key == "Pack" or key == "Work":
			current = {"kind": key}
			blocks.append(current)
		if not current.is_empty() and not current.has(key):
			current[key] = value
	return blocks


## The licence rule on every folder under `root` that holds a PNG.
static func check_licence_folders(root: String) -> PackedStringArray:
	var failures: PackedStringArray = []
	var folders: PackedStringArray = []
	for png: String in pngs_under(root):
		var folder: String = png.get_base_dir()
		if not folders.has(folder):
			folders.append(folder)
	for folder: String in folders:
		var licence_path: String = folder.path_join(LICENCE_FILE)
		if not FileAccess.file_exists(licence_path):
			failures.append("%s holds a PNG and has no %s" % [folder, LICENCE_FILE])
			continue
		failures.append_array(check_licence_text(folder, FileAccess.get_file_as_string(licence_path)))
	return failures


static func check_licence_text(folder: String, text: String) -> PackedStringArray:
	var failures: PackedStringArray = []
	var blocks: Array[Dictionary] = licence_blocks(text)
	if blocks.is_empty():
		failures.append("%s/%s has no block starting with a Pack: or Work: line" % [folder, LICENCE_FILE])
	for block: Dictionary in blocks:
		var problem: String = _block_problem(block)
		if not problem.is_empty():
			failures.append("%s/%s: %s '%s' %s" % [folder, LICENCE_FILE, block["kind"], block[block["kind"]], problem])
	return failures


static func _block_problem(block: Dictionary) -> String:
	if String(block.get("Licence", block.get("License", ""))).is_empty():
		return "has no Licence: line"
	var source: String = block.get("Source", "")
	if source.is_empty():
		return "has no Source: line of its own"
	if block["kind"] == "Work":
		return "" if source == OWN_WORK_SOURCE else "gives '%s' as its source, not %s" % [source, OWN_WORK_SOURCE]
	if String(block.get("Author", "")).is_empty():
		return "has no Author: line"
	if not (source.begins_with("https://") or source.begins_with("http://")):
		return "gives '%s' as its source, not the pack's page" % source
	if is_licence_deed(source):
		return "gives the licence deed %s as its source, not the pack's page" % source
	return ""


static func is_licence_deed(url: String) -> bool:
	var host: String = url.get_slice("://", 1).get_slice("/", 0).to_lower()
	for licence_host: String in LICENCE_HOSTS:
		if host == licence_host or host.ends_with("." + licence_host):
			return true
	return false


## Every PNG in `pngs` is named by a scene or resource under `referrer_roots`.
static func check_referred(pngs: PackedStringArray, referrer_roots: PackedStringArray, skipped: PackedStringArray = []) -> PackedStringArray:
	var referrers: String = ""
	for root: String in referrer_roots:
		for path: String in files_under(root, REFERRER_EXTENSIONS, skipped):
			referrers += FileAccess.get_file_as_string(path)
	var failures: PackedStringArray = []
	for png: String in pngs:
		if not referrers.contains('"%s"' % png):
			failures.append("%s is referred to by no scene or resource" % png)
	return failures


# --- Palette and alpha ---------------------------------------------------------------------------

## Every texel with any alpha is a palette colour.
static func check_palette(path: String, image: Image, palette: Dictionary) -> PackedStringArray:
	var offenders: PackedStringArray = []
	var count: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a8 > 0 and not palette.has(rgb_key(color)):
				count += 1
				if offenders.size() < MAX_LISTED:
					offenders.append("(%d, %d) %s" % [x, y, hex(color)])
	return _pixel_failure(path, "pixel(s) not in the master palette", offenders, count)


## Each texel is fully opaque or fully transparent, except under shadows/ and decals/, where a
## partly transparent texel is the palette's darkest colour.
static func check_alpha(path: String, image: Image, palette: Dictionary) -> PackedStringArray:
	var allowed: bool = _allows_partial_alpha(path)
	var shadow_key: int = rgb_key(darkest(palette))
	var offenders: PackedStringArray = []
	var count: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a8 == 0 or color.a8 == 255:
				continue
			if allowed and rgb_key(color) == shadow_key:
				continue
			count += 1
			if offenders.size() < MAX_LISTED:
				offenders.append("(%d, %d) alpha %d %s" % [x, y, color.a8, hex(color)])
	var rule: String = "partly transparent pixel(s) outside shadows/ and decals/"
	if allowed:
		rule = "partly transparent pixel(s) not in the darkest colour %s" % hex(key_color(shadow_key))
	return _pixel_failure(path, rule, offenders, count)


static func _allows_partial_alpha(path: String) -> bool:
	for dir: String in PARTIAL_ALPHA_DIRS:
		if path.contains("/%s/" % dir):
			return true
	return false


static func _pixel_failure(path: String, rule: String, offenders: PackedStringArray, count: int) -> PackedStringArray:
	if count == 0:
		return PackedStringArray()
	return PackedStringArray(["%s: %d %s: %s" % [path, count, rule, ", ".join(offenders)]])


# --- Outline -------------------------------------------------------------------------------------

## In every `cell`-sized frame cell, each opaque texel with a transparent 4-neighbour (or one
## outside its cell) is an outline colour.
static func check_outline(path: String, image: Image, outline: Dictionary, cell: Vector2i) -> PackedStringArray:
	var offenders: PackedStringArray = []
	var count: int = 0
	for cell_y: int in image.get_height() / cell.y:
		for cell_x: int in image.get_width() / cell.x:
			var rect: Rect2i = Rect2i(Vector2i(cell_x, cell_y) * cell, cell)
			for pixel: Vector2i in edge_pixels(image, rect):
				var color: Color = image.get_pixelv(pixel)
				if outline.has(rgb_key(color)):
					continue
				count += 1
				if offenders.size() < MAX_LISTED:
					offenders.append("cell (%d, %d) pixel (%d, %d) %s" % [cell_x, cell_y, pixel.x, pixel.y, hex(color)])
	return _pixel_failure(path, "edge pixel(s) not in the outline set", offenders, count)


## The opaque texels of `rect` with a transparent 4-neighbour or one outside `rect`.
static func edge_pixels(image: Image, rect: Rect2i) -> Array[Vector2i]:
	var edges: Array[Vector2i] = []
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var pixel: Vector2i = Vector2i(x, y)
			if image.get_pixelv(pixel).a8 > 0 and _is_open(image, rect, pixel):
				edges.append(pixel)
	return edges


static func _is_open(image: Image, rect: Rect2i, pixel: Vector2i) -> bool:
	for step: Vector2i in NEIGHBOURS:
		var next: Vector2i = pixel + step
		if not rect.has_point(next) or image.get_pixelv(next).a8 == 0:
			return true
	return false


# --- Import --------------------------------------------------------------------------------------

## The PNG imports lossless (compress/mode 0) and without mipmaps.
static func check_import(png: String) -> PackedStringArray:
	var config: ConfigFile = ConfigFile.new()
	if config.load(png + ".import") != OK:
		return PackedStringArray(["%s has no readable .import" % png])
	var failures: PackedStringArray = []
	var mode: int = int(config.get_value("params", "compress/mode", -1))
	if mode != 0:
		failures.append("%s imports with compress/mode=%d, not 0 (lossless)" % [png, mode])
	if bool(config.get_value("params", "mipmaps/generate", true)):
		failures.append("%s imports with mipmaps/generate=true" % png)
	return failures


# --- Contrast ------------------------------------------------------------------------------------

## Every outline colour reaches `minimum` against each land ground's mean colour.
static func check_outline_contrast(outline: PackedColorArray, grounds: Dictionary[StringName, Color], minimum: float) -> PackedStringArray:
	var failures: PackedStringArray = []
	for color: Color in outline:
		for ground: StringName in grounds:
			var ratio: float = contrast_ratio(color, grounds[ground])
			if ratio < minimum:
				failures.append("outline colour %s reaches %.2f:1 against the %s ground (%s), under %.1f:1" % [hex(color), ratio, ground, hex(grounds[ground]), minimum])
	return failures


## The better contrast against `ground` of the frame's outline ring (its edge texels' mean
## colour) and of its mean colour, over the opaque texels of `rect`.
static func water_contrast(image: Image, rect: Rect2i, ground: Color) -> float:
	var body: Array[Vector2i] = []
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if image.get_pixel(x, y).a8 > 0:
				body.append(Vector2i(x, y))
	if body.is_empty():
		return 1.0
	var ring: Array[Vector2i] = edge_pixels(image, rect)
	return maxf(contrast_ratio(mean_color(image, ring), ground), contrast_ratio(mean_color(image, body), ground))


static func mean_color(image: Image, pixels: Array[Vector2i]) -> Color:
	var sum: Vector3 = Vector3.ZERO
	for pixel: Vector2i in pixels:
		var color: Color = image.get_pixelv(pixel)
		sum += Vector3(color.r, color.g, color.b)
	sum /= maxf(1.0, float(pixels.size()))
	return Color(sum.x, sum.y, sum.z)


static func check_water_contrast(frame: String, image: Image, rect: Rect2i, grounds: Dictionary[StringName, Color], minimum: float) -> PackedStringArray:
	var failures: PackedStringArray = []
	for ground: StringName in grounds:
		var ratio: float = water_contrast(image, rect, grounds[ground])
		if ratio < minimum:
			failures.append("%s %s reaches %.2f:1 against the %s ground (%s) by the better of its outline ring and mean colour, under %.1f:1" % [frame, rect, ratio, ground, hex(grounds[ground]), minimum])
	return failures


# --- Land tiles ----------------------------------------------------------------------------------

## No opaque texel of a land tile is a sea or foam ramp colour.
static func check_no_water(path: String, image: Image, water: Dictionary) -> PackedStringArray:
	var offenders: PackedStringArray = []
	var count: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a8 > 0 and water.has(rgb_key(color)):
				count += 1
				if offenders.size() < MAX_LISTED:
					offenders.append("(%d, %d) %s" % [x, y, hex(color)])
	return _pixel_failure(path, "sea or foam pixel(s) in a land tile", offenders, count)


# --- Frame budget --------------------------------------------------------------------------------

static func unique_frames(frames: SpriteFrames, animation: StringName) -> int:
	var seen: Dictionary = {}
	for index: int in frames.get_frame_count(animation):
		var key: String = _texture_key(frames.get_frame_texture(animation, index))
		if not key.is_empty():
			seen[key] = true
	return seen.size()


static func total_unique_frames(frames: SpriteFrames) -> int:
	var seen: Dictionary = {}
	for animation: StringName in frames.get_animation_names():
		for index: int in frames.get_frame_count(animation):
			var key: String = _texture_key(frames.get_frame_texture(animation, index))
			if not key.is_empty():
				seen[key] = true
	return seen.size()


## Every animation of `frames` has at most `max_unique` unique frames and plays at `max_fps` or
## slower; a failure names `owner_name` and the animation.
static func check_frame_budget(owner_name: String, frames: SpriteFrames, max_unique: int, max_fps: float) -> PackedStringArray:
	var failures: PackedStringArray = []
	for animation: StringName in frames.get_animation_names():
		var count: int = unique_frames(frames, animation)
		if count > max_unique:
			failures.append("%s: animation '%s' has %d unique frames, over %d" % [owner_name, animation, count, max_unique])
		var fps: float = frames.get_animation_speed(animation)
		if fps > max_fps:
			failures.append("%s: animation '%s' plays at %s fps, over %s" % [owner_name, animation, fps, max_fps])
	return failures


static func check_total_frames(owner_name: String, frames: SpriteFrames, max_total: int) -> PackedStringArray:
	var count: int = total_unique_frames(frames)
	if count <= max_total:
		return PackedStringArray()
	return PackedStringArray(["%s has %d unique frames in all, over %d" % [owner_name, count, max_total]])


## The number of distinct non-empty `cell`-sized cells of a sheet.
static func unique_cells(image: Image, cell: Vector2i) -> int:
	var seen: Dictionary = {}
	for cell_y: int in image.get_height() / cell.y:
		for cell_x: int in image.get_width() / cell.x:
			var key: String = _image_key(image.get_region(Rect2i(Vector2i(cell_x, cell_y) * cell, cell)))
			if not key.is_empty():
				seen[key] = true
	return seen.size()


static func _texture_key(texture: Texture2D) -> String:
	if texture == null:
		return ""
	var image: Image = texture.get_image()
	if image == null:
		return ""
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return _image_key(image)


## The texels as hex, with fully transparent texels cleared; "" for an empty image.
static func _image_key(image: Image) -> String:
	var data: PackedByteArray = image.get_data()
	var opaque: bool = false
	for index: int in range(3, data.size(), 4):
		if data[index] == 0:
			data[index - 3] = 0
			data[index - 2] = 0
			data[index - 1] = 0
		else:
			opaque = true
	if not opaque:
		return ""
	return "%dx%d:%s" % [image.get_width(), image.get_height(), data.hex_encode()]


# --- Silhouettes ---------------------------------------------------------------------------------

## No two icons share one alpha mask; a failure names both.
static func check_silhouettes(icons: Dictionary[String, Image]) -> PackedStringArray:
	var failures: PackedStringArray = []
	var owners: Dictionary = {}
	var names: Array[String] = []
	names.assign(icons.keys())
	names.sort()
	for icon_name: String in names:
		var mask: String = _mask_key(icons[icon_name])
		if owners.has(mask):
			failures.append("%s and %s share one silhouette" % [owners[mask], icon_name])
		else:
			owners[mask] = icon_name
	return failures


static func _mask_key(image: Image) -> String:
	var bits: PackedByteArray = []
	for y: int in image.get_height():
		for x: int in image.get_width():
			bits.append(1 if image.get_pixel(x, y).a8 > 0 else 0)
	return "%dx%d:%s" % [image.get_width(), image.get_height(), bits.hex_encode()]


# --- Item icons ----------------------------------------------------------------------------------

## An item's icon (art-pass "Item icons"; design.md D17, D21).
const ICON_SIZE: Vector2i = Vector2i(16, 16)
## The box one pixel in from each edge of the icon that the item stays inside.
const ICON_BOX: Rect2i = Rect2i(1, 1, 14, 14)


## The item file at `path` has a 16x16 icon, its opaque texels inside ICON_BOX and its edge in
## `outline` colours; each failure names the file.
static func check_item_icon(path: String, item: ItemData, outline: Dictionary) -> PackedStringArray:
	if item == null:
		return PackedStringArray(["%s is not an item" % path])
	if item.sprite == null:
		return PackedStringArray(["%s has no icon" % path])
	var image: Image = read_png(item.sprite.resource_path)
	if image == null:
		return PackedStringArray(["%s: its icon %s is not a readable PNG" % [path, item.sprite.resource_path]])
	if image.get_size() != ICON_SIZE:
		return PackedStringArray(["%s: its icon is %s, not 16x16" % [path, image.get_size()]])
	var used: Rect2i = image.get_used_rect()
	if used.size == Vector2i.ZERO:
		return PackedStringArray(["%s: its icon is empty" % path])
	var failures: PackedStringArray = []
	if not ICON_BOX.encloses(used):
		failures.append("%s: its icon spans %s, outside the 14x14 box %s" % [path, used, ICON_BOX])
	failures.append_array(check_outline("%s icon" % path, image, outline, ICON_SIZE))
	return failures
