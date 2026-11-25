class_name PoiPlacer
extends RefCounted
## island-generator design §4 steps 9–14 on a painted grid: the landing, the walk map, the raft
## site, the POIs and their pieces, the ambient pick-ups and the routes. Every choice is an
## integer draw from its stage's generator; candidates are always listed in reading order.

const T := DataEnums.Terrain
## Half-tiles per second for a lone walker (MovementModel.WALK_SPEED tiles a second, 2 a tile).
const HALF_TILES_PER_S: float = MovementModel.WALK_SPEED * 2.0
## The chamfer walk is at most 6.1% longer than the Euclidean path, so lower bands are raised by
## 7%: an island accepted here also passes the tests' AStarGrid2D measure.
const LOWER_BAND_RAISE: float = 1.07
## Anchors tried per POI before it fits nowhere.
const ANCHOR_TRIES: int = 20
const LAND_TERRAIN: Array[DataEnums.Terrain] = [T.BEACH, T.DUNE, T.SCRUB, T.ROCK]

var chain: ChainData
var catalog: ContentCatalog
var grid: IslandGrid
var terrain: PackedInt32Array
var to_water: PackedInt32Array
var lee_coast: PackedInt32Array
var shore_width: int = 0
var walkable: PackedInt32Array

var failures := PackedStringArray()
var landing: Array[Vector2i] = []
var raft_site := Vector2i(-1, -1)
## Half-tile walk distances from the first landing cell; -1 where it cannot walk.
var walk := PackedInt32Array()
## Each placed POI: {id: StringName, anchor: Vector2i}.
var pois: Array[Dictionary] = []
var shaded: Array[Vector2i] = []
var palms: Array[Vector2i] = []
var coconuts: int = 0
## The POI whose palms these are (its harvest effects are the climb's cost).
var climb_poi: StringName = &""
## Each pick-up: {cell, item_id, count, respawn, group, scaling}.
var pickups: Array[Dictionary] = []
var routes: Array[StringName] = []

# Cell index -> true for every marker and piece.
var _taken: Dictionary[int, bool] = {}


func _init(template: ChainData, content: ContentCatalog, painted: Dictionary) -> void:
	chain = template
	catalog = content
	grid = painted["grid"]
	terrain = painted["terrain"]
	to_water = painted["to_water"]
	lee_coast = painted["lee_coast"]
	shore_width = painted["shore_width"]
	walkable = grid.mask_of(terrain, IslandLayout.WALKABLE)


## Runs every step; failures says why the attempt cannot be used (empty when it can).
func place(landing_rng: RandomNumberGenerator, pois_rng: RandomNumberGenerator, pickups_rng: RandomNumberGenerator, routes_rng: RandomNumberGenerator, relaxed: bool) -> void:
	if not _place_landing(landing_rng):
		return
	walk = grid.chamfer_walk(walkable, landing[0])
	_place_raft_site(landing_rng)
	_place_pois(pois_rng, relaxed)
	_place_ambient(pickups_rng)
	_roll_routes(routes_rng)


## The half-tile band of a band in seconds: the upper as it is, the lower raised by 7%.
static func walk_band(seconds: Vector2) -> Vector2i:
	return Vector2i(ceili(seconds.x * LOWER_BAND_RAISE * HALF_TILES_PER_S), floori(seconds.y * HALF_TILES_PER_S))


func _at(cell: Vector2i) -> int:
	return terrain[grid.index_of(cell)]


func is_land(cell: Vector2i) -> bool:
	return grid.has(cell) and LAND_TERRAIN.has(_at(cell))


func _beside(cell: Vector2i, kinds: Array) -> bool:
	for step: Vector2i in IslandGrid.ORTHOGONAL:
		var next: Vector2i = cell + step
		if grid.has(next) and kinds.has(_at(next)):
			return true
	return false


func _reached(cell: Vector2i) -> bool:
	return walk[grid.index_of(cell)] >= 0


static func _squared(a: Vector2i, b: Vector2i) -> int:
	var d: Vector2i = a - b
	return d.x * d.x + d.y * d.y


# Sorts `cells` by squared distance from `from`, then reading order.
static func _by_distance(cells: Array[Vector2i], from: Vector2i) -> Array[Vector2i]:
	var keyed: Array[Vector2i] = cells.duplicate()
	keyed.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = _squared(a, from)
		var db: int = _squared(b, from)
		return da < db or da == db and (a.y < b.y or a.y == b.y and a.x < b.x))
	return keyed


