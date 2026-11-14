extends GutTest
## crossing "Arrival scatter" and "Arrival scatter fallback" (vessel-car-board design D7), pure: the
## cells the host picks on the coast cay's built layout for riders by their route's scatter, and on
## a fixture beach too small for four boards.

const BOARD: Vector2i = Vector2i(10, 20)
const DEFAULT: Vector2i = Vector2i(0, 5)
const SEED: int = 4242

var built: IslandLayout


func before_each() -> void:
	built = IslandLayout.build(load("res://resources/islands/coast_cay.tres") as IslandLayoutData)


func _distance(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a - b).length()


func _scatter(list: Array) -> Dictionary[int, Vector2i]:
	var scatter: Dictionary[int, Vector2i] = {}
	for index: int in list.size():
		scatter[index + 1] = list[index]
	return scatter


# A beach of one row of seven cells, the landing cell at its west end.
func _small_beach() -> IslandLayout:
	var data := IslandLayoutData.new()
	data.rows = PackedStringArray(["~~~~~~~~~~", "~1......~~", "~~~~~~~~~~"])
	data.terrain_glyphs = {"~": DataEnums.Terrain.DEEP, ".": DataEnums.Terrain.BEACH, "1": DataEnums.Terrain.BEACH}
	data.solo_spawn_glyph = "1"
	data.coop_spawn_glyphs = "1"
	return IslandLayout.build(data)


func test_a_solo_board_rider_takes_the_first_landing_cell() -> void:
	var cells := ArrivalScatter.pick(built, _scatter([BOARD]), SEED)
	assert_eq(cells.size(), 1)
	assert_eq(cells.get(1), built.landing_cells()[0])


func test_three_board_riders_land_apart_on_reachable_beach() -> void:
	var cells := ArrivalScatter.pick(built, _scatter([BOARD, BOARD, BOARD]), SEED)
	assert_eq(cells.size(), 3)
	var reachable := built.reachable_from(built.landing_cells()[0])
	for peer: int in cells:
		assert_eq(built.terrain.cells.get(cells[peer]), DataEnums.Terrain.BEACH, "rider %d on the beach" % peer)
		assert_true(reachable.has(cells[peer]), "rider %d reachable on foot" % peer)
	for pair: Array in [[1, 2], [1, 3], [2, 3]]:
		var apart: float = _distance(cells[pair[0]], cells[pair[1]])
		assert_between(apart, 10.0, 20.0, "riders %d and %d are %.1f tiles apart" % [pair[0], pair[1], apart])


func test_the_same_seed_lands_the_same_and_another_seed_elsewhere() -> void:
	var first := ArrivalScatter.pick(built, _scatter([BOARD, BOARD, BOARD]), SEED)
	assert_eq(ArrivalScatter.pick(built, _scatter([BOARD, BOARD, BOARD]), SEED), first, "the same cells")
	var differs: bool = false
	for other: int in range(1, 6):
		if ArrivalScatter.pick(built, _scatter([BOARD, BOARD, BOARD]), SEED + other) != first:
			differs = true
	assert_true(differs, "another seed lands them elsewhere")


func test_a_raft_party_and_a_board_rider() -> void:
	var cells := ArrivalScatter.pick(built, _scatter([DEFAULT, DEFAULT, BOARD]), SEED)
	var landing := built.landing_cells()
	assert_eq(cells[1], landing[0], "the raft riders on the landing cells")
	assert_eq(cells[2], landing[1])
	assert_eq(built.terrain.cells.get(cells[3]), DataEnums.Terrain.BEACH)
	for raft_rider: int in [1, 2]:
		assert_between(_distance(cells[3], cells[raft_rider]), 10.0, 20.0, "the board rider 10-20 tiles from rider %d" % raft_rider)


func test_four_boards_on_a_small_beach_land_on_distinct_cells() -> void:
	var small := _small_beach()
	var cells := ArrivalScatter.pick(small, _scatter([BOARD, BOARD, BOARD, BOARD]), SEED)
	assert_eq(cells.size(), 4)
	var seen: Dictionary[Vector2i, bool] = {}
	for peer: int in cells:
		assert_eq(small.terrain.cells.get(cells[peer]), DataEnums.Terrain.BEACH)
		assert_false(seen.has(cells[peer]), "rider %d on a cell of their own" % peer)
		seen[cells[peer]] = true
	assert_eq(cells[1], Vector2i(1, 1), "the first on the landing cell")
	assert_eq(cells[2], Vector2i(7, 1), "the next as far from it as the beach allows")


