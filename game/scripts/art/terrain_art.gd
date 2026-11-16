class_name TerrainArt
extends RefCounted
## Pure, static rules that say which tile a cell gets on each land layer (design.md D11, D14, K39,
## K40): no node, no scene and no random number generator, so every peer and every rebuild picks
## the same tile. The numbers (layers, source ids, picks) are in `terrain_art.tres`.
## A cell is a layer's member when its terrain is one the layer counts; a corner of a cell is land
## when all four cells that share it are members. A layout's tide-pool cells (water to the grid)
## count as land for the Sand layer only (T3).

const SAND: StringName = &"Sand"
const DUNE: StringName = &"Dune"
const BRUSH: StringName = &"Brush"
const PLAIN: StringName = &"Plain"
## Corner bits of a mask.
const NW: int = 1
const NE: int = 2
const SW: int = 4
const SE: int = 8
const FULL: int = 15
## The low 32 bits of an int.
const MASK_32: int = 0xffffffff
## A corner set's tile of mask m is at column m % COLUMNS, row m / COLUMNS; its picks are on PICK_ROW.
const COLUMNS: int = 4
const PICK_ROW: int = 4
## A palm cell counts for the dune when at least this many of its four orthogonal neighbours do
## (art-terrain-polish D1), so a palm in the dune keeps the dune whole round it and a palm out on
## the beach never becomes a lone dune blob.
const PALM_DUNE_SIDES: int = 3
## The four cells that share each corner, as offsets from the cell.
const CORNER_CELLS: Dictionary[int, Array] = {
	NW: [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)],
	NE: [Vector2i(0, -1), Vector2i(1, -1), Vector2i(0, 0), Vector2i(1, 0)],
	SW: [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(-1, 1), Vector2i(0, 1)],
	SE: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
}

static var _data: TerrainArtData


static func data() -> TerrainArtData:
	if _data == null:
		_data = TerrainArtData.standard()
	return _data


## The cosmetic seed of a cell: the same for the same layout and cell on every peer and every
## build (design.md D14). Bit 0 is the shore phase's (ShoreRule); the variants use the higher ones.
## The string hash's low bits barely mix (33 is 1 mod 8), so it goes through an avalanche first
## (art-coast-pass D2): without it the picks ran in diagonal stripes.
static func cell_hash(layout_id: StringName, cell: Vector2i) -> int:
	return mix32(hash("%s:%d,%d" % [layout_id, cell.x, cell.y]))


## murmur3's 32-bit finaliser (fmix32) of the low 32 bits of `value`, from 0 to 2^32 - 1. Every
## product is taken in 16-bit halves and masked, so the 64-bit ints never overflow.
static func mix32(value: int) -> int:
	var mixed: int = value & MASK_32
	mixed ^= mixed >> 16
	mixed = _times32(mixed, 0x85ebca6b)
	mixed ^= mixed >> 13
	mixed = _times32(mixed, 0xc2b2ae35)
	mixed ^= mixed >> 16
	return mixed


# (a * b) mod 2^32 for a and b below 2^32.
static func _times32(a: int, b: int) -> int:
	return (a * (b & 0xffff) + (((a * (b >> 16)) & 0xffff) << 16)) & MASK_32


## The depth-mask step of a water kind; -1 for land.
static func depth_step(kind: DataEnums.Terrain) -> int:
	return data().depth_steps.get(kind, -1)


## The layers `kind` is drawn on, from the bottom up: the sand first, then the layers it belongs
## to (design.md D11: membership is cumulative). Water is on none.
static func layers_for(kind: DataEnums.Terrain) -> Array[StringName]:
	var layers: Array[StringName] = []
	if TerrainQuery.is_water(kind):
		return layers
	var art: TerrainArtData = data()
	var own: StringName = art.layer_of.get(kind, SAND)
	var rank: int = art.set_layers.find(own)
	if rank >= 0:
		for index: int in rank + 1:
			layers.append(art.set_layers[index])
	else:
		layers.append(SAND)
		layers.append(own)
	return layers


## True when `cell` belongs to `layer`. `palms` are the layout's palm cells: on the dune layer a
## palm cell counts when at least PALM_DUNE_SIDES of its four orthogonal neighbours count by the
## terrain alone, so the dune round it keeps its corners (art-terrain-polish D1). Callers that pass
## no palms get the terrain-only rule.
static func is_member(layer: StringName, cell: Vector2i, terrain: GridTerrain, pools: Array[Vector2i], palms: Array[Vector2i] = []) -> bool:
	return _counts(layer, cell, terrain.terrain_at(cell), terrain, pools, palms)


## Every cell of `layer`, in the grid's order.
static func layer_cells(layer: StringName, terrain: GridTerrain, pools: Array[Vector2i], palms: Array[Vector2i] = []) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for cell: Vector2i in terrain.cells:
		if is_member(layer, cell, terrain, pools, palms):
			found.append(cell)
	if layer == SAND:
		for pool: Vector2i in pools:
			if not terrain.cells.has(pool):
				found.append(pool)
	return found


