class_name LookComposer
extends RefCounted
## Builds a player's look from its parts at load time (art-pass "Layered player look", "Four slots,
## four looks"; design.md C1, C2, D20): the body sheet swapped from skin row 0 to the look's row,
## then the outfit, the hair and the item blended over it back to front, wrapped in one texture
## that a copy of the template balsero_frames.tres points every region at. The clothing stays in
## the key ramp: the slot colour is the shader's. A missing part is drawn with the default look's
## part for that layer, with a warning, and listed in `fallbacks`. Head anchors are measured on
## the composite per pose family: 1 px above its topmost opaque row, after the swim drop.
## Composed once per catalog root and look (`cache_key()`), kept for the session; no autoload.

const DEFAULT_ROOT: String = "res://assets/art/characters"
const PARTS: StringName = &"parts"
## The pose families measured on the composite; the dive's anchor is BodyArt's.
const FAMILIES: Array[StringName] = [&"walk", &"crouch", &"swim", &"downed", &"dead"]

# Catalog folder + "|" + cache_key() -> its composed look.
static var _cache: Dictionary[String, ComposedLook] = {}


## The composed `look`, from the parts in `catalog` (null: the shipped parts).
static func compose(look: PlayerLookData, catalog: ContentCatalog = null) -> ComposedLook:
	if catalog == null:
		catalog = ContentCatalog.new(DEFAULT_ROOT, {PARTS: LookPart})
	var art: BodyArt = BodyArt.standard()
	if look == null:
		look = art.default_look
	var key: String = "%s|%s" % [catalog.folder_path(PARTS), look.cache_key()]
	if _cache.has(key):
		return _cache[key]
	var composed := ComposedLook.new()
	var fallback: PlayerLookData = art.default_look
	var image: Image = null
	var body: LookPart = _part(catalog, look.body_id, fallback.body_id, composed)
	if body != null:
		var skin: Image = ArtTuning.standard().skin_ramps.get_image()
		image = PaletteSwap.swap_rows(_sheet(body), skin, 0, look.skin_row)
	else:
		image = Image.create_empty(LookPart.SHEET_SIZE.x, LookPart.SHEET_SIZE.y, false, Image.FORMAT_RGBA8)
	var layers: Array[StringName] = [look.outfit_id, look.hair_id, look.item_id]
	var defaults: Array[StringName] = [fallback.outfit_id, fallback.hair_id, fallback.item_id]
	for i: int in layers.size():
		if layers[i] == &"" and defaults[i] == &"":
			continue
		var part: LookPart = _part(catalog, layers[i], defaults[i], composed)
		if part == null:
			continue
		var sheet: Image = _sheet(part)
		image.blend_rect(sheet, Rect2i(Vector2i.ZERO, sheet.get_size()), Vector2i.ZERO)
	composed.image = image
	composed.texture = ImageTexture.create_from_image(image)
	composed.frames = _frames(art.frames, composed.texture)
	_measure(composed, art)
	_cache[key] = composed
	return composed


## Test only: forgets every composed look, so fixture parts reusing shipped ids compose fresh.
static func clear_cache() -> void:
	_cache.clear()


# The part `id` names, or the default look's part for that layer (reported), or null.
static func _part(catalog: ContentCatalog, id: StringName, default_id: StringName, composed: ComposedLook) -> LookPart:
	if id != &"" and catalog.has_entry(PARTS, id):
		var found := catalog.get_entry(PARTS, id) as LookPart
		if found != null and found.sheet != null:
			return found
	var line: String = "part %s is missing; drawn with %s" % [id, default_id]
	push_warning("LookComposer: " + line)
	composed.fallbacks.append(line)
	if default_id != &"" and catalog.has_entry(PARTS, default_id):
		return catalog.get_entry(PARTS, default_id) as LookPart
	return null


static func _sheet(part: LookPart) -> Image:
	var image: Image = part.sheet.get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


# A copy of the template with every AtlasTexture region on `texture`.
static func _frames(template: SpriteFrames, texture: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for name: StringName in frames.get_animation_names():
		frames.remove_animation(name)
	for name: StringName in template.get_animation_names():
		frames.add_animation(name)
		frames.set_animation_speed(name, template.get_animation_speed(name))
		frames.set_animation_loop(name, template.get_animation_loop(name))
		for index: int in template.get_frame_count(name):
			var source := template.get_frame_texture(name, index) as AtlasTexture
			var region := AtlasTexture.new()
			region.atlas = texture
			region.region = source.region if source != null else Rect2()
			frames.add_frame(name, region, template.get_frame_duration(name, index))
	return frames


# Head anchors: per family, 1 px (the head gap) above the topmost opaque row over its cells, in
# body-local px after the swim drop; the dive's is BodyArt's.
static func _measure(composed: ComposedLook, art: BodyArt) -> void:
	var frame_top: int = art.feet_y - art.feet_row - 1
	for family: StringName in FAMILIES:
		var top: int = LookPart.CELL.y
		for cell: Vector2i in LookPart.pose_cells(family):
			var used: Rect2i = composed.image.get_region(Rect2i(cell * LookPart.CELL, LookPart.CELL)).get_used_rect()
			if used.has_area():
				top = mini(top, used.position.y)
		var drop: int = art.swim_drop_px if family == &"swim" else 0
		composed.set_head_anchor(family, top + frame_top + drop - art.head_gap_px)
	composed.set_head_anchor(&"dive", art.dive_anchor_y)
