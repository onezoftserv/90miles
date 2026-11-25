class_name TerrainView
extends Node2D
## The ground drawn from the grid (art-pass "Terrain tile layers", "Land edges", "Scrolling sea",
## "Shoreline overlay", "Tide pools and contact shade"; design.md D11-D15, K39, K46): the sea rect
## and the tile layers of its scene, filled cell by cell from TerrainArt, ShoreRule and SeaMask,
## the same on every peer for the same layout. It only reads its parent: `terrain` (a GridTerrain)
## and, when the parent has them, `layout` (whose id seeds the variants) and `built` (the grid's
## size, tide pools and palms). It checks them every frame and builds again when the grid changes.
## Its tile sets have no physics, navigation or occlusion layer, so it never blocks anything.

## The corner-set and plain layers, each filled by TerrainArt.tile.
const LAND_LAYERS: Array[StringName] = [TerrainArt.SAND, TerrainArt.DUNE, TerrainArt.PLAIN, TerrainArt.BRUSH]
## decals/decal_tiles.tres: the tide pool, and the shade corner set whose row 4 starts with a palm's
## foot shade (design.md K36, K39).
const POOL_SOURCE: int = 0
const SHADE_SOURCE: int = 1
## The pebble decals at the foot of a straight rock seam (art-terrain-polish D6), by the rock
## cell's own plain mask: the tile whose stones sit in the sand strip that seam leaves.
const PEBBLE_SOURCE: int = 2
const PEBBLE_SIDE: Dictionary[int, Vector2i] = {10: Vector2i(0, 0), 5: Vector2i(1, 0), 12: Vector2i(2, 0), 3: Vector2i(3, 0)}
const PALM_SHADE: Vector2i = Vector2i(0, 4)
## Under a shelter (art-prop-polish D5) the shaded cells take the hut shade of decals/shade.png:
## one corner set per depth band from the hut's north edge, starting on this row, darkest under the
## roof and fading south; a deeper cell takes the last band.
const HUT_SHADE_ROW: int = 5
const HUT_SHADE_BANDS: int = 3
## How far the sea reaches past the grid on each side, in px, for a camera at the island's edge.
const SEA_MARGIN_PX: float = 640.0

## What the last build read: the layout id, the grid's columns and rows, and its two masks.
var layout_id: StringName = &""
var grid_size: Vector2i = Vector2i.ZERO
var depth_bytes: PackedByteArray = PackedByteArray()
## The sea mask's RG bytes the last build set, two per cell (SeaMask.soft_channels).
var sea_channels: PackedByteArray = PackedByteArray()
var phase_bytes: PackedByteArray = PackedByteArray()
## How long the last build took, in microseconds (design.md T12).
var build_usec: int = 0

var _grid: GridTerrain
var _grid_cells: int = -1

@onready var _sea: Polygon2D = $Sea
@onready var _shore: TileMapLayer = $Shore
@onready var _decals: TileMapLayer = $Decals


func _init() -> void:
	add_to_group(&"art_view")


func _ready() -> void:
	_follow()


func _process(_delta: float) -> void:
	_follow()


# Builds again when the parent's grid is another one or has grown; keeps the foam on its cells.
func _follow() -> void:
	var source: Node = get_parent()
	var grid := (source.get(&"terrain") if source != null else null) as GridTerrain
	if grid != null and (grid != _grid or grid.cells.size() != _grid_cells):
		_build(source, grid)
	(_shore.material as ShaderMaterial).set_shader_parameter(&"origin", _shore.global_position)


