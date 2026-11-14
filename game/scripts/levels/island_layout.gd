class_name IslandLayout
extends RefCounted
## Reads an IslandLayoutData into a GridTerrain and lists of placements (island-generation
## "Handmade sandbar"). Pure: no scene, so tests and the island scene share one reading.

const TILE: int = DevIslandTerrain.TILE
const WALKABLE: Array[DataEnums.Terrain] = [
	DataEnums.Terrain.BEACH, DataEnums.Terrain.DUNE, DataEnums.Terrain.SCRUB, DataEnums.Terrain.ROCK,
	DataEnums.Terrain.SHALLOWS,
]
## Land a secret piece may hide on: walkable ground that is not shallows or rock (secret-cay
## "Hiding spots").
const LAND: Array[DataEnums.Terrain] = [DataEnums.Terrain.BEACH, DataEnums.Terrain.DUNE, DataEnums.Terrain.SCRUB]
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
## The cells shaded by the hut (the coast cay's observation post).
var hut_cells: Array[Vector2i] = []
## The shore cells of drinkable water.
var drink_spots: Array[Vector2i] = []
## Each sign: {cell: Vector2i, sign: IslandSignData}, in reading order.
var signs: Array[Dictionary] = []
## Each pick-up: {cell: Vector2i, item_id: StringName, count: int, respawn: int, group: StringName}.
var pickups: Array[Dictionary] = []
## The chest's cell (secret-cay); (-1, -1) when the layout has none.
var chest: Vector2i = Vector2i(-1, -1)
## Each scenery cell: {cell: Vector2i, decor_id: StringName}, in reading order.
var decor: Array[Dictionary] = []

var _layout: IslandLayoutData
var _problems: PackedStringArray = PackedStringArray()


static func build(layout: IslandLayoutData) -> IslandLayout:
	var built := IslandLayout.new()
	built._read(layout)
	return built


## Where arriving players stand, in join order: the co-op spawn points. The first is also the
## solo spawn, so a lone arrival always stands on the first landing cell.
func landing_cells() -> Array[Vector2i]:
	return coop_spawns


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


## How many steps a player on foot needs from `start` to each cell it can reach, over land and
## shallows (the same WALKABLE set as reachable_from: never deep water). Breadth-first.
func walk_distances_from(start: Vector2i) -> Dictionary[Vector2i, int]:
	var distances: Dictionary[Vector2i, int] = {start: 0}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for step: Vector2i in STEPS:
			var next: Vector2i = cell + step
			if distances.has(next) or not terrain.cells.has(next) or not WALKABLE.has(terrain.cells[next]):
				continue
			distances[next] = distances[cell] + 1
			queue.append(next)
	return distances


## secret-cay "Hiding spots" and "Hiding-spot fallback": the land cells a piece may hide on,
## measured from the landing (the solo spawn), in reading order. Strict: between the tuning's
## percentiles of land walking distance and 4-10 tiles (straight line) from the nearest feature of
## a kind it lists, on no feature, spawn or other marked cell. When that list is empty the rule
## relaxes in order: the fallback band, then no feature-distance limit, then any reachable land
## cell that is not taken. Empty only when the island has no such cell.
func hiding_spots(tuning: SecretTuning, catalog: ContentCatalog = null) -> Array[Vector2i]:
	var distances: Dictionary[Vector2i, int] = walk_distances_from(solo_spawn)
	var taken: Dictionary[Vector2i, bool] = _taken_cells()
	var features: Array[Dictionary] = _features(tuning, catalog)
	var land_steps: Array[int] = []
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in distances:
		if not LAND.has(terrain.cells[cell]):
			continue
		land_steps.append(distances[cell])
		if not taken.has(cell):
			candidates.append(cell)
	if candidates.is_empty():
		return candidates
	land_steps.sort()
	candidates.sort_custom(_reading_order)
	var near: Dictionary[Vector2i, float] = {}
	for cell: Vector2i in candidates:
		near[cell] = _nearest_feature(cell, features)["tiles"]
	var passes: Array[Array] = [
		[tuning.spot_percentile_min, tuning.spot_percentile_max, true],
		[tuning.spot_fallback_percentile_min, tuning.spot_fallback_percentile_max, true],
		[tuning.spot_fallback_percentile_min, tuning.spot_fallback_percentile_max, false],
	]
	for rule: Array in passes:
		var low: int = _quantile(land_steps, rule[0])
		var high: int = _quantile(land_steps, rule[1])
		var spots: Array[Vector2i] = []
		for cell: Vector2i in candidates:
			if distances[cell] < low or distances[cell] > high:
				continue
			if rule[2] and (near[cell] < tuning.spot_feature_min_tiles or near[cell] > tuning.spot_feature_max_tiles):
				continue
			spots.append(cell)
		if not spots.is_empty():
			return spots
	return candidates


