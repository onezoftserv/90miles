extends GutTest
## island-generator design §4: the integer grid helpers on small inline grids, checked against
## hand counts.

const T := DataEnums.Terrain


# A grid from rows of "#" (1) and "." (0).
func _mask(rows: Array[String]) -> IslandGrid:
	return IslandGrid.new(rows[0].length(), rows.size())


func _values(rows: Array[String]) -> PackedInt32Array:
	var values := PackedInt32Array()
	for row: String in rows:
		for k: int in row.length():
			values.append(1 if row[k] == "#" else 0)
	return values


func test_chebyshev_rings_to_water() -> void:
	var rows: Array[String] = [
		".......",
		".#####.",
		".#####.",
		".#####.",
		".......",
	]
	var grid := _mask(rows)
	var land := _values(rows)
	var water := grid.filled(0)
	for i: int in land.size():
		water[i] = 1 - land[i]
	var rings: PackedInt32Array = grid.chebyshev_from(water)
	assert_eq(rings[grid.index_of(Vector2i(0, 0))], 0, "water is 0")
	assert_eq(rings[grid.index_of(Vector2i(1, 1))], 1, "a corner of the land")
	assert_eq(rings[grid.index_of(Vector2i(3, 2))], 2, "the middle")
	assert_eq(rings[grid.index_of(Vector2i(2, 2))], 2, "a diagonal ring counts as one step")


func test_squared_distance_inside_a_window() -> void:
	var rows: Array[String] = [
		"#......",
		".......",
		".......",
		"......#",
	]
	var grid := _mask(rows)
	var sources := _values(rows)
	assert_eq(grid.nearest_squared(sources, Vector2i(2, 1), 3), 5, "(0, 0) is 2² + 1² away")
	assert_eq(grid.nearest_squared(sources, Vector2i(4, 2), 3), 5, "(6, 3) is 2² + 1² away")
	assert_eq(grid.nearest_squared(sources, Vector2i(3, 0), 2), -1, "nothing inside a radius of 2")
	assert_eq(grid.nearest_squared(sources, Vector2i(3, 0), 2, true), 1, "the edge counts when asked")


func test_bodies_are_four_connected_and_the_largest_wins() -> void:
	var rows: Array[String] = [
		"##..#",
		"##...",
		"..#..",
		"..###",
	]
	var grid := _mask(rows)
	var bodies: Dictionary = grid.label_bodies(_values(rows))
	var sizes: PackedInt32Array = bodies["sizes"]
	assert_eq(sizes, PackedInt32Array([4, 1, 4]), "a diagonal touch does not join two bodies")
	assert_eq(bodies["largest"], 0, "the first of the largest, in reading order")
	var labels: PackedInt32Array = bodies["labels"]
	assert_eq(labels[grid.index_of(Vector2i(2, 2))], 2)
	assert_eq(labels[grid.index_of(Vector2i(4, 3))], 2)
	assert_eq(labels[grid.index_of(Vector2i(2, 0))], -1)


func _terrain(rows: Array[String]) -> Dictionary:
	var kinds: Dictionary[String, int] = {".": T.BEACH, "-": T.SHALLOWS, "~": T.DEEP}
	var grid := IslandGrid.new(rows[0].length(), rows.size())
	var terrain := PackedInt32Array()
	for row: String in rows:
		for k: int in row.length():
			terrain.append(kinds[row[k]])
	return {"grid": grid, "walkable": grid.mask_of(terrain, IslandLayout.WALKABLE)}


func test_the_chamfer_walk_counts_half_tiles() -> void:
	var made: Dictionary = _terrain([
		".....",
		".....",
		".....",
	])
	var grid: IslandGrid = made["grid"]
	var walk: PackedInt32Array = grid.chamfer_walk(made["walkable"], Vector2i(0, 0))
	assert_eq(walk[grid.index_of(Vector2i(4, 0))], 8, "four orthogonal steps")
	assert_eq(walk[grid.index_of(Vector2i(2, 2))], 6, "two diagonal steps")
	assert_eq(walk[grid.index_of(Vector2i(4, 2))], 10, "two diagonals and two straight")


func test_the_chamfer_walk_wades_cuts_no_corner_and_never_swims() -> void:
	var made: Dictionary = _terrain([
		".~...",
		"..~~.",
		"--~..",
		".-~~~",
	])
	var grid: IslandGrid = made["grid"]
	var walk: PackedInt32Array = grid.chamfer_walk(made["walkable"], Vector2i(0, 0))
	assert_eq(walk[grid.index_of(Vector2i(1, 3))], 7, "down two, then a diagonal through the shallows")
	assert_eq(walk[grid.index_of(Vector2i(2, 0))], -1, "no diagonal past the deep cell at (1, 0) and (2, 1)")
	assert_eq(walk[grid.index_of(Vector2i(4, 0))], -1, "deep water is never walked")
	assert_eq(walk[grid.index_of(Vector2i(1, 0))], -1, "the deep cell itself")