# Step 9.
func _place_landing(rng: RandomNumberGenerator) -> bool:
	var candidates: Array[Vector2i] = []
	var shore: Array[Vector2i] = []
	for i: int in terrain.size():
		var cell: Vector2i = grid.cell_of(i)
		if terrain[i] != T.BEACH or not _beside(cell, [T.SHALLOWS]):
			continue
		shore.append(cell)
		if lee_coast[i] != 0:
			candidates.append(cell)
	if candidates.is_empty():
		failures.append("landing: no lee beach beside shallows")
		return false
	var total := Vector2i.ZERO
	for cell: Vector2i in candidates:
		total += cell
	var centroid: Vector2i = total / candidates.size()
	var middle: Vector2i = _by_distance(candidates, centroid)[0]
	var nearest: Array[Vector2i] = _by_distance(candidates, middle)
	var first: Vector2i = nearest[rng.randi_range(0, mini(5, nearest.size()) - 1)]
	landing = [first]
	for cell: Vector2i in _by_distance(shore, first):
		if landing.size() >= chain.landing_cell_count:
			break
		if cell != first:
			landing.append(cell)
	for cell: Vector2i in landing:
		_taken[grid.index_of(cell)] = true
	return true


# Step 11: a beach cell in the raft band, nearest the band's middle.
func _place_raft_site(rng: RandomNumberGenerator) -> void:
	var band: Vector2i = walk_band(chain.raft_site_walk_s)
	var middle: int = (band.x + band.y) / 2
	var best: int = IslandGrid.FAR
	var ties: Array[Vector2i] = []
	for i: int in terrain.size():
		if terrain[i] != T.BEACH or _taken.has(i) or walk[i] < band.x or walk[i] > band.y:
			continue
		var off: int = absi(walk[i] - middle)
		if off < best:
			best = off
			ties = []
		if off == best:
			ties.append(grid.cell_of(i))
	if ties.is_empty():
		failures.append("raft site: no beach cell in its walk band")
		return
	raft_site = ties[rng.randi_range(0, ties.size() - 1)]
	_taken[grid.index_of(raft_site)] = true


# Step 12.
func _place_pois(rng: RandomNumberGenerator, relaxed: bool) -> void:
	var order: Array[Dictionary] = []
	var seen: Dictionary[StringName, bool] = {}
	if not chain.signature_poi_id.is_empty():
		order.append({"id": chain.signature_poi_id, "required": true})
		seen[chain.signature_poi_id] = true
	for poi_id: StringName in chain.guaranteed_poi_ids:
		if not seen.has(poi_id):
			order.append({"id": poi_id, "required": true})
			seen[poi_id] = true
	var rolled: Array[String] = []
	for poi_id: StringName in chain.poi_chances:
		if not seen.has(poi_id):
			rolled.append(String(poi_id))
	rolled.sort()
	for poi_id: String in rolled:
		var chance: float = chain.poi_chances[StringName(poi_id)]
		var kept: bool = IslandSeeds.roll(rng, chance)
		if kept and not relaxed:
			order.append({"id": StringName(poi_id), "required": false})
	for entry: Dictionary in order:
		var poi := catalog.get_entry(&"pois", entry["id"]) as PoiData
		if poi == null:
			failures.append("poi %s: no such POI" % entry["id"])
			continue
		if not _place_poi(poi, rng) and entry["required"]:
			failures.append("poi %s: fits nowhere" % poi.id)
	if pois.size() < chain.poi_count.x or pois.size() > chain.poi_count.y:
		failures.append("pois: %d placed, not %d-%d" % [pois.size(), chain.poi_count.x, chain.poi_count.y])


func _anchor_fits(poi: PoiData, cell: Vector2i, band: Vector2i) -> bool:
	var i: int = grid.index_of(cell)
	if _taken.has(i) or walk[i] < 0 or walk[i] < band.x or walk[i] > band.y:
		return false
	if not poi.anchor_terrain.is_empty() and not poi.anchor_terrain.has(terrain[i]):
		return false
	if not _placement_fits(poi.placement, cell):
		return false
	if to_water[i] < poi.anchor_min_water_tiles:
		return false
	if poi.needs_shoreline_access and not _beside(cell, [T.SHALLOWS]):
		return false
	for placed: Dictionary in pois:
		if _squared(placed["anchor"], cell) < poi.min_distance_tiles * poi.min_distance_tiles:
			return false
	return true


