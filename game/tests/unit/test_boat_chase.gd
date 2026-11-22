extends GutTest
## guardacostas-capture, group 4 (design.md §3, spec "Boat chase at sea"): the chase as a pure rule over
## plain values in tiles. The boat closes at 2× the swim speed (6 tiles/s) through deep water only,
## hauls a swimmer aboard after 2 s within 1 tile (the count resets when they leave it), and the chase
## breaks on a dive, in the shallows, on land (which becomes a landing) and past 10 tiles. Ticks are
## 1/60 s, summed to whole seconds.

const TICK: float = 1.0 / 60.0
const TOLERANCE: float = 0.000001
const DEEP := DataEnums.Terrain.DEEP
const SHALLOWS := DataEnums.Terrain.SHALLOWS
const BEACH := DataEnums.Terrain.BEACH

var chase: BoatChase
# Cells that are not deep water, by cell; everything else is deep.
var not_deep: Dictionary[Vector2i, DataEnums.Terrain] = {}


func before_each() -> void:
	var patrol := (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol
	chase = BoatChase.from_patrol(patrol, 0.0)
	not_deep.clear()


func _terrain(cell: Vector2i) -> DataEnums.Terrain:
	return not_deep.get(cell, DEEP)


func _is_deep(cell: Vector2i) -> bool:
	return _terrain(cell) == DEEP


func _cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x), floori(at.y))


# Steps the chase for `seconds` with the swimmer standing at `target`; returns [boat, outcome].
func _run(boat: Vector2, target: Vector2, seconds: float, submerged: bool = false) -> Array:
	var outcome: BoatChase.Outcome = BoatChase.Outcome.CHASING
	for i: int in roundi(seconds / TICK):
		var step := chase.step(boat, target, _terrain(_cell(target)), submerged, TICK, _is_deep)
		boat = step.position
		outcome = step.outcome
		if outcome != BoatChase.Outcome.CHASING:
			break
	return [boat, outcome]


func test_the_numbers_come_from_the_patrol_data() -> void:
	assert_almost_eq(chase.speed_tiles_s, 6.0, TOLERANCE, "2x the 3 tiles/s swim speed")
	assert_almost_eq(chase.haul_tiles, 1.0, TOLERANCE)
	assert_almost_eq(chase.haul_s, 2.0, TOLERANCE)
	assert_almost_eq(chase.break_tiles, 10.0, TOLERANCE)


func test_the_boat_closes_at_6_tiles_per_second() -> void:
	var result := _run(Vector2(0.5, 0.5), Vector2(9.5, 0.5), 1.0)
	assert_eq(result[1], BoatChase.Outcome.CHASING)
	assert_almost_eq((result[0] as Vector2).x, 6.5, 0.0001, "6 tiles in 1 s")


func test_the_boat_moves_through_deep_water_only() -> void:
	# A shallow bar at x = 4 between the boat and a swimmer in deep water beyond it.
	for y: int in range(-20, 21):
		not_deep[Vector2i(4, y)] = SHALLOWS
	var result := _run(Vector2(0.5, 0.5), Vector2(8.5, 0.5), 3.0)
	assert_eq(result[1], BoatChase.Outcome.CHASING, "the swimmer is still in deep water")
	assert_true((result[0] as Vector2).x < 4.0, "the boat stops at the edge of the deep water: %s" % result[0])
	assert_true(_is_deep(_cell(result[0])))


func test_a_swimmer_within_1_tile_for_2_s_is_hauled_aboard() -> void:
	var boat := Vector2(0.5, 0.5)
	var target := Vector2(1.2, 0.5)
	var outcome: BoatChase.Outcome = BoatChase.Outcome.CHASING
	var ticks: int = 0
	while outcome == BoatChase.Outcome.CHASING and ticks < 600:
		var step := chase.step(boat, target, DEEP, false, TICK, _is_deep)
		boat = step.position
		outcome = step.outcome
		ticks += 1
	assert_eq(outcome, BoatChase.Outcome.HAULED)
	assert_almost_eq(ticks * TICK, 2.0, TICK + TOLERANCE, "after 2 s within 1 tile")


