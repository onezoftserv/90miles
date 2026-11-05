extends GutTest
## coop-networking "Per-peer rate limits": the token bucket behind every per-peer limit.


func test_burst_is_the_capacity_then_refills_at_the_rate() -> void:
	var quick_chat := RateLimiter.new(3.0, 0.5)
	assert_true(quick_chat.try_take(1.0, 0.0))
	assert_true(quick_chat.try_take(1.0, 0.0))
	assert_true(quick_chat.try_take(1.0, 0.0))
	assert_false(quick_chat.try_take(1.0, 0.0), "a 4th phrase in the same burst")
	assert_false(quick_chat.try_take(1.0, 1.9), "not refilled yet at 1.9 s")
	assert_true(quick_chat.try_take(1.0, 2.0), "one token back after 2 s")
	assert_false(quick_chat.try_take(1.0, 2.0))


func test_refill_never_exceeds_the_capacity() -> void:
	var bucket := RateLimiter.new(3.0, 0.5)
	for i: int in 3:
		bucket.try_take(1.0, 0.0)
	var taken: int = 0
	for i: int in 10:
		if bucket.try_take(1.0, 1000.0):
			taken += 1
	assert_eq(taken, 3)


func test_fractional_amounts() -> void:
	var sim_time := RateLimiter.new(0.25, 1.0)
	assert_true(sim_time.try_take(0.25, 0.0))
	assert_false(sim_time.try_take(0.125, 0.0))
	assert_true(sim_time.try_take(0.125, 0.125))
	assert_almost_eq(sim_time.available(0.125), 0.0, 0.000001)


func test_sixty_intents_of_a_tenth_at_once_take_only_the_slack() -> void:
	var sim_time := RateLimiter.new(0.25, 1.0)
	var accepted: float = 0.0
	for i: int in 60:
		if sim_time.try_take(0.1, 0.0):
			accepted += 0.1
	assert_almost_eq(accepted, 0.2, 0.000001)


func test_sixty_intents_of_a_tenth_within_one_second_stay_under_1_25_s() -> void:
	var sim_time := RateLimiter.new(0.25, 1.0)
	var accepted: float = 0.0
	for i: int in 60:
		if sim_time.try_take(0.1, float(i) / 60.0):
			accepted += 0.1
	assert_lt(accepted, 1.25 + 0.000001)
	assert_gt(accepted, 1.0, "the honest share still gets through")


func test_invalid_amounts_are_refused() -> void:
	var bucket := RateLimiter.new(3.0, 0.5)
	for amount: float in [0.0, -1.0, NAN, INF]:
		assert_false(bucket.try_take(amount, 0.0), "amount %s" % amount)
	assert_almost_eq(bucket.available(0.0), 3.0, 0.000001, "refused amounts take nothing")


func test_a_clock_going_backwards_adds_nothing() -> void:
	var bucket := RateLimiter.new(1.0, 1.0)
	assert_true(bucket.try_take(1.0, 10.0))
	assert_false(bucket.try_take(1.0, 5.0))
	assert_false(bucket.try_take(1.0, 10.5))
	assert_true(bucket.try_take(1.0, 11.0))