func _placement_fits(placement: DataEnums.Placement, cell: Vector2i) -> bool:
	var i: int = grid.index_of(cell)
	match placement:
		DataEnums.Placement.ANY_LAND:
			return is_land(cell)
		DataEnums.Placement.BEACH:
			return terrain[i] == T.BEACH
		DataEnums.Placement.INTERIOR:
			return is_land(cell) and to_water[i] > shore_width
		DataEnums.Placement.SHORELINE:
			return is_land(cell) and to_water[i] == 1
		DataEnums.Placement.SHALLOWS:
			return terrain[i] == T.SHALLOWS
	return false


func _place_poi(poi: PoiData, rng: RandomNumberGenerator) -> bool:
	var band := Vector2i(0, IslandGrid.FAR)
	if chain.poi_walk_s.has(poi.id):
		band = walk_band(chain.poi_walk_s[poi.id])
	var candidates: Array[Vector2i] = []
	for i: int in terrain.size():
		var cell: Vector2i = grid.cell_of(i)
		if _anchor_fits(poi, cell, band):
			candidates.append(cell)
	for attempt: int in mini(ANCHOR_TRIES, candidates.size()):
		var anchor: Vector2i = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
		var pieces: Dictionary = _pieces(poi, anchor, rng)
		if pieces.is_empty():
			continue
		_commit(poi, anchor, pieces)
		return true
	return false