func test_more_boards_than_beach_cells_stack_on_the_landing_cells() -> void:
	var data := IslandLayoutData.new()
	data.rows = PackedStringArray(["~~~~", "~1.~", "~~~~"])
	data.terrain_glyphs = {"~": DataEnums.Terrain.DEEP, ".": DataEnums.Terrain.BEACH, "1": DataEnums.Terrain.BEACH}
	data.solo_spawn_glyph = "1"
	data.coop_spawn_glyphs = "1"
	var cells := ArrivalScatter.pick(IslandLayout.build(data), _scatter([BOARD, BOARD, BOARD]), SEED)
	assert_eq(cells[1], Vector2i(1, 1))
	assert_eq(cells[2], Vector2i(2, 1), "the free cell first")
	assert_eq(cells[3], Vector2i(1, 1), "then back to the landing cell")


func test_default_scatter_parties_land_as_before() -> void:
	for players: int in range(1, 5):
		var list: Array = []
		var ids: Array[int] = []
		for index: int in players:
			list.append(DEFAULT)
			ids.append(index + 1)
		var cells := ArrivalScatter.pick(built, _scatter(list), SEED)
		var before := IslandArrival.landing_positions(built, ids)
		for peer: int in ids:
			assert_eq(IslandLayout.cell_center(cells[peer]), before[peer], "%d players: rider %d" % [players, peer])


func test_only_a_wider_scatter_scatters() -> void:
	assert_false(ArrivalScatter.is_wide(DEFAULT))
	assert_false(ArrivalScatter.is_wide(Vector2i(0, 3)))
	assert_true(ArrivalScatter.is_wide(BOARD))
	assert_true(ArrivalScatter.is_wide(Vector2i(0, 8)))


func test_nobody_lands_on_the_islands_furniture() -> void:
	var furnished: Array[Vector2i] = []
	furnished.append_array(built.palms)
	furnished.append_array(built.drink_spots)
	furnished.append(built.raft_site)
	for entry: Dictionary in built.signs:
		furnished.append(entry["cell"])
	var beach := ArrivalScatter.beach_cells(built, built.landing_cells()[0])
	for cell: Vector2i in furnished:
		assert_false(beach.has(cell), "%s is no landing spot" % cell)
	for seed_value: int in 50:
		var cells := ArrivalScatter.pick(built, _scatter([BOARD, BOARD, BOARD, BOARD]), seed_value)
		for peer: int in cells:
			assert_false(furnished.has(cells[peer]), "seed %d: rider %d not on a palm, the raft site, a spring or a sign" % [seed_value, peer])


func test_three_and_four_boards_fit_on_the_coast_cay_for_every_seed() -> void:
	for riders: int in [3, 4]:
		var list: Array = []
		for index: int in riders:
			list.append(BOARD)
		for seed_value: int in 100:
			var cells := ArrivalScatter.pick(built, _scatter(list), seed_value)
			for a: int in cells:
				for b: int in cells:
					if a < b:
						assert_between(_distance(cells[a], cells[b]), 10.0, 20.0, "%d riders, seed %d: riders %d and %d" % [riders, seed_value, a, b])


func test_a_dead_rider_anchors_no_board_rider() -> void:
	var landing := built.landing_cells()
	var cells := ArrivalScatter.pick(built, _scatter([DEFAULT, BOARD]), SEED, [1] as Array[int])
	assert_eq(cells[1], landing[0], "the dead keep the first landing cell")
	assert_eq(cells[2], landing[1], "the lone survivor takes the next landing cell, not a cell 10-20 tiles from a body")
	var three := ArrivalScatter.pick(built, _scatter([DEFAULT, BOARD, BOARD]), SEED, [1] as Array[int])
	assert_eq(three[2], landing[1])
	assert_between(_distance(three[2], three[3]), 10.0, 20.0, "the living scatter from each other")