func _build(source: Node, grid: GridTerrain) -> void:
	var started: int = Time.get_ticks_usec()
	_grid = grid
	_grid_cells = grid.cells.size()
	var pools: Array[Vector2i] = []
	var palms: Array[Vector2i] = []
	var spots: Array[Vector2i] = []
	var built := source.get(&"built") as IslandLayout
	if built != null:
		grid_size = built.size
		pools = built.tide_pools
		palms = built.palms
		spots = [built.workbench]
	else:
		grid_size = _extent(grid)
	var layout := source.get(&"layout") as IslandLayoutData
	layout_id = layout.id if layout != null else StringName(String(source.name).to_snake_case())
	for layer: StringName in LAND_LAYERS:
		var tiles := get_node(NodePath(layer)) as TileMapLayer
		tiles.clear()
		for cell: Vector2i in TerrainArt.layer_cells(layer, grid, pools, palms):
			_put(tiles, cell, TerrainArt.tile(layer, cell, layout_id, grid, pools, palms))
	_shore.clear()
	var shore_cells: Array[Vector2i] = ShoreRule.shore_cells(grid, pools)
	var still: Dictionary[Vector2i, bool] = ShoreRule.still_water(grid, pools)
	for cell: Vector2i in shore_cells:
		_put(_shore, cell, ShoreRule.foam_tile(cell, grid, pools, still))
	_build_decals(grid, pools, palms, spots)
	depth_bytes = SeaMask.depth_bytes(grid_size, grid)
	phase_bytes = SeaMask.phase_bytes(layout_id, grid_size, grid, pools, shore_cells)
	_build_sea()
	var phases: Image = SeaMask.to_image(phase_bytes, grid_size, ShoreRule.FRAMES - 1)
	(_shore.material as ShaderMaterial).set_shader_parameter(&"phase_mask", ImageTexture.create_from_image(phases))
	build_usec = maxi(Time.get_ticks_usec() - started, 1)


func _put(tiles: TileMapLayer, cell: Vector2i, tile: Dictionary) -> void:
	tiles.set_cell(cell, tile[&"source"], tile[&"atlas"], tile[&"alternative"])


# Tide pools, then the shade of shaded cells as a corner set, then a foot shade under each palm
# and the workbench whose cell holds no decal yet, then the pebbles. The raft and its site cast
# their own WIDE drop shadow from their look (art-terrain-polish D3), so no decal lies under them.
func _build_decals(grid: GridTerrain, pools: Array[Vector2i], palms: Array[Vector2i], spots: Array[Vector2i]) -> void:
	_decals.clear()
	for pool: Vector2i in pools:
		_decals.set_cell(pool, POOL_SOURCE, Vector2i.ZERO)
	var sheltered: bool = ShelterArtData.standard().hut_shade.get(layout_id, false)
	for cell: Vector2i in grid.shaded:
		if not pools.has(cell):
			if sheltered:
				_decals.set_cell(cell, SHADE_SOURCE, hut_shade_tile(cell, grid))
				continue
			var mask: int = _shade_mask(cell, grid)
			@warning_ignore("integer_division")
			_decals.set_cell(cell, SHADE_SOURCE, Vector2i(mask % TerrainArt.COLUMNS, mask / TerrainArt.COLUMNS))
	for foot: Vector2i in palms + spots:
		if foot.x >= 0 and _decals.get_cell_source_id(foot) < 0:
			_decals.set_cell(foot, SHADE_SOURCE, PALM_SHADE)
	for cell: Vector2i in grid.cells:
		var side: Vector2i = _pebble_side(cell, grid, pools)
		if side.x >= 0 and has_pebbles(layout_id, cell) and _decals.get_cell_source_id(cell) < 0:
			_decals.set_cell(cell, PEBBLE_SOURCE, side)


## Whether the rock cell `cell` of the layout `layout_id` shows pebbles at its foot: about one
## seam cell in two, by its hash (art-terrain-polish D6), the same on every peer.
static func has_pebbles(layout_id: StringName, cell: Vector2i) -> bool:
	return (TerrainArt.cell_hash(layout_id, cell) >> 3) & 1 == 0


# The pebble tile for a rock cell on a straight inland seam (its sand whole, its own plain mask
# one straight edge): the one that sits in the sand strip the seam leaves; (-1, -1) otherwise.
static func _pebble_side(cell: Vector2i, grid: GridTerrain, pools: Array[Vector2i]) -> Vector2i:
	if grid.terrain_at(cell) != DataEnums.Terrain.ROCK:
		return Vector2i(-1, -1)
	if TerrainArt.corner_mask(TerrainArt.SAND, cell, grid, pools) != TerrainArt.FULL:
		return Vector2i(-1, -1)
	return PEBBLE_SIDE.get(TerrainArt.corner_mask(TerrainArt.PLAIN, cell, grid, pools), Vector2i(-1, -1))


