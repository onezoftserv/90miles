class_name IslandValidator
extends RefCounted
## island-generator design §5: every check a generated island must pass, each failure a message
## naming the check. Reads the built island (so a test can edit its grid) and its POI anchors.

const T := DataEnums.Terrain
const LAND: Array[DataEnums.Terrain] = [T.BEACH, T.DUNE, T.SCRUB, T.ROCK]


## Failure messages; empty when the island passes.
static func check(chain: ChainData, built: IslandLayout, pois: Array[Dictionary], catalog: ContentCatalog) -> PackedStringArray:
	var failures := PackedStringArray()
	failures.append_array(built.problems())
	var grid := IslandGrid.new(built.size.x, built.size.y)
	if grid.cell_count() == 0:
		failures.append("size: the island has no cells")
		return failures
	var terrain := grid.filled(T.DEEP)
	for cell: Vector2i in built.terrain.cells:
		if grid.has(cell):
			terrain[grid.index_of(cell)] = built.terrain.cells[cell]
	var land: PackedInt32Array = grid.mask_of(terrain, LAND)
	_check_land(chain, grid, land, failures)
	_check_pois(chain, pois, catalog, failures)
	if built.coop_spawns.is_empty():
		failures.append("landing: no landing cells")
		return failures
	var walk: PackedInt32Array = grid.chamfer_walk(grid.mask_of(terrain, IslandLayout.WALKABLE), built.coop_spawns[0])
	_check_reach(grid, built, walk, failures)
	_check_landing(chain, built, failures)
	_check_walks(chain, grid, built, land, walk, pois, failures)
	return failures


static func _check_land(chain: ChainData, grid: IslandGrid, land: PackedInt32Array, failures: PackedStringArray) -> void:
	var count: int = 0
	var margin: int = chain.edge_margin_tiles
	var in_margin: int = 0
	for i: int in land.size():
		if land[i] == 0:
			continue
		count += 1
		var cell: Vector2i = grid.cell_of(i)
		if cell.x < margin or cell.y < margin or cell.x >= grid.width - margin or cell.y >= grid.height - margin:
			in_margin += 1
	if chain.land_cells.y > 0 and (count < chain.land_cells.x or count > chain.land_cells.y):
		failures.append("land count: %d, not %d-%d" % [count, chain.land_cells.x, chain.land_cells.y])
	var share: float = float(count) / float(grid.cell_count())
	if share < chain.land_fraction.x or share > chain.land_fraction.y:
		failures.append("land share: %.3f, not %.2f-%.2f" % [share, chain.land_fraction.x, chain.land_fraction.y])
	if in_margin > 0:
		failures.append("margin: %d land cells inside the %d-tile margin" % [in_margin, margin])
	var bodies: Dictionary = grid.label_bodies(land)
	var sizes: PackedInt32Array = bodies["sizes"]
	if chain.landmass_count > 0 and sizes.size() != chain.landmass_count:
		failures.append("landmass: %d bodies, not %d" % [sizes.size(), chain.landmass_count])
	var reach: int = chain.max_inland_distance_tiles
	if reach > 0:
		var water := grid.filled(0)
		for i: int in land.size():
			water[i] = 1 - land[i]
		var rings: PackedInt32Array = grid.chebyshev_from(water)
		for i: int in land.size():
			# Chebyshev d ≤ Euclidean ≤ √2·d: only the deep cells need the window.
			if land[i] == 0 or rings[i] * rings[i] * 2 <= reach * reach:
				continue
			var squared: int = grid.nearest_squared(water, grid.cell_of(i), reach, true)
			if squared < 0:
				failures.append("inland: %s is more than %d tiles from water" % [grid.cell_of(i), reach])
				break


