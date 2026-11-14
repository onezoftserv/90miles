extends GutTest
## creature-perch-ride "Sighting effects" and "Crossing creature roll": the host's run record keeps
## the run's flags, how many of each creature the run placed, and when each limited effect last
## fired. A session lives one run, so each session starts with an empty record.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const Limit := EffectData.Limit


func test_an_unlimited_effect_always_fires() -> void:
	var record := RunRecord.new()
	assert_true(record.claim("a", Limit.NONE, 1))
	assert_true(record.claim("a", Limit.NONE, 1))
	assert_true(record.claim("a", Limit.NONE, 2))


func test_a_once_per_run_effect_fires_once_whatever_the_day() -> void:
	var record := RunRecord.new()
	assert_true(record.claim("a", Limit.ONCE_PER_RUN, 1))
	assert_false(record.claim("a", Limit.ONCE_PER_RUN, 1))
	assert_false(record.claim("a", Limit.ONCE_PER_RUN, 2))


func test_a_once_per_day_effect_fires_once_each_day() -> void:
	var record := RunRecord.new()
	assert_true(record.claim("a", Limit.ONCE_PER_DAY, 1), "day 1")
	assert_false(record.claim("a", Limit.ONCE_PER_DAY, 1), "day 1 again")
	assert_true(record.claim("a", Limit.ONCE_PER_DAY, 2), "day 2")
	assert_false(record.claim("a", Limit.ONCE_PER_DAY, 2), "day 2 again")
	assert_true(record.claim("a", Limit.ONCE_PER_DAY, 4), "a later day")


func test_a_once_per_reader_effect_fires_once_per_key() -> void:
	var record := RunRecord.new()
	assert_true(record.claim("a@1", Limit.ONCE_PER_READER, 1))
	assert_false(record.claim("a@1", Limit.ONCE_PER_READER, 3))
	assert_true(record.claim("a@2", Limit.ONCE_PER_READER, 3), "another reader")


func test_keys_are_counted_apart() -> void:
	var record := RunRecord.new()
	assert_true(record.claim("a", Limit.ONCE_PER_RUN, 1))
	assert_true(record.claim("b", Limit.ONCE_PER_RUN, 1))


func test_flags_are_set_and_cleared() -> void:
	var record := RunRecord.new()
	assert_false(record.has_flag(&"galleguito_a_bordo"))
	record.set_flag(&"galleguito_a_bordo")
	assert_true(record.has_flag(&"galleguito_a_bordo"))
	record.clear_flag(&"galleguito_a_bordo")
	assert_false(record.has_flag(&"galleguito_a_bordo"))


func test_creature_counts_add_up() -> void:
	var record := RunRecord.new()
	assert_eq(record.creature_count(&"galleguito"), 0)
	record.count_creature(&"galleguito")
	record.count_creature(&"galleguito")
	assert_eq(record.creature_count(&"galleguito"), 2)
	assert_eq(record.creature_count(&"pajarito"), 0)


func test_each_session_starts_a_fresh_record() -> void:
	var first := SESSION_SCENE.instantiate() as CoopSession
	var second := SESSION_SCENE.instantiate() as CoopSession
	autofree(first)
	autofree(second)
	assert_not_null(first.run_record)
	first.run_record.set_flag(&"galleguito_a_bordo")
	first.run_record.count_creature(&"galleguito")
	assert_ne(first.run_record, second.run_record)
	assert_false(second.run_record.has_flag(&"galleguito_a_bordo"), "a new run starts with no flags")
	assert_eq(second.run_record.creature_count(&"galleguito"), 0)
