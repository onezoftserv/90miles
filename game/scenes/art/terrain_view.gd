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
const PALM_SHADE: Vector2i = Vector2i(0, 4)
## The two halves of the wide shade under the raft site: its west neighbour and its own cell.
const WIDE_WEST: Vector2i = Vector2i(1, 4)
const WIDE_EAST: Vector2i = Vector2i(2, 4)
## How far the sea reaches past the grid on each side, in px, for a camera at the island's edge.
const SEA_MARGIN_PX: float = 640.0

## What the last build read: the layout id, the grid's columns and rows, and its two masks.
var layout_id: StringName = &""
var grid_size: Vector2i = Vector2i.ZERO
var depth_bytes: PackedByteArray = PackedByteArray()
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
		for cell: Vector2i in TerrainArt.layer_cells(layer, grid, pools):
			_put(tiles, cell, TerrainArt.tile(layer, cell, layout_id, grid, pools))
	_shore.clear()
	var shore_cells: Array[Vector2i] = ShoreRule.shore_cells(grid, pools)
	for cell: Vector2i in shore_cells:
		_put(_shore, cell, ShoreRule.foam_tile(cell, grid, pools))
	_build_decals(grid, pools, palms, spots, built.raft_site if built != null else Vector2i(-1, -1))
	depth_bytes = SeaMask.depth_bytes(grid_size, grid)
	phase_bytes = SeaMask.phase_bytes(layout_id, grid_size, grid, pools, shore_cells)
	_build_sea()
	var phases: Image = SeaMask.to_image(phase_bytes, grid_size, ShoreRule.FRAMES - 1)
	(_shore.material as ShaderMaterial).set_shader_parameter(&"phase_mask", ImageTexture.create_from_image(phases))
	build_usec = maxi(Time.get_ticks_usec() - started, 1)


func _put(tiles: TileMapLayer, cell: Vector2i, tile: Dictionary) -> void:
	tiles.set_cell(cell, tile[&"source"], tile[&"atlas"], tile[&"alternative"])


# Tide pools, then the shade of shaded cells as a corner set, then a foot shade under each palm
# and the workbench whose cell holds no decal yet, then the wide shade under the raft site.
func _build_decals(grid: GridTerrain, pools: Array[Vector2i], palms: Array[Vector2i], spots: Array[Vector2i], raft_site: Vector2i) -> void:
	_decals.clear()
	for pool: Vector2i in pools:
		_decals.set_cell(pool, POOL_SOURCE, Vector2i.ZERO)
	for cell: Vector2i in grid.shaded:
		if not pools.has(cell):
			var mask: int = _shade_mask(cell, grid)
			@warning_ignore("integer_division")
			_decals.set_cell(cell, SHADE_SOURCE, Vector2i(mask % TerrainArt.COLUMNS, mask / TerrainArt.COLUMNS))
	for foot: Vector2i in palms + spots:
		if foot.x >= 0 and _decals.get_cell_source_id(foot) < 0:
			_decals.set_cell(foot, SHADE_SOURCE, PALM_SHADE)
	if raft_site.x >= 0:
		for half: Dictionary in [{&"cell": raft_site + Vector2i.LEFT, &"atlas": WIDE_WEST}, {&"cell": raft_site, &"atlas": WIDE_EAST}]:
			var cell: Vector2i = half[&"cell"]
			if TerrainArt.depth_step(grid.terrain_at(cell)) < 0 and _decals.get_cell_source_id(cell) < 0:
				_decals.set_cell(cell, SHADE_SOURCE, half[&"atlas"])


# A corner of a shaded cell counts when the four cells round it are shaded (design.md K39).
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
# filtering between brackish and deep never passes through shallows.
func _build_sea() -> void:
	var tile: float = float(IslandLayout.TILE)
	var area := Rect2(Vector2.ZERO, Vector2(grid_size) * tile).grow(SEA_MARGIN_PX)
	_sea.polygon = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
	setup_sea(_sea.material as ShaderMaterial, depth_bytes, grid_size, tile)


## Sets the sea shader's parameters on `material` for a grid of `cells` columns and rows of
## `cell_px` each, with `depth_bytes` as its depth steps: the one setup both the island's sea and the
## crossing's (CrossingSea) use, so they cannot drift apart.
static func setup_sea(material: ShaderMaterial, depth_bytes: PackedByteArray, cells: Vector2i, cell_px: float) -> void:
	var art: TerrainArtData = TerrainArt.data()
	var deep: int = art.depth_steps[DataEnums.Terrain.DEEP]
	var brackish: int = art.depth_steps[DataEnums.Terrain.BRACKISH]
	var channels := PackedByteArray()
	channels.resize(depth_bytes.size() * 2)
	for index: int in depth_bytes.size():
		channels[index * 2] = 0 if depth_bytes[index] == deep else 255
		channels[index * 2 + 1] = 255 if depth_bytes[index] == brackish else 0
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


# Columns and rows of a grid with no layout: one past its largest cell.
static func _extent(grid: GridTerrain) -> Vector2i:
	var size := Vector2i.ONE
	for cell: Vector2i in grid.cells:
		size = Vector2i(maxi(size.x, cell.x + 1), maxi(size.y, cell.y + 1))
	return size