static func _check_pois(chain: ChainData, pois: Array[Dictionary], catalog: ContentCatalog, failures: PackedStringArray) -> void:
	var kinds: Dictionary[StringName, bool] = {}
	for placed: Dictionary in pois:
		if kinds.has(placed["id"]):
			failures.append("pois: %s placed twice" % placed["id"])
		kinds[placed["id"]] = true
	var required: Array[StringName] = chain.guaranteed_poi_ids.duplicate()
	if not chain.signature_poi_id.is_empty():
		required.append(chain.signature_poi_id)
	for poi_id: StringName in required:
		if not kinds.has(poi_id):
			failures.append("pois: guaranteed %s is missing" % poi_id)
	if pois.size() < chain.poi_count.x or pois.size() > chain.poi_count.y:
		failures.append("pois: %d placed, not %d-%d" % [pois.size(), chain.poi_count.x, chain.poi_count.y])
	for a: int in pois.size():
		var poi := catalog.get_entry(&"pois", pois[a]["id"]) as PoiData
		var apart: int = poi.min_distance_tiles if poi != null else 0
		for b: int in range(a + 1, pois.size()):
			var d: Vector2i = (pois[a]["anchor"] as Vector2i) - (pois[b]["anchor"] as Vector2i)
			if d.x * d.x + d.y * d.y < apart * apart:
				failures.append("poi spacing: %s and %s are under %d tiles apart" % [pois[a]["id"], pois[b]["id"], apart])


static func _check_reach(grid: IslandGrid, built: IslandLayout, walk: PackedInt32Array, failures: PackedStringArray) -> void:
	var cells: Array[Vector2i] = built.coop_spawns.duplicate()
	if built.raft_site.x >= 0:
		cells.append(built.raft_site)
	for pickup: Dictionary in built.pickups:
		cells.append(pickup["cell"])
	cells.append_array(built.palms)
	cells.append_array(built.hut_cells)
	for cell: Vector2i in cells:
		if not grid.has(cell) or walk[grid.index_of(cell)] < 0:
			failures.append("reach: %s cannot be reached from the landing" % cell)
			return


static func _check_landing(chain: ChainData, built: IslandLayout, failures: PackedStringArray) -> void:
	var cells: Array[Vector2i] = built.coop_spawns
	if cells.size() != chain.landing_cell_count:
		failures.append("landing: %d cells, not %d" % [cells.size(), chain.landing_cell_count])
	for cell: Vector2i in cells:
		if built.terrain.terrain_at(cell) != T.BEACH:
			failures.append("landing: %s is not beach" % cell)
	var spread: int = chain.landing_spread_tiles
	for a: int in cells.size():
		for b: int in range(a + 1, cells.size()):
			var d: Vector2i = cells[a] - cells[b]
			if d.x * d.x + d.y * d.y > spread * spread:
				failures.append("landing: %s and %s are over %d tiles apart" % [cells[a], cells[b], spread])
				return


static func _check_walks(chain: ChainData, grid: IslandGrid, built: IslandLayout, land: PackedInt32Array, walk: PackedInt32Array, pois: Array[Dictionary], failures: PackedStringArray) -> void:
	if built.raft_site.x >= 0:
		_band("raft site", walk[grid.index_of(built.raft_site)], chain.raft_site_walk_s, failures)
	else:
		failures.append("raft site: none")
	for placed: Dictionary in pois:
		if chain.poi_walk_s.has(placed["id"]):
			_band("poi %s" % placed["id"], walk[grid.index_of(placed["anchor"])], chain.poi_walk_s[placed["id"]], failures)
	var far: int = -1
	for i: int in land.size():
		if land[i] != 0:
			far = maxi(far, walk[i])
	_band("far end", far, chain.far_end_walk_s, failures)


static func _band(what: String, half_tiles: int, seconds: Vector2, failures: PackedStringArray) -> void:
	var band: Vector2i = PoiPlacer.walk_band(seconds)
	if half_tiles < band.x or half_tiles > band.y:
		failures.append("walk: %s is %.1f s away, not %.1f-%.1f" % [what, half_tiles / PoiPlacer.HALF_TILES_PER_S, seconds.x, seconds.y])
