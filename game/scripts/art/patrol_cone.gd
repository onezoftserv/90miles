class_name PatrolCone
extends RefCounted
## guardacostas-stealth decision 11: the searchlight's cone as a light texture, generated once per
## (width, length) from the boat's data: a sector of `range_tiles` tiles (16 px each) and `cone_deg`
## degrees, its apex at the left edge of the image and its axis along +x, so a PointLight2D with
## `offset = (width / 2, 0)` rotated to the beam lights exactly the cells the Searchlight lights. The
## light is brightest at the boat and fades a little toward the far edge. art-guardacostas D4: its rim
## is soft and centred on the true edge (a smoothstep RIM_DEG wide across the cone's side and RIM_PX
## across its far end), so a point the Searchlight lights is drawn at half its strength or more and
## nothing beyond the rim's outer half is drawn at all; the texture grows by that outer half. Pure
## drawing: it never reads or writes the simulation.

const TILE: float = 16.0
## How much of its full strength the light still has at its far edge.
const FAR_STRENGTH: float = 0.6
const NEAR_STRENGTH: float = 0.9
## The rim's width in degrees and pixels, centred on the true edge.
const RIM_DEG: float = 8.0
const RIM_PX: float = 12.0

static var _cache: Dictionary[String, ImageTexture] = {}


## The cone texture for a `cone_deg` wide, `range_tiles` long beam (built on first use).
static func texture(cone_deg: float, range_tiles: float) -> ImageTexture:
	var key: String = "%f|%f" % [cone_deg, range_tiles]
	if not _cache.has(key):
		_cache[key] = _build(cone_deg, range_tiles)
	return _cache[key]


## Pixels the texture is long: the range in pixels and the rim's outer half.
static func length_px(range_tiles: float) -> int:
	return maxi(ceili(range_tiles * TILE + RIM_PX / 2.0), 1)


## Pixels across the texture: the reach of the cone and its rim's outer half either side of its axis,
## doubled, plus a pixel so the axis has a centre row.
static func height_px(cone_deg: float, range_tiles: float) -> int:
	var half: float = deg_to_rad(minf(cone_deg + RIM_DEG, 180.0) / 2.0)
	var reach: float = (range_tiles * TILE + RIM_PX / 2.0) * (1.0 if half >= PI / 2.0 else sin(half))
	return maxi(ceili(reach) * 2 + 2, 2)


## How strong the light is drawn at `gap` pixels from the apex (along +x) of a `cone_deg` wide beam
## `radius` pixels long: the near-to-far fade times the lower of the side and far rims, each a smoothstep
## centred on the true edge (the lower, not the product, so a corner of the wedge is at half too).
static func strength_at(gap: Vector2, cone_deg: float, radius: float) -> float:
	var distance: float = gap.length()
	var off: float = absf(rad_to_deg(gap.angle())) if distance > 0.0 else 0.0
	var angle_edge: float = smoothstep(-RIM_DEG / 2.0, RIM_DEG / 2.0, cone_deg / 2.0 - off)
	var range_edge: float = smoothstep(-RIM_PX / 2.0, RIM_PX / 2.0, radius - distance)
	return fade_at(distance, radius) * minf(angle_edge, range_edge)


## The near-to-far fade alone at `distance` pixels of a `radius` pixel beam.
static func fade_at(distance: float, radius: float) -> float:
	return lerpf(NEAR_STRENGTH, FAR_STRENGTH, clampf(distance / radius, 0.0, 1.0))


static func _build(cone_deg: float, range_tiles: float) -> ImageTexture:
	var length: int = length_px(range_tiles)
	var height: int = height_px(cone_deg, range_tiles)
	var radius: float = range_tiles * TILE
	var image := Image.create(length, height, false, Image.FORMAT_RGBA8)
	var centre_y: float = height / 2.0
	for y: int in height:
		for x: int in length:
			var strength: float = strength_at(Vector2(x + 0.5, y + 0.5 - centre_y), cone_deg, radius)
			if strength <= 0.0:
				continue
			image.set_pixel(x, y, Color(strength, strength, strength, 1.0))
	return ImageTexture.create_from_image(image)
