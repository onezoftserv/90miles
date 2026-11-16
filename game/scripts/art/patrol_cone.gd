class_name PatrolCone
extends RefCounted
## guardacostas-stealth decision 11: the searchlight's cone as a light texture, generated once per
## (width, length) from the boat's data: a sector of `range_tiles` tiles (16 px each) and `cone_deg`
## degrees, its apex at the left edge of the image and its axis along +x, so a PointLight2D with
## `offset = (width / 2, 0)` rotated to the beam lights exactly the cells the Searchlight lights. The
## light is brightest at the boat and fades a little toward the far edge, with a soft rim. Pure
## drawing: it never reads or writes the simulation.

const TILE: float = 16.0
## How much of its full strength the light still has at its far edge.
const FAR_STRENGTH: float = 0.6
const NEAR_STRENGTH: float = 0.9
## The rim's softness in degrees and pixels.
const RIM_DEG: float = 2.5
const RIM_PX: float = 4.0

static var _cache: Dictionary[String, ImageTexture] = {}


## The cone texture for a `cone_deg` wide, `range_tiles` long beam (built on first use).
static func texture(cone_deg: float, range_tiles: float) -> ImageTexture:
	var key: String = "%f|%f" % [cone_deg, range_tiles]
	if not _cache.has(key):
		_cache[key] = _build(cone_deg, range_tiles)
	return _cache[key]


## Pixels the texture is long: the range in pixels.
static func length_px(range_tiles: float) -> int:
	return maxi(ceili(range_tiles * TILE), 1)


## Pixels across the texture: the cone's widest reach either side of its axis, doubled, plus a pixel
## so the axis has a centre row.
static func height_px(cone_deg: float, range_tiles: float) -> int:
	var half: float = deg_to_rad(minf(cone_deg, 180.0) / 2.0)
	var reach: float = range_tiles * TILE * (1.0 if half >= PI / 2.0 else sin(half))
	return maxi(ceili(reach) * 2 + 2, 2)


static func _build(cone_deg: float, range_tiles: float) -> ImageTexture:
	var length: int = length_px(range_tiles)
	var height: int = height_px(cone_deg, range_tiles)
	var radius: float = range_tiles * TILE
	var half_cone: float = cone_deg / 2.0
	var image := Image.create(length, height, false, Image.FORMAT_RGBA8)
	var centre_y: float = height / 2.0
	for y: int in height:
		for x: int in length:
			var gap := Vector2(x + 0.5, y + 0.5 - centre_y)
			var distance: float = gap.length()
			if distance > radius:
				continue
			var off: float = absf(rad_to_deg(gap.angle()))
			var angle_edge: float = clampf((half_cone - off) / RIM_DEG, 0.0, 1.0)
			var range_edge: float = clampf((radius - distance) / RIM_PX, 0.0, 1.0)
			var strength: float = lerpf(NEAR_STRENGTH, FAR_STRENGTH, distance / radius) * angle_edge * range_edge
			image.set_pixel(x, y, Color(strength, strength, strength, 1.0))
	return ImageTexture.create_from_image(image)
