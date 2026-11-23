class_name FireGlow
extends RefCounted
## art-mood-pass D2 (C33b; owner Q13 (a)): the fire's light as a texture of hard concentric rings, made
## once per radius from data, as `PatrolCone` makes the searchlight's. The image is (2r + 1)² pixels,
## the fire at its centre; it holds one band per value of `values`, from the centre out, each of equal
## width and one value, and nothing beyond r. A PointLight2D draws it at texture_scale 1, so every ring
## stays a hard step (only 1:1 keeps them hard in the 4.7.2 Compatibility renderer). Pure drawing: it
## never reads or writes the simulation.

const TILE: float = 16.0

static var _cache: Dictionary[String, ImageTexture] = {}


## The light's radius in pixels for a fire whose company reaches `company_radius_tiles` tiles, so the
## pool is exactly the reach of the fire's company.
static func radius_px(company_radius_tiles: float) -> int:
	return maxi(roundi(company_radius_tiles * TILE), 1)


## The ring texture of radius `radius` px with `values` bands, the first at the centre (built once).
static func texture(radius: int, values: PackedFloat32Array) -> ImageTexture:
	var key: String = "%d|%s" % [radius, values]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(_build(radius, values))
	return _cache[key]


static func _build(radius: int, values: PackedFloat32Array) -> Image:
	var size: int = 2 * radius + 1
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var steps: int = maxi(values.size(), 1)
	for y: int in size:
		for x: int in size:
			var distance: float = Vector2(x - radius, y - radius).length()
			if distance > radius or values.is_empty():
				continue
			var band: int = mini(int(distance * steps / (radius + 1.0)), steps - 1)
			var value: float = values[band]
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	return image