# A corner of a shaded cell counts when the four cells round it are shaded (design.md K39).
## The hut-shade tile of the shaded cell `cell` under a shelter (art-prop-polish D5): the band of its
## depth from the hut's north edge, and the corner mask counting the cell north of any shaded cell
## as shaded, so the shade is whole up to the roof line instead of fading at the posts.
static func hut_shade_tile(cell: Vector2i, grid: GridTerrain) -> Vector2i:
	var depth: int = 0
	while grid.is_shaded(cell - Vector2i(0, depth + 1)):
		depth += 1
	var mask: int = 0
	for corner: int in TerrainArt.CORNER_CELLS:
		var whole: bool = true
		for offset: Vector2i in TerrainArt.CORNER_CELLS[corner]:
			var near: Vector2i = cell + offset
			whole = whole and (grid.is_shaded(near) or grid.is_shaded(near + Vector2i.DOWN))
		if whole:
			mask |= corner
	@warning_ignore("integer_division")
	return Vector2i(mask % TerrainArt.COLUMNS, HUT_SHADE_ROW + mini(depth, HUT_SHADE_BANDS - 1) * TerrainArt.COLUMNS + mask / TerrainArt.COLUMNS)


static func _shade_mask(cell: Vector2i, grid: GridTerrain) -> int:
	var mask: int = 0
	for corner: int in TerrainArt.CORNER_CELLS:
		var whole: bool = true
		for offset: Vector2i in TerrainArt.CORNER_CELLS[corner]:
			whole = whole and grid.is_shaded(cell + offset)
		if whole:
			mask |= corner
	return mask


# The sea rect over the grid and its margin, and its material's textures: the water and ramps
# from ArtTuning, and the depth mask with shallowness and brackishness in two channels, so linear
# filtering between brackish and deep never passes through shallows, softened (art-coast-pass D6).
func _build_sea() -> void:
	var tile: float = float(IslandLayout.TILE)
	var area := Rect2(Vector2.ZERO, Vector2(grid_size) * tile).grow(SEA_MARGIN_PX)
	_sea.polygon = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
	sea_channels = setup_sea(_sea.material as ShaderMaterial, depth_bytes, grid_size, tile)


## Sets the sea shader's parameters on `material` for a grid of `cells` columns and rows of
## `cell_px` each, with `depth_bytes` as its depth steps: the one setup both the island's sea and the
## crossing's (CrossingSea) use, so they cannot drift apart. The mask is SeaMask.soft_channels'
## softened one and the shader warps where it samples it by SeaMask's numbers (art-coast-pass D6).
## Returns the mask's bytes.
static func setup_sea(material: ShaderMaterial, depth_bytes: PackedByteArray, cells: Vector2i, cell_px: float) -> PackedByteArray:
	var art: TerrainArtData = TerrainArt.data()
	var deep: int = art.depth_steps[DataEnums.Terrain.DEEP]
	var brackish: int = art.depth_steps[DataEnums.Terrain.BRACKISH]
	var channels: PackedByteArray = SeaMask.soft_channels(depth_bytes, cells, cell_px)
	var mask := Image.create_from_data(cells.x, cells.y, false, Image.FORMAT_RG8, channels)
	var tuning := load(ArtTuning.STANDARD_PATH) as ArtTuning
	material.set_shader_parameter(&"water", tuning.sea_water)
	material.set_shader_parameter(&"ramps", tuning.sea_ramps)
	material.set_shader_parameter(&"depth_mask", ImageTexture.create_from_image(mask))
	material.set_shader_parameter(&"grid_cells", Vector2(cells))
	material.set_shader_parameter(&"cell_px", cell_px)
	material.set_shader_parameter(&"deep_row", deep)
	material.set_shader_parameter(&"shallows_row", art.depth_steps[DataEnums.Terrain.SHALLOWS])
	material.set_shader_parameter(&"brackish_row", brackish)
	material.set_shader_parameter(&"warp_px", SeaMask.WARP_PX)
	material.set_shader_parameter(&"warp_period_px", SeaMask.WARP_PERIOD_PX)
	return channels


# Columns and rows of a grid with no layout: one past its largest cell.
static func _extent(grid: GridTerrain) -> Vector2i:
	var size := Vector2i.ONE
	for cell: Vector2i in grid.cells:
		size = Vector2i(maxi(size.x, cell.x + 1), maxi(size.y, cell.y + 1))
	return size
