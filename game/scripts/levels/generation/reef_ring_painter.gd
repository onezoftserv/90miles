class_name ReefRingPainter
extends RefCounted
## The REEF_RING painter (island-generator design §4 steps 2–8): one long landmass round a bent
## spine, its sea level set by rank so the land count is exact, cleaned to one 4-connected body,
## ringed by shallows, a rock shore with a beach on the lee and rock patches in the scrub.
## Integer maths only: no trigonometry, no float decisions.

const T := DataEnums.Terrain
## Spine directions, one per 22.5° notch, starting east and turning clockwise on screen.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(3, 0), Vector2i(3, 1), Vector2i(2, 2), Vector2i(1, 3),
	Vector2i(0, 3), Vector2i(-1, 3), Vector2i(-2, 2), Vector2i(-3, 1),
	Vector2i(-3, 0), Vector2i(-3, -1), Vector2i(-2, -2), Vector2i(-1, -3),
	Vector2i(0, -3), Vector2i(1, -3), Vector2i(2, -2), Vector2i(3, -1),
]
const STEP_TILES: int = 3
## Single-cell bumps that roughen the coast.
const BUMPS: int = 24
const BUMP_RADIUS: int = 3
## The height at a bump's centre: a quarter of a spine cap's, enough to wobble the coast.
const BUMP_PEAK: int = 256
## The height at a cap's centre.
const CAP_PEAK: int = 1024
## Each spine point's cap reaches this far past its half-width, so the coast the rank cut finds
## lies inside the caps, not on flat zero-height ground.
const CAP_EXTRA_TILES: int = 6
const SMOOTHING_PASSES: int = 2
const LAKE_FILL_CELLS: int = 12
const CLEANUP_PASSES: int = 20
const CLUSTER_PASSES: int = 2
## Rock may end this far from its weight (a share of the interior).
const ROCK_TOLERANCE: float = 0.05


## Paints one attempt. Returns {terrain: PackedInt32Array of DataEnums.Terrain, grid: IslandGrid,
## land_target: int, land_count: int, shore_width: int, to_water: PackedInt32Array (Chebyshev
## distance of each cell to water), lee_coast: PackedInt32Array (1 on lee coast cells),
## failures: PackedStringArray}.
static func paint(chain: ChainData, land_rng: RandomNumberGenerator, bands_rng: RandomNumberGenerator) -> Dictionary:
	var grid := IslandGrid.new(chain.grid_size.x, chain.grid_size.y)
	var failures := PackedStringArray()
	var spine: Dictionary = _heights(chain, grid, land_rng)
	var heights: PackedInt32Array = spine["heights"]
	var target: int = _land_target(chain, grid, land_rng)
	var land: PackedInt32Array = _land_by_rank(chain, grid, heights, target)
	_clean_up(grid, land)
	var land_count: int = 0
	for value: int in land:
		land_count += value
	var terrain := grid.filled(T.DEEP)
	var to_land: PackedInt32Array = grid.chebyshev_from(land)
	var shallows: int = chain.shallows_width_tiles.y
	for i: int in terrain.size():
		if land[i] != 0:
			terrain[i] = T.SCRUB
		elif to_land[i] <= shallows:
			terrain[i] = T.SHALLOWS
	var water := grid.filled(0)
	for i: int in land.size():
		water[i] = 1 - land[i]
	var to_water: PackedInt32Array = grid.chebyshev_from(water)
	var shore_width: int = bands_rng.randi_range(chain.beach_width_tiles.x, chain.beach_width_tiles.y)
	var lee_coast: PackedInt32Array = _lee_coast(chain, grid, land, to_water)
	_paint_shore(chain, grid, terrain, land, to_water, lee_coast, shore_width)
	_paint_interior(chain, grid, terrain, land, to_water, shore_width, bands_rng)
	return {
		"terrain": terrain, "grid": grid, "land_target": target, "land_count": land_count,
		"shore_width": shore_width, "spine_tiles": spine["spine_tiles"], "rolled_tiles": spine["rolled_tiles"], "to_water": to_water, "lee_coast": lee_coast, "failures": failures,
	}


