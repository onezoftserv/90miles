class_name ShoreRule
extends RefCounted
## Pure, static: which land cells get foam, which foam piece, and the frame each starts at
## (design.md D13, T3, K39, K40). A shore cell is a land cell whose sand corner mask has a water
## corner; a layout's tide-pool cells count as land, so a pool has no ring. Water cells get none.

## The source of `sea/shore_tiles.tres` and its 8 frames; the foam sheet holds frame f of mask m at
## atlas (f, m), and the shore shader plays the frames from the cell's phase.
const FOAM_SOURCE: int = 0
## The still piece (art-terrain-polish D2): the same 8 x 16 layout, every frame alike.
const STILL_SOURCE: int = 1
const FRAMES: int = 8
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


## Every shore cell of `terrain`, in the grid's order.
static func shore_cells(terrain: GridTerrain, pools: Array[Vector2i]) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for cell: Vector2i in TerrainArt.layer_cells(TerrainArt.SAND, terrain, pools):
		if TerrainArt.corner_mask(TerrainArt.SAND, cell, terrain, pools) != TerrainArt.FULL:
			found.append(cell)
	return found


## The foam tile of `cell` at frame 0 as {source, atlas, alternative}, or {} when it has no shore.
## A cell whose water neighbours all lie in `still` (from `still_water`) takes the still piece.
static func foam_tile(cell: Vector2i, terrain: GridTerrain, pools: Array[Vector2i], still: Dictionary[Vector2i, bool] = {}) -> Dictionary:
	if not TerrainArt.is_member(TerrainArt.SAND, cell, terrain, pools):
		return {}
	var mask: int = TerrainArt.corner_mask(TerrainArt.SAND, cell, terrain, pools)
	if mask == TerrainArt.FULL:
		return {}
	var source: int = STILL_SOURCE if _on_still_water(cell, terrain, pools, still) else FOAM_SOURCE
	return {&"source": source, &"atlas": Vector2i(0, mask), &"alternative": 0}


## The water cells of `terrain` that lie in a still body: 4-connected water (a layout's tide pools
## are land, so they are never part of one) that holds no deep cell and stays inside the grid. The
## cay's lagoon is one; a bay that reaches deep water, or the grid's edge, is open.
static func still_water(terrain: GridTerrain, pools: Array[Vector2i] = []) -> Dictionary[Vector2i, bool]:
	var still: Dictionary[Vector2i, bool] = {}
	var seen: Dictionary[Vector2i, bool] = {}
	for start: Vector2i in terrain.cells:
		if seen.has(start) or not _is_water(start, terrain, pools):
			continue
		var body: Array[Vector2i] = []
		var open: bool = false
		var todo: Array[Vector2i] = [start]
		seen[start] = true
		while not todo.is_empty():
			var cell: Vector2i = todo.pop_back()
			body.append(cell)
			if terrain.terrain_at(cell) == DataEnums.Terrain.DEEP:
				open = true
			for side: Vector2i in SIDES:
				var next: Vector2i = cell + side
				if not terrain.cells.has(next):
					open = true
				elif not seen.has(next) and _is_water(next, terrain, pools):
					seen[next] = true
					todo.append(next)
		if not open:
			for cell: Vector2i in body:
				still[cell] = true
	return still


static func _is_water(cell: Vector2i, terrain: GridTerrain, pools: Array[Vector2i]) -> bool:
	return TerrainQuery.is_water(terrain.terrain_at(cell)) and not pools.has(cell)


# True when `cell` has water among its 8 neighbours and every such water cell is still.
static func _on_still_water(cell: Vector2i, terrain: GridTerrain, pools: Array[Vector2i], still: Dictionary[Vector2i, bool]) -> bool:
	if still.is_empty():
		return false
	var wet: int = 0
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			var next: Vector2i = cell + Vector2i(x, y)
			if (x == 0 and y == 0) or not _is_water(next, terrain, pools):
				continue
			if not still.has(next):
				return false
			wet += 1
	return wet > 0


## The frame `cell` starts at, 0 to 7: its place along the shore plus one bit of its hash, so the
## foam is uneven but two neighbours are never more than two frames apart (K39).
static func phase(layout_id: StringName, cell: Vector2i) -> int:
	return posmod(cell.x + cell.y + (TerrainArt.cell_hash(layout_id, cell) & 1), FRAMES)
