extends GutTest
## survival-meters "Hits and drains are told apart" and "Jumps and cures are told apart"
## (damage-feedback design D3): the pure watch that sorts one meter's changes, fed by hand the
## way a cue feeds it once per drawn frame. One player, offline: nothing here needs a session.

const W := MeterWatch.Change
const FRAME: float = 1.0 / 60.0
## The host's StateSync interval: a client sees a meter change in steps this far apart.
const SYNC: float = 0.05

var watch: MeterWatch


func before_each() -> void:
	watch = MeterWatch.new(3.0, 1.0)


# Feeds `value` for `frames` frames of `step` seconds each and returns every result.
func _hold(value: float, frames: int, step: float = FRAME) -> Array[int]:
	var seen: Array[int] = []
	for i: int in frames:
		seen.append(watch.observe(value, false, step))
	return seen


# Drains `per_s` from `start` for `seconds`, the value moving every `step` and observed every frame,
# as a client sees the host's updates. Returns every result and leaves the last value in `_value`.
var _value: float = 0.0
func _drain(start: float, per_s: float, seconds: float, step: float) -> Array[int]:
	var seen: Array[int] = []
	var value: float = start
	var since_step: float = 0.0
	var elapsed: float = 0.0
	while elapsed < seconds - 0.0001:
		elapsed += FRAME
		since_step += FRAME
		if since_step >= step - 0.0001:
			value -= per_s * since_step
			since_step = 0.0
		seen.append(watch.observe(value, false, FRAME))
	_value = value
	return seen


func test_the_first_observation_is_only_a_baseline() -> void:
	assert_eq(watch.observe(60.0, false, FRAME), W.NONE, "a late joiner's first look at a hurt body")
	assert_eq(watch.observe(60.0, false, FRAME), W.NONE)


func test_a_dead_body_never_counts() -> void:
	watch.observe(100.0, false, FRAME)
	assert_eq(watch.observe(40.0, true, FRAME), W.NONE)
	assert_eq(watch.observe(0.0, true, FRAME), W.NONE)
	assert_eq(watch.observe(30.0, true, FRAME), W.NONE)


func test_an_isolated_loss_of_5_is_a_hit_of_5() -> void:
	watch.observe(100.0, false, FRAME)
	_hold(100.0, 120)
	assert_eq(watch.observe(95.0, false, FRAME), W.HIT, "a crab's pinch")
	assert_almost_eq(watch.last_change, -5.0, 0.001)


func test_a_loss_under_the_margin_is_a_drain() -> void:
	watch.observe(100.0, false, FRAME)
	_hold(100.0, 120)
	assert_eq(watch.observe(97.1, false, FRAME), W.DRAIN)


func test_thirst_at_0_drains_every_frame_on_the_host() -> void:
	watch.observe(100.0, false, FRAME)
	var seen := _drain(100.0, 2.0, 3.0, FRAME)
	assert_false(seen.has(W.HIT), "2/s on the host's own frames is never a hit")
	assert_true(seen.has(W.DRAIN))


func test_thirst_at_0_drains_in_sync_steps_on_a_client() -> void:
	watch.observe(100.0, false, FRAME)
	var seen := _drain(100.0, 2.0, 3.0, SYNC)
	assert_false(seen.has(W.HIT), "2/s at 20 Hz is never a hit")
	assert_true(seen.has(W.DRAIN))


func test_a_half_second_gap_while_drowning_is_a_drain() -> void:
	watch.observe(100.0, false, FRAME)
	var seen := _drain(100.0, 10.0, 1.0, SYNC)
	assert_false(seen.has(W.HIT), "drowning at 10/s in 20 Hz steps")
	var value: float = _value
	# Half a second of the host's updates lost: the frames go by with the old value.
	for i: int in 30:
		seen.append(watch.observe(value, false, FRAME))
	assert_eq(watch.observe(value - 5.0, false, FRAME), W.DRAIN, "the next update is 5 lower")


func test_a_bite_inside_a_drain_is_a_hit_of_about_25() -> void:
	watch.observe(100.0, false, FRAME)
	_drain(100.0, 10.0, 1.0, FRAME)
	var value: float = _value - 10.0 * FRAME - 25.0
	assert_eq(watch.observe(value, false, FRAME), W.HIT)
	assert_almost_eq(watch.last_change, -25.0, 0.05)


func test_a_rise_at_once_is_a_jump() -> void:
	watch.observe(50.0, false, FRAME)
	_hold(50.0, 30)
	assert_eq(watch.observe(65.0, false, FRAME), W.JUMP, "a coconut's +15 thirst")
	assert_almost_eq(watch.last_change, 15.0, 0.001)


func test_a_jump_while_draining_counts_what_it_gained() -> void:
	watch.observe(50.0, false, FRAME)
	_drain(50.0, 2.0, 1.0, FRAME)
	assert_eq(watch.observe(_value + 15.0, false, FRAME), W.JUMP)
	assert_almost_eq(watch.last_change, 15.0, 0.05)


func test_a_slow_regain_is_nothing() -> void:
	watch.observe(50.0, false, FRAME)
	var value: float = 50.0
	for i: int in 180:
		value += 1.0 * FRAME
		assert_eq(watch.observe(value, false, FRAME), W.NONE, "frame %d" % i)


func test_a_small_rise_is_nothing() -> void:
	watch.observe(98.0, false, FRAME)
	assert_eq(watch.observe(100.0, false, FRAME), W.NONE, "a full meter took only 2")


func test_reset_makes_the_next_observation_a_baseline() -> void:
	watch.observe(40.0, false, FRAME)
	watch.reset()
	assert_eq(watch.observe(90.0, false, FRAME), W.NONE, "a rebind to a teammate at 90")
	assert_eq(watch.observe(60.0, false, FRAME), W.HIT, "a real loss after it still counts")


func test_the_drain_rate_is_forgotten_after_a_second_without_loss() -> void:
	watch.observe(100.0, false, FRAME)
	_drain(100.0, 10.0, 1.0, SYNC)
	_hold(_value, 70)
	assert_eq(watch.observe(_value - 5.0, false, FRAME), W.HIT, "a pinch once drowning has stopped")