# Steps 2–3: the spine and its heights.
static func _heights(chain: ChainData, grid: IslandGrid, rng: RandomNumberGenerator) -> Dictionary:
	var length: int = rng.randi_range(chain.shape_length_tiles.x, chain.shape_length_tiles.y)
	var bend: int = rng.randi_range(chain.shape_bend_degrees.x, chain.shape_bend_degrees.y)
	var notches: int = (bend * 10 + 112) / 225
	var turn: int = 1 if rng.randi_range(0, 1) == 0 else -1
	var steps: int = maxi(1, length / STEP_TILES)
	# Along the long axis: start half the bend back from east, so the chord lies east-west.
	var base: int = 0 if grid.width >= grid.height else 4
	var direction: int = posmod(base - turn * ((notches + 1) / 2), DIRECTIONS.size())
	var turn_at: Array[int] = []
	while turn_at.size() < mini(notches, steps - 1):
		var at: int = rng.randi_range(1, steps - 1)
		if not turn_at.has(at):
			turn_at.append(at)
	var half_widths: Vector2i = chain.shape_half_width_tiles
	var half_width: int = rng.randi_range(half_widths.x, half_widths.y)
	var points: Array[Vector2i] = [Vector2i.ZERO]
	var widths: Array[int] = [half_width]
	for step: int in range(1, steps + 1):
		if turn_at.has(step):
			direction = posmod(direction + turn, DIRECTIONS.size())
		points.append(points[points.size() - 1] + DIRECTIONS[direction])
		half_width = clampi(half_width + rng.randi_range(-1, 1), half_widths.x, half_widths.y)
		widths.append(half_width)
	_fit(chain, grid, points, widths)
	var heights := grid.filled(0)
	for i: int in points.size():
		_add_cap(grid, heights, points[i], widths[i] + CAP_EXTRA_TILES, 0, CAP_PEAK)
	for bump: int in BUMPS:
		var at: int = rng.randi_range(0, points.size() - 1)
		var reach: int = widths[at] + 2
		var offset := Vector2i(rng.randi_range(-reach, reach), rng.randi_range(-reach, reach))
		_add_cap(grid, heights, points[at] + offset, BUMP_RADIUS, 1, BUMP_PEAK)
	for i: int in SMOOTHING_PASSES:
		heights = _smooth(grid, heights)
	return {"heights": heights, "spine_tiles": (points.size() - 1) * STEP_TILES, "rolled_tiles": length}


# Drops spine points from the end until the spine and its widths fit inside the margin, then
# centres it.
static func _fit(chain: ChainData, grid: IslandGrid, points: Array[Vector2i], widths: Array[int]) -> void:
	var margin: int = chain.edge_margin_tiles
	var room := Vector2i(grid.width - 2 * margin, grid.height - 2 * margin)
	while true:
		var low := Vector2i(IslandGrid.FAR, IslandGrid.FAR)
		var high := Vector2i(-IslandGrid.FAR, -IslandGrid.FAR)
		for i: int in points.size():
			low = Vector2i(mini(low.x, points[i].x - widths[i]), mini(low.y, points[i].y - widths[i]))
			high = Vector2i(maxi(high.x, points[i].x + widths[i]), maxi(high.y, points[i].y + widths[i]))
		var span: Vector2i = high - low + Vector2i.ONE
		if span.x <= room.x and span.y <= room.y or points.size() <= 2:
			var shift: Vector2i = Vector2i(margin, margin) + (room - span) / 2 - low
			for i: int in points.size():
				points[i] += shift
			return
		points.pop_back()
		widths.pop_back()


# A rounded cap of (radius² − distance²) × peak / radius² round `center`: the same peak for every
# radius, so a wider point makes the land wider, not taller. `add` 1 adds it (bumps); 0 keeps the
# higher of the cap and the height already there (the spine), so the height is a distance field
# from the spine and the land keeps one width from end to end.
static func _add_cap(grid: IslandGrid, heights: PackedInt32Array, center: Vector2i, radius: int, add: int, peak: int) -> void:
	var squared: int = maxi(1, radius * radius)
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var d: int = dx * dx + dy * dy
			var cell := Vector2i(center.x + dx, center.y + dy)
			if d > squared or not grid.has(cell):
				continue
			var i: int = grid.index_of(cell)
			var value: int = (squared - d) * peak / squared
			heights[i] = heights[i] + value if add != 0 else maxi(heights[i], value)


# The weighted mean of each 3×3, centre weight 2.
static func _smooth(grid: IslandGrid, heights: PackedInt32Array) -> PackedInt32Array:
	var out := grid.filled(0)
	for y: int in grid.height:
		for x: int in grid.width:
			var total: int = heights[y * grid.width + x]
			var weight: int = 1
			for dy: int in range(-1, 2):
				var yy: int = y + dy
				if yy < 0 or yy >= grid.height:
					continue
				for dx: int in range(-1, 2):
					var xx: int = x + dx
					if xx < 0 or xx >= grid.width:
						continue
					total += heights[yy * grid.width + xx]
					weight += 1
			out[y * grid.width + x] = total / weight
	return out


# Step 4: the land count, inside both land_cells and land_fraction.
static func _land_target(chain: ChainData, grid: IslandGrid, rng: RandomNumberGenerator) -> int:
	var cells: int = grid.cell_count()
	var low: int = ceili(chain.land_fraction.x * cells)
	var high: int = floori(chain.land_fraction.y * cells)
	if chain.land_cells.y > 0:
		low = maxi(low, chain.land_cells.x)
		high = mini(high, chain.land_cells.y)
	return rng.randi_range(low, maxi(low, high))