## The kind of spot `cell` is, for the map's hint: the kind of its nearest feature of a kind the
## tuning lists (`palm`, a pick-up's group such as `flotsam`, `tide_pool`, `workbench`,
## `raft_site`); the first in reading order on a tie; `default` when the island has none.
func spot_kind(cell: Vector2i, tuning: SecretTuning = null, catalog: ContentCatalog = null) -> StringName:
	var nearest: Dictionary = _nearest_feature(cell, _features(tuning if tuning != null else SecretTuning.standard(), catalog))
	return nearest["kind"]



# The features a spot is measured from, in reading order: {cell, kind}.
func _features(tuning: SecretTuning, catalog: ContentCatalog) -> Array[Dictionary]:
	var content: ContentCatalog = catalog if catalog != null else GameState.content
	var kinds: Array[StringName] = tuning.spot_feature_kinds
	var found: Array[Dictionary] = []
	if kinds.has(&"palm"):
		for cell: Vector2i in palms:
			found.append({"cell": cell, "kind": &"palm"})
	if kinds.has(&"pickup"):
		for pickup: Dictionary in pickups:
			if SecretRules.is_secret(content.get_entry(&"items", pickup["item_id"])):
				continue
			var group: StringName = pickup["group"]
			found.append({"cell": pickup["cell"], "kind": group if not group.is_empty() else &"pickup"})
	if kinds.has(&"tide_pool"):
		for cell: Vector2i in tide_pools:
			found.append({"cell": cell, "kind": &"tide_pool"})
	if kinds.has(&"workbench") and workbench.x >= 0:
		found.append({"cell": workbench, "kind": &"workbench"})
	if kinds.has(&"raft_site") and raft_site.x >= 0:
		found.append({"cell": raft_site, "kind": &"raft_site"})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _reading_order(a["cell"], b["cell"]))
	return found


# {tiles, kind} of the feature nearest `cell` in a straight line; INF and `default` with none.
func _nearest_feature(cell: Vector2i, features: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {"tiles": INF, "kind": &"default"}
	for feature: Dictionary in features:
		var tiles: float = Vector2(cell).distance_to(Vector2(feature["cell"]))
		if tiles < best["tiles"]:
			best = {"tiles": tiles, "kind": feature["kind"]}
	return best


# Every cell something already stands on: spawns, palms, pick-ups, tide pools, the workbench, the
# raft site, drinking spots, signs, the chest and the decor.
func _taken_cells() -> Dictionary[Vector2i, bool]:
	var taken: Dictionary[Vector2i, bool] = {solo_spawn: true}
	var lists: Array[Array] = [coop_spawns, palms, tide_pools, drink_spots, [workbench, raft_site, chest]]
	for list: Array in lists:
		for cell: Vector2i in list:
			taken[cell] = true
	for pickup: Dictionary in pickups:
		taken[pickup["cell"]] = true
	for sign_entry: Dictionary in signs:
		taken[sign_entry["cell"]] = true
	for decor_entry: Dictionary in decor:
		taken[decor_entry["cell"]] = true
	return taken


# The step count at quantile `q` of `sorted`, nearest rank.
static func _quantile(sorted: Array[int], q: float) -> int:
	return sorted[clampi(roundi(q * (sorted.size() - 1)), 0, sorted.size() - 1)]


static func _reading_order(a: Vector2i, b: Vector2i) -> bool:
	return a.y < b.y or a.y == b.y and a.x < b.x


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
	for index: int in layout.nest_palms:
		if index < 0 or index >= palms.size():
			_problems.append("nest palm %d is not a palm" % index)


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
	elif not _layout.drink_glyph.is_empty() and glyph == _layout.drink_glyph:
		drink_spots.append(cell)
	elif glyph == _layout.solo_spawn_glyph or _layout.coop_spawn_glyphs.contains(glyph):
		spawns[glyph] = cell
	elif not _layout.chest_glyph.is_empty() and glyph == _layout.chest_glyph:
		chest = cell
	if _layout.decor_glyphs.has(glyph):
		decor.append({"cell": cell, "decor_id": _layout.decor_glyphs[glyph]})
	for sign_data: IslandSignData in _layout.signs:
		if sign_data.glyph == glyph:
			signs.append({"cell": cell, "sign": sign_data})
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
