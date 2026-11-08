class_name IslandLayout
extends RefCounted
## Reads an IslandLayoutData into a GridTerrain and lists of placements (island-generation
## "Handmade sandbar"). Pure: no scene, so tests and the island scene share one reading.

const TILE: int = DevIslandTerrain.TILE
const WALKABLE: Array[DataEnums.Terrain] = [
	DataEnums.Terrain.BEACH, DataEnums.Terrain.DUNE, DataEnums.Terrain.SCRUB, DataEnums.Terrain.SHALLOWS,
]
const STEPS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var terrain: GridTerrain = GridTerrain.new()
## Columns and rows.
var size: Vector2i = Vector2i.ZERO
var palms: Array[Vector2i] = []
## Coconuts on each palm, parallel to `palms`.
var palm_coconuts: Array[int] = []
var workbench: Vector2i = Vector2i(-1, -1)
var solo_spawn: Vector2i = Vector2i(-1, -1)
var coop_spawns: Array[Vector2i] = []
var tide_pools: Array[Vector2i] = []
## The beach cell of the raft's build site; (-1, -1) when the layout has none.
var raft_site: Vector2i = Vector2i(-1, -1)
## The cells shaded by the hut.
var hut_cells: Array[Vector2i] = []
## Each pick-up: {cell: Vector2i, item_id: StringName, count: int, respawn: int, group: StringName}.
var pickups: Array[Dictionary] = []

var _layout: IslandLayoutData
var _problems: PackedStringArray = PackedStringArray()


static func build(layout: IslandLayoutData) -> IslandLayout:
	var built := IslandLayout.new()
	built._read(layout)
	return built


## The pixel position of the middle of `cell`.
static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


## What is wrong with the data: a glyph with no terrain, a row of another length, a missing
## spawn point, palm or workbench. Empty when it is sound.
func problems() -> PackedStringArray:
	return _problems


## Every cell a player on foot can reach from `start` over land and shallows.
func reachable_from(start: Vector2i) -> Dictionary[Vector2i, bool]:
	var seen: Dictionary[Vector2i, bool] = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step: Vector2i in STEPS:
			var next: Vector2i = cell + step
			if seen.has(next) or not terrain.cells.has(next) or not WALKABLE.has(terrain.cells[next]):
				continue
			seen[next] = true
			queue.append(next)
	return seen


func _read(layout: IslandLayoutData) -> void:
	_layout = layout
	terrain.default_terrain = DataEnums.Terrain.DEEP
	size = Vector2i(layout.rows[0].length() if not layout.rows.is_empty() else 0, layout.rows.size())
	var spawns: Dictionary[String, Vector2i] = {}
	for y: int in layout.rows.size():
		var row: String = layout.rows[y]
		if row.length() != size.x:
			_problems.append("row %d has %d cells, not %d" % [y, row.length(), size.x])
		for x: int in row.length():
			_read_cell(Vector2i(x, y), row[x], spawns)
	_share_coconuts()
	for glyph: String in layout.coop_spawn_glyphs:
		if spawns.has(glyph):
			coop_spawns.append(spawns[glyph])
		else:
			_problems.append("no co-op spawn point '%s'" % glyph)
	solo_spawn = spawns.get(layout.solo_spawn_glyph, Vector2i(-1, -1))
	if not spawns.has(layout.solo_spawn_glyph):
		_problems.append("no solo spawn point")
	if palms.is_empty():
		_problems.append("no palms")


func _read_cell(cell: Vector2i, glyph: String, spawns: Dictionary[String, Vector2i]) -> void:
	if not _layout.terrain_glyphs.has(glyph):
		_problems.append("unknown glyph '%s' at %s" % [glyph, cell])
		return
	terrain.set_cell(cell, _layout.terrain_glyphs[glyph])
	if _layout.shade_glyphs.contains(glyph):
		terrain.shaded[cell] = true
		hut_cells.append(cell)
	if glyph == _layout.palm_glyph:
		palms.append(cell)
	elif glyph == _layout.workbench_glyph:
		workbench = cell
	elif glyph == _layout.tide_pool_glyph:
		tide_pools.append(cell)
	elif not _layout.raft_site_glyph.is_empty() and glyph == _layout.raft_site_glyph:
		raft_site = cell
	elif glyph == _layout.solo_spawn_glyph or _layout.coop_spawn_glyphs.contains(glyph):
		spawns[glyph] = cell
	for entry: IslandGlyphData in _layout.pickups:
		if entry.glyph == glyph:
			pickups.append({"cell": cell, "item_id": entry.item_id, "count": entry.count, "respawn": entry.respawn, "group": entry.group})


# The coconuts go round the palms in reading order, so the first palms hold the extra ones.
func _share_coconuts() -> void:
	if palms.is_empty():
		return
	var base: int = _layout.coconut_total / palms.size()
	var extra: int = _layout.coconut_total % palms.size()
	for i: int in palms.size():
		palm_coconuts.append(base + (1 if i < extra else 0))