# The POI's pieces round `anchor`, or {} when one does not fit. Nothing is taken yet.
func _pieces(poi: PoiData, anchor: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var taken: Dictionary[int, bool] = _taken.duplicate()
	var shade: Array[Vector2i] = []
	if poi.shade_tiles >= 0:
		for dy: int in range(-poi.shade_tiles, poi.shade_tiles + 1):
			for dx: int in range(-poi.shade_tiles, poi.shade_tiles + 1):
				var cell: Vector2i = anchor + Vector2i(dx, dy)
				if not is_land(cell) or taken.has(grid.index_of(cell)) or not _reached(cell):
					return {}
				shade.append(cell)
		for cell: Vector2i in shade:
			if cell != anchor:
				taken[grid.index_of(cell)] = true
	var found: Array[Dictionary] = []
	if not poi.water_item_id.is_empty() and poi.water_capacity_cups > 0:
		found.append({
			"cell": anchor, "item_id": poi.water_item_id, "count": poi.water_capacity_cups,
			"respawn": _water_respawn(poi.water_refill), "group": poi.id, "scaling": 1.0,
		})
		taken[grid.index_of(anchor)] = true
	var grove: Array[Vector2i] = []
	var nuts: int = 0
	if poi.palm_count.y > 0:
		var count: int = rng.randi_range(poi.palm_count.x, poi.palm_count.y)
		nuts = rng.randi_range(poi.palm_coconuts.x, poi.palm_coconuts.y)
		var fits := func(cell: Vector2i) -> bool:
			return _at(cell) == poi.palm_terrain and _squared(cell, anchor) <= poi.palm_within_tiles * poi.palm_within_tiles
		grove = _pick_cells(count, poi.palm_apart_tiles, anchor, poi.palm_within_tiles, fits, taken, rng)
		if grove.size() < count:
			return {}
	for entry: SpawnEntryData in poi.loot:
		var laid: Dictionary = _lay_entry(entry, poi.id, anchor, false, taken, rng)
		if not laid["ok"]:
			return {}
		found.append_array(laid["pickups"])
	return {"shade": shade, "pickups": found, "palms": grove, "coconuts": nuts, "taken": taken}


func _commit(poi: PoiData, anchor: Vector2i, pieces: Dictionary) -> void:
	pois.append({"id": poi.id, "anchor": anchor})
	_taken = pieces["taken"]
	shaded.append_array(pieces["shade"])
	pickups.append_array(pieces["pickups"])
	var grove: Array[Vector2i] = pieces["palms"]
	if not grove.is_empty():
		palms.append_array(grove)
		coconuts += pieces["coconuts"]
		if climb_poi.is_empty():
			climb_poi = poi.id


static func _water_respawn(refill: PoiData.WaterRefill) -> DataEnums.RespawnTrigger:
	match refill:
		PoiData.WaterRefill.DAILY:
			return DataEnums.RespawnTrigger.DAILY
		PoiData.WaterRefill.RAIN:
			return DataEnums.RespawnTrigger.RAIN
	return DataEnums.RespawnTrigger.NEVER


# One entry's pick-ups, all its cells or none: {ok: false} when they do not fit, {ok: true,
# pickups} otherwise (none when its chance roll fails). `ambient` ignores the anchor. Marks the
# cells taken.
func _lay_entry(entry: SpawnEntryData, poi_id: StringName, anchor: Vector2i, ambient: bool, taken: Dictionary[int, bool], rng: RandomNumberGenerator) -> Dictionary:
	var laid: Array[Dictionary] = []
	if entry.kind != SpawnEntryData.Kind.ITEM:
		return {"ok": false, "pickups": laid}
	if not IslandSeeds.roll(rng, entry.chance):
		return {"ok": true, "pickups": laid}
	var units: int = rng.randi_range(entry.count.x, entry.count.y)
	if units <= 0:
		return {"ok": true, "pickups": laid}
	var per_cell: int = maxi(1, entry.per_cell)
	var cells_needed: int = ceili(float(units) / float(per_cell))
	var fits := func(cell: Vector2i) -> bool:
		var kind: int = _at(cell)
		if entry.on_terrain.is_empty():
			if not LAND_TERRAIN.has(kind):
				return false
		elif not entry.on_terrain.has(kind):
			return false
		if not entry.beside_terrain.is_empty() and not _beside(cell, entry.beside_terrain):
			return false
		if ambient:
			return true
		if entry.within_tiles <= 0:
			return cell == anchor
		return _squared(cell, anchor) <= entry.within_tiles * entry.within_tiles
	var cells: Array[Vector2i] = _pick_cells(cells_needed, entry.apart_tiles, anchor, -1 if ambient else entry.within_tiles, fits, taken, rng)
	if cells.size() < cells_needed:
		return {"ok": false, "pickups": laid}
	var group: StringName = entry.group if not entry.group.is_empty() else poi_id
	for k: int in cells.size():
		var count: int = per_cell if k < cells.size() - 1 else units - per_cell * (cells.size() - 1)
		laid.append({
			"cell": cells[k], "item_id": entry.ref_id, "count": count, "respawn": entry.respawn,
			"group": group, "scaling": entry.party_scaling_per_extra_player,
		})
	return {"ok": true, "pickups": laid}


# Up to `count` reachable, untaken cells passing `fits`, each at least `apart` tiles from the others
# picked, by seeded draws; the cells are marked taken. `within` < 0 scans the whole grid.
func _pick_cells(count: int, apart: int, anchor: Vector2i, within: int, fits: Callable, taken: Dictionary[int, bool], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var pool: Array[Vector2i] = []
	if within < 0:
		for i: int in terrain.size():
			var cell: Vector2i = grid.cell_of(i)
			if not taken.has(i) and walk[i] >= 0 and fits.call(cell):
				pool.append(cell)
	else:
		for y: int in range(anchor.y - within, anchor.y + within + 1):
			for x: int in range(anchor.x - within, anchor.x + within + 1):
				var cell := Vector2i(x, y)
				if not grid.has(cell):
					continue
				var i: int = grid.index_of(cell)
				if not taken.has(i) and walk[i] >= 0 and fits.call(cell):
					pool.append(cell)
	var picked: Array[Vector2i] = []
	while picked.size() < count and not pool.is_empty():
		var cell: Vector2i = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		picked.append(cell)
		taken[grid.index_of(cell)] = true
		if apart > 0:
			var kept: Array[Vector2i] = []
			for other: Vector2i in pool:
				if _squared(other, cell) >= apart * apart:
					kept.append(other)
			pool = kept
	return picked


# Step 13.
func _place_ambient(rng: RandomNumberGenerator) -> void:
	for entry: SpawnEntryData in chain.ambient_resources:
		var laid: Dictionary = _lay_entry(entry, &"ambient", Vector2i.ZERO, true, _taken, rng)
		if not laid["ok"]:
			failures.append("ambient %s: no room" % entry.ref_id)
		pickups.append_array(laid["pickups"])


# Step 14: the guaranteed rows, then weighted picks until the rolled count.
func _roll_routes(rng: RandomNumberGenerator) -> void:
	var rest: Array[ChainRouteEntryData] = []
	for row: ChainRouteEntryData in chain.routes:
		if row.guaranteed:
			routes.append(row.route_id)
		else:
			rest.append(row)
	var wanted: int = rng.randi_range(chain.route_count.x, chain.route_count.y)
	while routes.size() < wanted and not rest.is_empty():
		var total: int = 0
		for row: ChainRouteEntryData in rest:
			total += maxi(0, roundi(row.weight * 1000.0))
		if total <= 0:
			break
		var draw: int = rng.randi_range(0, total - 1)
		for k: int in rest.size():
			draw -= maxi(0, roundi(rest[k].weight * 1000.0))
			if draw < 0:
				routes.append(rest[k].route_id)
				rest.remove_at(k)
				break