func test_the_haul_count_resets_when_the_swimmer_leaves_the_tile() -> void:
	var boat := Vector2(0.5, 0.5)
	# 1.5 s within reach.
	for i: int in 90:
		var step := chase.step(boat, Vector2(1.0, 0.5), DEEP, false, TICK, _is_deep)
		boat = step.position
		assert_eq(step.outcome, BoatChase.Outcome.CHASING)
	assert_almost_eq(chase.touch_s, 1.5, TOLERANCE)
	# The swimmer is 3 tiles off for a tick: the count starts again.
	var away := chase.step(boat, boat + Vector2(3.0, 0.0), DEEP, false, TICK, _is_deep)
	assert_eq(away.outcome, BoatChase.Outcome.CHASING)
	assert_eq(chase.touch_s, 0.0, "contact broke")
	# Back within reach: a fresh 2 s.
	var outcome: BoatChase.Outcome = BoatChase.Outcome.CHASING
	var ticks: int = 0
	boat = away.position
	while outcome == BoatChase.Outcome.CHASING and ticks < 600:
		var step := chase.step(boat, boat + Vector2(0.5, 0.0), DEEP, false, TICK, _is_deep)
		boat = step.position
		outcome = step.outcome
		ticks += 1
	assert_almost_eq(ticks * TICK, 2.0, TICK + TOLERANCE, "a fresh 2 s of contact")


func test_a_dive_breaks_the_chase() -> void:
	var result := _run(Vector2(0.5, 0.5), Vector2(3.5, 0.5), 0.5, true)
	assert_eq(result[1], BoatChase.Outcome.DIVED)


func test_the_shallows_break_the_chase_and_nobody_is_hauled() -> void:
	not_deep[Vector2i(3, 0)] = SHALLOWS
	var result := _run(Vector2(0.5, 0.5), Vector2(3.5, 0.5), 3.0)
	assert_eq(result[1], BoatChase.Outcome.SHALLOWS)


func test_land_breaks_the_chase_as_a_landing() -> void:
	not_deep[Vector2i(3, 0)] = BEACH
	var result := _run(Vector2(0.5, 0.5), Vector2(3.5, 0.5), 3.0)
	assert_eq(result[1], BoatChase.Outcome.LANDED, "the place they came ashore is a land alert")
	assert_true(BoatChase.is_landing(result[1]))
	assert_false(BoatChase.is_landing(BoatChase.Outcome.SHALLOWS))


func test_more_than_10_tiles_breaks_the_chase() -> void:
	assert_eq(_run(Vector2(0.5, 0.5), Vector2(10.5, 0.5), TICK)[1], BoatChase.Outcome.CHASING, "10 tiles is still in reach")
	chase.touch_s = 0.0
	assert_eq(_run(Vector2(0.5, 0.5), Vector2(10.6, 0.5), TICK)[1], BoatChase.Outcome.LOST)


# Spec "Solo swimmer hauled aboard": spotted 6 tiles out, the boat closes and hauls in about 4 s.
func test_a_swimmer_spotted_6_tiles_out_is_hauled_in_about_4_s() -> void:
	var boat := Vector2(0.5, 0.5)
	var target := Vector2(6.5, 0.5)
	var outcome: BoatChase.Outcome = BoatChase.Outcome.CHASING
	var seconds: float = 0.0
	while outcome == BoatChase.Outcome.CHASING and seconds < 10.0:
		# The swimmer swims straight away at 3 tiles/s.
		target += Vector2(3.0 * TICK, 0.0)
		var step := chase.step(boat, target, DEEP, false, TICK, _is_deep)
		boat = step.position
		outcome = step.outcome
		seconds += TICK
	assert_eq(outcome, BoatChase.Outcome.HAULED)
	# 5 tiles to close at 3 tiles/s relative, then 2 s of haul.
	assert_almost_eq(seconds, 5.0 / 3.0 + 2.0, 0.1)
