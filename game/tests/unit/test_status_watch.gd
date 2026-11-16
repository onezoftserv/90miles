extends GutTest
## survival-meters "Jumps and cures are told apart" (damage-feedback design D3): the pure watch
## that sees a status clear on a body from its replicated status_flags. One player, offline.

const ST := DataEnums.Status

var watch: StatusWatch


func before_each() -> void:
	watch = StatusWatch.new()


func _bit(status: DataEnums.Status) -> int:
	return 1 << status


func test_the_first_observation_cures_nothing() -> void:
	assert_eq(watch.observe(0, false), 0)
	watch.reset()
	assert_eq(watch.observe(_bit(ST.BLEEDING), false), 0, "a body first seen bleeding")


func test_a_cleared_bit_is_a_cure() -> void:
	watch.observe(_bit(ST.BLEEDING) | _bit(ST.SUNBURN), false)
	assert_eq(watch.observe(_bit(ST.SUNBURN), false), _bit(ST.BLEEDING), "sábila stopped the bleeding")
	assert_eq(StatusWatch.statuses(_bit(ST.BLEEDING) | _bit(ST.SUNBURN)), [ST.BLEEDING, ST.SUNBURN] as Array[DataEnums.Status])


func test_a_new_status_is_no_cure() -> void:
	watch.observe(0, false)
	assert_eq(watch.observe(_bit(ST.BLEEDING), false), 0)


func test_a_dead_body_cures_nothing() -> void:
	watch.observe(_bit(ST.BLEEDING), false)
	assert_eq(watch.observe(0, true), 0)


func test_reset_makes_the_next_observation_a_baseline() -> void:
	watch.observe(_bit(ST.BLEEDING), false)
	watch.reset()
	assert_eq(watch.observe(0, false), 0, "a rebind to a teammate who does not bleed")