## The corner mask of `cell` on `layer` (NW 1, NE 2, SW 4, SE 8). On the plain layer a corner
## counts when the four cells are all the cell's own terrain, not merely plain (design.md K39).
static func corner_mask(layer: StringName, cell: Vector2i, terrain: GridTerrain, pools: Array[Vector2i], palms: Array[Vector2i] = []) -> int:
	var own: DataEnums.Terrain = terrain.terrain_at(cell)
	var mask: int = 0
	for corner: int in CORNER_CELLS:
		var land: bool = true
		for offset: Vector2i in CORNER_CELLS[corner]:
			if not _counts(layer, cell + offset, own, terrain, pools, palms):
				land = false
				break
		if land:
			mask |= corner
	return mask


## The tile `layer` gives `cell` as {source: int, atlas: Vector2i, alternative: int}, or {} when
## the cell is not in the layer. A cell of an upper layer takes the tile of its own mask from its
## own sheet when the sand under it is whole, and atlas (sand mask, own mask) of the layer's shore
## source otherwise (K39). A full tile, and the brush's islet, take one of the layer's picks by
## the cell's hash; an inland whole plain tile takes its full tile or one of its row's variants.
static func tile(layer: StringName, cell: Vector2i, layout_id: StringName, terrain: GridTerrain, pools: Array[Vector2i], palms: Array[Vector2i] = []) -> Dictionary:
	if not is_member(layer, cell, terrain, pools, palms):
		return {}
	var art: TerrainArtData = data()
	var own: int = corner_mask(layer, cell, terrain, pools, palms)
	var sand: int = own if layer == SAND else corner_mask(SAND, cell, terrain, pools)
	var row: int = art.plain_row.get(terrain.terrain_at(cell), 0) if layer == PLAIN else 0
	var source: int = art.source_of[layer]
	var atlas: Vector2i
	if sand != FULL and layer != SAND:
		source = art.shore_source_of[layer]
		atlas = Vector2i(sand, art.shore_row_stride * row + own)
	elif sand == FULL and own == art.variant_mask.get(layer, -1):
		atlas = Vector2i(_variant(layer, cell, layout_id), PICK_ROW)
	elif layer == PLAIN and own == FULL:
		atlas = Vector2i(FULL + _plain_variant(row, cell, layout_id), row)
	elif layer == PLAIN:
		atlas = Vector2i(own, row)
	else:
		@warning_ignore("integer_division")
		atlas = Vector2i(own % COLUMNS, own / COLUMNS)
	return {&"source": source, &"atlas": atlas, &"alternative": 0}


static func _variant(layer: StringName, cell: Vector2i, layout_id: StringName) -> int:
	var roll: int = cell_hash(layout_id, cell) >> 1
	var weights: PackedInt32Array = data().variant_weights.get(layer, PackedInt32Array())
	if weights.is_empty():
		return roll % int(data().variant_count[layer])
	var total: int = 0
	for weight: int in weights:
		total += weight
	var at: int = roll % total
	for pick: int in weights.size():
		if at < weights[pick]:
			return pick
		at -= weights[pick]
	return weights.size() - 1


## 0 for the full tile, n for the row's n-th variant after it.
static func _plain_variant(row: int, cell: Vector2i, layout_id: StringName) -> int:
	return (cell_hash(layout_id, cell) >> 1) % (1 + int(data().plain_variants.get(row, 0)))


# Whether `at` counts as land for `layer`; `own` is the terrain of the cell whose corners are asked,
# which only the plain layer reads. A palm in `palms` counts for the dune by its neighbours.
static func _counts(layer: StringName, at: Vector2i, own: DataEnums.Terrain, terrain: GridTerrain, pools: Array[Vector2i], palms: Array[Vector2i] = []) -> bool:
	var kind: DataEnums.Terrain = terrain.terrain_at(at)
	if layer == SAND:
		return not TerrainQuery.is_water(kind) or pools.has(at)
	if TerrainQuery.is_water(kind):
		return false
	var art: TerrainArtData = data()
	if layer == PLAIN:
		return kind == own and art.layer_of.get(kind, SAND) == PLAIN
	var rank: int = art.set_layers.find(art.layer_of.get(kind, SAND))
	if rank >= 0 and rank >= art.set_layers.find(layer):
		return true
	return layer == DUNE and palms.has(at) and _dune_sides(at, terrain, pools) >= PALM_DUNE_SIDES


# How many of `at`'s four orthogonal neighbours count for the dune by their terrain alone.
static func _dune_sides(at: Vector2i, terrain: GridTerrain, pools: Array[Vector2i]) -> int:
	var sides: int = 0
	for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if _counts(DUNE, at + step, DataEnums.Terrain.DUNE, terrain, pools):
			sides += 1
	return sides
