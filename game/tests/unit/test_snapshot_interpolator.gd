extends GutTest
## coop-networking "Host authority": other players are drawn 100 ms behind the newest host
## state, interpolated between host states.

const TILE: float = 16.0

var interp: SnapshotInterpolator


func before_each() -> void:
	interp = SnapshotInterpolator.new()


func test_delay_is_100_ms() -> void:
	assert_eq(SnapshotInterpolator.DELAY_S, 0.1)


func test_teammate_drawn_between_host_states() -> void:
	interp.push(0.0, Vector2(0.0, 0.0))
	interp.push(0.05, Vector2(1.0 * TILE, 0.0))
	var drawn := interp.sample_delayed(0.125)
	assert_almost_eq(drawn.x / TILE, 0.5, 0.0001)
	assert_almost_eq(drawn.y, 0.0, 0.0001)


func test_before_the_first_state_it_holds_the_first() -> void:
	interp.push(1.0, Vector2(10.0, 0.0))
	interp.push(1.05, Vector2(20.0, 0.0))
	assert_eq(interp.sample(0.5), Vector2(10.0, 0.0))


func test_after_the_newest_state_it_holds_the_newest() -> void:
	interp.push(1.0, Vector2(10.0, 0.0))
	interp.push(1.05, Vector2(20.0, 0.0))
	assert_eq(interp.sample(3.0), Vector2(20.0, 0.0), "no extrapolation")


func test_picks_the_bracketing_pair_among_several() -> void:
	interp.push(0.0, Vector2(0.0, 0.0))
	interp.push(0.05, Vector2(16.0, 0.0))
	interp.push(0.10, Vector2(16.0, 32.0))
	var drawn := interp.sample(0.075)
	assert_almost_eq(drawn.x, 16.0, 0.0001)
	assert_almost_eq(drawn.y, 16.0, 0.0001)


func test_a_state_older_than_the_newest_is_ignored() -> void:
	interp.push(0.0, Vector2(0.0, 0.0))
	interp.push(0.10, Vector2(10.0, 0.0))
	interp.push(0.05, Vector2(99.0, 0.0))
	assert_eq(interp.size(), 2)
	assert_almost_eq(interp.sample(0.05).x, 5.0, 0.0001)


func test_keeps_at_most_max_states() -> void:
	for i: int in SnapshotInterpolator.MAX_STATES + 5:
		interp.push(float(i) * 0.05, Vector2(float(i), 0.0))
	assert_eq(interp.size(), SnapshotInterpolator.MAX_STATES)


func test_empty_returns_the_fallback() -> void:
	assert_true(interp.is_empty())
	assert_eq(interp.sample(1.0, Vector2(3.0, 4.0)), Vector2(3.0, 4.0))


func test_clear_forgets_every_state() -> void:
	interp.push(0.0, Vector2.ONE)
	interp.clear()
	assert_true(interp.is_empty())