# Step 4: the `target` highest cells inside the margin are land (ties by reading order).
static func _land_by_rank(chain: ChainData, grid: IslandGrid, heights: PackedInt32Array, target: int) -> PackedInt32Array:
	var margin: int = chain.edge_margin_tiles
	var keys := PackedInt64Array()
	for y: int in range(margin, grid.height - margin):
		for x: int in range(margin, grid.width - margin):
			var i: int = y * grid.width + x
			keys.append(-int(heights[i]) * 65536 + i)
	keys.sort()
	var land := grid.filled(0)
	for k: int in mini(target, keys.size()):
		land[posmod(keys[k], 65536)] = 1
	return land


# Step 5: one 4-connected body, small lakes filled, spurs and corner-only touches removed.
static func _clean_up(grid: IslandGrid, land: PackedInt32Array) -> void:
	for pass_index: int in CLEANUP_PASSES:
		var changed: bool = false
		var bodies: Dictionary = grid.label_bodies(land)
		var labels: PackedInt32Array = bodies["labels"]
		for i: int in land.size():
			if land[i] != 0 and labels[i] != bodies["largest"]:
				land[i] = 0
				changed = true
		changed = _fill_lakes(grid, land) or changed
		for y: int in grid.height:
			for x: int in grid.width:
				var i: int = y * grid.width + x
				if land[i] == 0:
					continue
				var neighbours: int = 0
				for step: Vector2i in IslandGrid.ORTHOGONAL:
					var next := Vector2i(x, y) + step
					if grid.has(next) and land[grid.index_of(next)] != 0:
						neighbours += 1
				if neighbours <= 1:
					land[i] = 0
					changed = true
		changed = _open_diagonals(grid, land) or changed
		if not changed:
			return


# Water bodies that do not touch the grid's edge and are smaller than LAKE_FILL_CELLS become land.
static func _fill_lakes(grid: IslandGrid, land: PackedInt32Array) -> bool:
	var water := grid.filled(0)
	for i: int in land.size():
		water[i] = 1 - land[i]
	var bodies: Dictionary = grid.label_bodies(water)
	var labels: PackedInt32Array = bodies["labels"]
	var sizes: PackedInt32Array = bodies["sizes"]
	var edge: Dictionary[int, bool] = {}
	for x: int in grid.width:
		edge[labels[x]] = true
		edge[labels[(grid.height - 1) * grid.width + x]] = true
	for y: int in grid.height:
		edge[labels[y * grid.width]] = true
		edge[labels[y * grid.width + grid.width - 1]] = true
	var changed: bool = false
	for i: int in land.size():
		var label: int = labels[i]
		if label >= 0 and not edge.has(label) and sizes[label] < LAKE_FILL_CELLS:
			land[i] = 1
			changed = true
	return changed


# A 2×2 block with land on one diagonal and water on the other becomes all land.
static func _open_diagonals(grid: IslandGrid, land: PackedInt32Array) -> bool:
	var changed: bool = false
	for y: int in grid.height - 1:
		for x: int in grid.width - 1:
			var a: int = y * grid.width + x
			var b: int = a + 1
			var c: int = a + grid.width
			var d: int = c + 1
			if land[a] == land[d] and land[b] == land[c] and land[a] != land[b]:
				land[a] = 1
				land[b] = 1
				land[c] = 1
				land[d] = 1
				changed = true
	return changed


# Step 7: a coast cell (land at Chebyshev 1 from water) is a lee coast cell when its ray in the lee
# direction reaches the grid's edge over water only. (With any of three rays, west, north-west or
# south-west, nearly every coast was lee; with all three, too little beach was left for the
# driftwood and the flotsam.)
static func _lee_coast(chain: ChainData, grid: IslandGrid, land: PackedInt32Array, to_water: PackedInt32Array) -> PackedInt32Array:
	var lee := grid.filled(0)
	var ray := Vector2i(signi(chain.lee_facing.x), signi(chain.lee_facing.y))
	for i: int in land.size():
		if land[i] == 0 or to_water[i] != 1:
			continue
		var cell: Vector2i = grid.cell_of(i) + ray
		var open: bool = true
		while open and grid.has(cell):
			open = land[grid.index_of(cell)] == 0
			cell += ray
		if open:
			lee[i] = 1
	return lee


