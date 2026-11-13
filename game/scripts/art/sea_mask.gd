class_name SeaMask
extends RefCounted
## Pure, static: the per-cell data the sea and foam shaders read, as plain bytes in row-major
## order, one per cell of the island's grid (design.md D12, D13, K40). No node and no shader here.


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


## The foam phase of every cell: a shore cell's offset 0 to 7, 0 elsewhere.
static func phase_bytes(layout_id: StringName, size: Vector2i, terrain: GridTerrain, pools: Array[Vector2i]) -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size.x * size.y)
	for cell: Vector2i in ShoreRule.shore_cells(terrain, pools):
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
