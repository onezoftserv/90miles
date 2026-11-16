class_name SeaMask
extends RefCounted
## Pure, static: the per-cell data the sea and foam shaders read, as plain bytes in row-major
## order, one per cell of the island's grid (design.md D12, D13, K40). No node and no shader here.

## The soft deep edge (art-coast-pass D6): the depth mask's two channels are blurred with one
## separable Gaussian of this many cells, over this many cells each side, clamped at the grid's edge.
const SOFT_SIGMA_CELLS: float = 1.0
const SOFT_RADIUS_CELLS: int = 3
## After the blur each texel goes back to its own side of the cut: a deep texel's shallowness at
## most 0.45, any other's at least 0.55, and the same for brackishness (in bytes, 114 and 141).
const SOFT_LOW: float = 0.45
const SOFT_HIGH: float = 0.55
## How far a cell's centre, sampled where the sea shader samples it, must stay from the cut.
const SOFT_MARGIN: float = 0.02
## The sea shader's static warp of the point where it samples the mask: value noise on a lattice
## of this period, up to this many px on each axis. world_sea.gdshader holds the same numbers
## (`warp_px`, `warp_period_px`) and the same lattice hash (`sea_lattice`).
const WARP_PX: float = 4.0
const WARP_PERIOD_PX: float = 48.0
const MASK_32: int = 0xffffffff


## The depth step of every cell (deep, shallows or brackish from the art data). A land cell holds
## the commonest step among its water neighbours, the least step on a tie, so the sea that shows
## through a shore cell's transparent side matches the water beside it; one with no water near
## holds the data's `land_step`.
static func depth_bytes(size: Vector2i, terrain: GridTerrain) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size.x * size.y)
	for y: int in size.y:
		for x: int in size.x:
			bytes[y * size.x + x] = _step_at(Vector2i(x, y), terrain)
	return bytes


## The foam phase of every cell: a shore cell's offset 0 to 7, 0 elsewhere. A caller that has the
## shore cells already passes them as `shore`; with none passed they are found here.
static func phase_bytes(layout_id: StringName, size: Vector2i, terrain: GridTerrain, pools: Array[Vector2i], shore: Array[Vector2i] = []) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size.x * size.y)
	var cells: Array[Vector2i] = shore if not shore.is_empty() else ShoreRule.shore_cells(terrain, pools)
	for cell: Vector2i in cells:
		if cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y:
			bytes[cell.y * size.x + cell.x] = ShoreRule.phase(layout_id, cell)
	return bytes


## A one-channel image of `bytes`, each value scaled so `max_value` is white: the texture a shader
## samples, one texel per cell.
static func to_image(bytes: PackedByteArray, size: Vector2i, max_value: int) -> Image:
	var scaled: PackedByteArray = bytes.duplicate()
	for index: int in scaled.size():
		@warning_ignore("integer_division")
		scaled[index] = bytes[index] * 255 / max_value
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_R8, scaled)


## The sea shader's depth mask for `depth_bytes` (one step per cell, `size` columns and rows of
## `cell_px` each), as RG8 bytes: r the shallowness, g the brackishness, blurred so the steps meet
## in a curve instead of along cell borders, then clamped back to each cell's own side of the cut.
## Last, every cell is checked where the shader samples its centre (after the static warp); a cell
## that would show another step there takes its unblurred value, which always holds (its own
## texel weighs at least 0.56 a quarter cell away). g never rises above r, so no shallows band
## appears between brackish and deep water. A grid of one step is not blurred at all.
static func soft_channels(depth_bytes: PackedByteArray, size: Vector2i, cell_px: float) -> PackedByteArray:
	var art: TerrainArtData = TerrainArt.data()
	var deep: int = art.depth_steps[DataEnums.Terrain.DEEP]
	var brackish: int = art.depth_steps[DataEnums.Terrain.BRACKISH]
	var count: int = size.x * size.y
	var wanted_r: PackedFloat32Array = PackedFloat32Array()
	var wanted_g: PackedFloat32Array = PackedFloat32Array()
	wanted_r.resize(count)
	wanted_g.resize(count)
	var uniform: bool = true
	for index: int in count:
		wanted_r[index] = 0.0 if depth_bytes[index] == deep else 1.0
		wanted_g[index] = 1.0 if depth_bytes[index] == brackish else 0.0
		uniform = uniform and depth_bytes[index] == depth_bytes[0]
	var channels: PackedByteArray = PackedByteArray()
	channels.resize(count * 2)
	if uniform:
		for index: int in count:
			channels[index * 2] = roundi(wanted_r[index] * 255.0)
			channels[index * 2 + 1] = roundi(wanted_g[index] * 255.0)
		return channels
	var soft_r: PackedFloat32Array = _blurred(wanted_r, size)
	var soft_g: PackedFloat32Array = _blurred(wanted_g, size)
	var low: int = floori(SOFT_LOW * 255.0)
	var high: int = ceili(SOFT_HIGH * 255.0)
	for index: int in count:
		var r: int = roundi(soft_r[index] * 255.0)
		var g: int = roundi(soft_g[index] * 255.0)
		r = mini(r, low) if wanted_r[index] < 0.5 else maxi(r, high)
		g = maxi(g, high) if wanted_g[index] > 0.5 else mini(g, low)
		channels[index * 2] = r
		channels[index * 2 + 1] = mini(g, r)
	var centres: Array[Vector2] = []
	for y: int in size.y:
		for x: int in size.x:
			var centre: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * cell_px
			centres.append(centre + warp_offset(centre))
	var settled: bool = false
	while not settled:
		settled = true
		for index: int in count:
			var seen: Vector2 = sample(channels, size, cell_px, centres[index])
			var r_holds: bool = seen.x >= 0.5 + SOFT_MARGIN if wanted_r[index] > 0.5 else seen.x <= 0.5 - SOFT_MARGIN
			var g_holds: bool = seen.y >= 0.5 + SOFT_MARGIN if wanted_g[index] > 0.5 else seen.y <= 0.5 - SOFT_MARGIN
			var whole: bool = channels[index * 2] == roundi(wanted_r[index] * 255.0) and channels[index * 2 + 1] == roundi(wanted_g[index] * 255.0)
			if not (r_holds and g_holds) and not whole:
				channels[index * 2] = roundi(wanted_r[index] * 255.0)
				channels[index * 2 + 1] = roundi(wanted_g[index] * 255.0)
				settled = false
	return channels


