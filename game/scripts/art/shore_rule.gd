class_name ShoreRule
extends RefCounted
## Pure, static: which land cells get foam, which foam piece, and the frame each starts at
## (design.md D13, T3, K39, K40). A shore cell is a land cell whose sand corner mask has a water
## corner; a layout's tide-pool cells count as land, so a pool has no ring. Water cells get none.

## The source of `sea/shore_tiles.tres` and its 8 frames; the foam sheet holds frame f of mask m at
## atlas (f, m), and the shore shader plays the frames from the cell's phase.
const FOAM_SOURCE: int = 0
const FRAMES: int = 8


## Every shore cell of `terrain`, in the grid's order.
static func shore_cells(terrain: GridTerrain, pools: Array[Vector2i]) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for cell: Vector2i in TerrainArt.layer_cells(TerrainArt.SAND, terrain, pools):
		if TerrainArt.corner_mask(TerrainArt.SAND, cell, terrain, pools) != TerrainArt.FULL:
			found.append(cell)
	return found


## The foam tile of `cell` at frame 0 as {source, atlas, alternative}, or {} when it has no shore.
static func foam_tile(cell: Vector2i, terrain: GridTerrain, pools: Array[Vector2i]) -> Dictionary:
	if not TerrainArt.is_member(TerrainArt.SAND, cell, terrain, pools):
		return {}
	var mask: int = TerrainArt.corner_mask(TerrainArt.SAND, cell, terrain, pools)
	if mask == TerrainArt.FULL:
		return {}
	return {&"source": FOAM_SOURCE, &"atlas": Vector2i(0, mask), &"alternative": 0}


## The frame `cell` starts at, 0 to 7: its place along the shore plus one bit of its hash, so the
## foam is uneven but two neighbours are never more than two frames apart (K39).
static func phase(layout_id: StringName, cell: Vector2i) -> int:
	return posmod(cell.x + cell.y + (TerrainArt.cell_hash(layout_id, cell) & 1), FRAMES)