## Shore cells (land within `shore_width` of water) within `shore_width` steps of a lee coast
## cell, walking 8-way over shore cells only: 1 on those cells.
static func lee_shore(grid: IslandGrid, land: PackedInt32Array, to_water: PackedInt32Array, lee_coast: PackedInt32Array, shore_width: int) -> PackedInt32Array:
	var steps := grid.filled(IslandGrid.FAR)
	var queue := PackedInt32Array()
	for i: int in lee_coast.size():
		if lee_coast[i] != 0:
			steps[i] = 0
			queue.append(i)
	var head: int = 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		if steps[i] >= shore_width:
			continue
		for step: Vector2i in IslandGrid.EIGHT:
			var next: Vector2i = grid.cell_of(i) + step
			if not grid.has(next):
				continue
			var j: int = grid.index_of(next)
			if land[j] == 0 or to_water[j] > shore_width or steps[j] != IslandGrid.FAR:
				continue
			steps[j] = steps[i] + 1
			queue.append(j)
	var out := grid.filled(0)
	for i: int in steps.size():
		if steps[i] <= shore_width:
			out[i] = 1
	return out


static func _paint_shore(chain: ChainData, grid: IslandGrid, terrain: PackedInt32Array, land: PackedInt32Array, to_water: PackedInt32Array, lee_coast: PackedInt32Array, shore_width: int) -> void:
	var lee: PackedInt32Array = lee_shore(grid, land, to_water, lee_coast, shore_width)
	for i: int in terrain.size():
		if land[i] != 0 and to_water[i] <= shore_width:
			terrain[i] = chain.lee_terrain if lee[i] != 0 else chain.shore_terrain


# Step 8: rock patches in the scrub beyond the shore band, at the rock weight within tolerance.
static func _paint_interior(chain: ChainData, grid: IslandGrid, terrain: PackedInt32Array, land: PackedInt32Array, to_water: PackedInt32Array, shore_width: int, rng: RandomNumberGenerator) -> void:
	var inside := grid.filled(0)
	var interior: int = 0
	for i: int in land.size():
		if land[i] != 0 and to_water[i] > shore_width:
			inside[i] = 1
			interior += 1
	if interior == 0:
		return
	var weight: float = rock_weight(chain)
	var rock := grid.filled(0)
	for i: int in inside.size():
		if inside[i] != 0 and IslandSeeds.roll(rng, weight):
			rock[i] = 1
	for pass_index: int in CLUSTER_PASSES:
		rock = _cluster(grid, inside, rock)
	var low: int = ceili((weight - ROCK_TOLERANCE) * interior)
	var high: int = floori((weight + ROCK_TOLERANCE) * interior)
	var count: int = 0
	for value: int in rock:
		count += value
	if count == 0 and low > 0:
		for i: int in inside.size():
			if inside[i] != 0:
				rock[i] = 1
				count = 1
				break
	var guard: int = 0
	while (count < low or count > high) and guard < 200:
		guard += 1
		var grow: bool = count < low
		var before: int = count
		# One ring per sweep, read from the sweep's start, so every patch grows or shrinks evenly.
		var start: PackedInt32Array = rock.duplicate()
		for i: int in inside.size():
			if inside[i] == 0 or (rock[i] != 0) == grow:
				continue
			if not _touches(grid, inside, start, i, 1 if grow else 0):
				continue
			rock[i] = 1 if grow else 0
			count += 1 if grow else -1
			if grow and count >= low or not grow and count <= high:
				break
		if count == before:
			break
	for i: int in inside.size():
		if inside[i] != 0:
			terrain[i] = T.ROCK if rock[i] != 0 else T.SCRUB


## Rock's share of the interior from the chain's biome weights.
static func rock_weight(chain: ChainData) -> float:
	var total: float = 0.0
	for weight: float in chain.biome_weights.values():
		total += weight
	if total <= 0.0:
		return 0.0
	return chain.biome_weights.get(T.ROCK, 0.0) / total


# One 3×3 majority pass over the interior.
static func _cluster(grid: IslandGrid, inside: PackedInt32Array, rock: PackedInt32Array) -> PackedInt32Array:
	var out := rock.duplicate()
	for i: int in inside.size():
		if inside[i] == 0:
			continue
		var cell: Vector2i = grid.cell_of(i)
		var rocks: int = rock[i]
		var cells: int = 1
		for step: Vector2i in IslandGrid.EIGHT:
			var next: Vector2i = cell + step
			if not grid.has(next) or inside[grid.index_of(next)] == 0:
				continue
			cells += 1
			rocks += rock[grid.index_of(next)]
		if rocks * 2 > cells:
			out[i] = 1
		elif rocks * 2 < cells:
			out[i] = 0
	return out


# Whether cell `i` has a 4-neighbour inside the interior whose rock value is `value`.
static func _touches(grid: IslandGrid, inside: PackedInt32Array, rock: PackedInt32Array, i: int, value: int) -> bool:
	var cell: Vector2i = grid.cell_of(i)
	for step: Vector2i in IslandGrid.ORTHOGONAL:
		var next: Vector2i = cell + step
		if grid.has(next):
			var j: int = grid.index_of(next)
			if inside[j] != 0 and rock[j] == value:
				return true
	return false