## The mask's r and g at `px` (in the sea's own px) as the shader's linear filter reads it: texel
## centres at the cells' centres, clamped at the grid's edge.
static func sample(channels: PackedByteArray, size: Vector2i, cell_px: float, px: Vector2) -> Vector2:
	var at: Vector2 = px / cell_px - Vector2(0.5, 0.5)
	var base: Vector2 = at.floor()
	var part: Vector2 = at - base
	var x0: int = clampi(int(base.x), 0, size.x - 1)
	var y0: int = clampi(int(base.y), 0, size.y - 1)
	var x1: int = clampi(int(base.x) + 1, 0, size.x - 1)
	var y1: int = clampi(int(base.y) + 1, 0, size.y - 1)
	var result: Vector2 = Vector2.ZERO
	for channel: int in 2:
		var top: float = lerpf(channels[(y0 * size.x + x0) * 2 + channel], channels[(y0 * size.x + x1) * 2 + channel], part.x)
		var bottom: float = lerpf(channels[(y1 * size.x + x0) * 2 + channel], channels[(y1 * size.x + x1) * 2 + channel], part.x)
		result[channel] = lerpf(top, bottom, part.y) / 255.0
	return result


## The sea shader's static warp at `px`: two channels of smoothstep value noise on a lattice of
## WARP_PERIOD_PX, each from -WARP_PX to WARP_PX. Mirrors `sea_warp` in world_sea.gdshader.
static func warp_offset(px: Vector2) -> Vector2:
	var at: Vector2 = px / WARP_PERIOD_PX
	return Vector2(_value_noise(at, 0), _value_noise(at, 1)) * WARP_PX


## The lattice value of `cell` for `channel`, from -1 to 1: murmur3's finaliser chained over the
## channel, the row and the column, all as 32-bit words. Mirrors `sea_lattice` in the shader.
static func lattice(cell: Vector2i, channel: int) -> float:
	var mixed: int = TerrainArt.mix32((cell.x & MASK_32) ^ TerrainArt.mix32((cell.y & MASK_32) ^ TerrainArt.mix32(channel)))
	return float(mixed & 0xffff) / 65535.0 * 2.0 - 1.0


static func _value_noise(at: Vector2, channel: int) -> float:
	var cell: Vector2i = Vector2i(floori(at.x), floori(at.y))
	var part: Vector2 = at - Vector2(cell)
	var ease: Vector2 = part * part * (Vector2(3.0, 3.0) - 2.0 * part)
	var top: float = lerpf(lattice(cell, channel), lattice(cell + Vector2i(1, 0), channel), ease.x)
	var bottom: float = lerpf(lattice(cell + Vector2i(0, 1), channel), lattice(cell + Vector2i(1, 1), channel), ease.x)
	return lerpf(top, bottom, ease.y)


# One channel blurred along x, then along y, with the edge cells repeated past the grid's edge.
static func _blurred(values: PackedFloat32Array, size: Vector2i) -> PackedFloat32Array:
	var weights: PackedFloat32Array = PackedFloat32Array()
	var total: float = 0.0
	for offset: int in range(-SOFT_RADIUS_CELLS, SOFT_RADIUS_CELLS + 1):
		var weight: float = exp(-float(offset * offset) / (2.0 * SOFT_SIGMA_CELLS * SOFT_SIGMA_CELLS))
		weights.append(weight)
		total += weight
	for index: int in weights.size():
		weights[index] /= total
	var across: PackedFloat32Array = PackedFloat32Array()
	across.resize(values.size())
	for y: int in size.y:
		for x: int in size.x:
			var sum: float = 0.0
			for offset: int in range(-SOFT_RADIUS_CELLS, SOFT_RADIUS_CELLS + 1):
				sum += weights[offset + SOFT_RADIUS_CELLS] * values[y * size.x + clampi(x + offset, 0, size.x - 1)]
			across[y * size.x + x] = sum
	var down: PackedFloat32Array = PackedFloat32Array()
	down.resize(values.size())
	for y: int in size.y:
		for x: int in size.x:
			var sum: float = 0.0
			for offset: int in range(-SOFT_RADIUS_CELLS, SOFT_RADIUS_CELLS + 1):
				sum += weights[offset + SOFT_RADIUS_CELLS] * across[clampi(y + offset, 0, size.y - 1) * size.x + x]
			down[y * size.x + x] = sum
	return down


static func _step_at(cell: Vector2i, terrain: GridTerrain) -> int:
	var own: int = TerrainArt.depth_step(terrain.terrain_at(cell))
	if own >= 0:
		return own
	var counts: Dictionary[int, int] = {}
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var step: int = TerrainArt.depth_step(terrain.terrain_at(cell + Vector2i(dx, dy)))
			if step >= 0:
				counts[step] = counts.get(step, 0) + 1
	var best: int = TerrainArt.data().land_step
	var best_count: int = 0
	for step: int in counts:
		if counts[step] > best_count or (counts[step] == best_count and step < best):
			best = step
			best_count = counts[step]
	return best
