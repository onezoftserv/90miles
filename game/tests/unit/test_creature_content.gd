extends GutTest
## creatures-ai "First creatures": the three files load, pass the content check and are read as data.

const TEMP_ROOT: String = "user://test_creature_content"


func after_each() -> void:
	FsHelpers.remove_tree(TEMP_ROOT)


func _creature(id: StringName) -> CreatureData:
	return GameState.content.get_entry(&"creatures", id) as CreatureData


func test_the_three_creatures_load_with_their_numbers() -> void:
	var shark := _creature(&"reef_shark")
	var crab := _creature(&"land_crab")
	var gull := _creature(&"seagull")
	for data: CreatureData in [shark, crab, gull]:
		assert_not_null(data)
		assert_false(data.name_es.is_empty())
		assert_gt(data.health, 0)
		assert_gt(data.speed_tiles_s, 0.0)
		assert_false(data.domains.is_empty())
		assert_false(data.spawn_rules.is_empty())
	assert_eq(shark.behavior, CreatureData.Behavior.PATROL_CIRCLE_STRIKE)
	assert_eq(crab.behavior, CreatureData.Behavior.NIGHT_THIEF)
	assert_eq(gull.behavior, CreatureData.Behavior.SWOOP_STEAL)
	assert_eq(shark.damage, 25.0)
	assert_eq(shark.circle_time_s, Vector2(6.0, 10.0))
	assert_eq(shark.retreat_time_s, 4.0)
	assert_eq(shark.low_energy_threshold, 20.0)
	assert_eq(shark.keep_off_shore_tiles, 2)
	assert_eq(crab.spawn_rules[0].count, Vector2i(6, 6))
	assert_true(crab.spawn_rules[0].per_beach)
	assert_eq(crab.spawn_rules[0].phases, [DataEnums.DayPhase.NIGHT])
	assert_eq(gull.spawn_rules[0].anchor, CreatureSpawnRuleData.Anchor.NEST_PALM)
	assert_eq(gull.spawn_rules[0].count, Vector2i(2, 2))


func test_perch_ride_is_appended_after_trade_or_rob_and_both_new_machines_load() -> void:
	# creature-perch-ride: appended, so no saved behavior number moves.
	assert_eq(CreatureData.Behavior.PERCH_RIDE, CreatureData.Behavior.TRADE_OR_ROB + 1)
	assert_eq(CreatureData.Behavior.size(), CreatureData.Behavior.PERCH_RIDE + 1, "the last one")
	assert_true(CreatureBrain.for_behavior(CreatureData.Behavior.PERCH_RIDE) is PerchRide)
	assert_true(CreatureBrain.for_behavior(CreatureData.Behavior.AMBIENT) is Ambient)


func test_the_content_check_reports_no_problem() -> void:
	assert_eq(ContentValidator.validate(GameState.content), PackedStringArray())


func test_the_sandbar_names_two_valid_nest_palms() -> void:
	var layout := preload("res://resources/islands/sandbar.tres") as IslandLayoutData
	var built := IslandLayout.build(layout)
	assert_eq(layout.nest_palms.size(), 2)
	for index: int in layout.nest_palms:
		assert_between(index, 0, built.palms.size() - 1)
	assert_eq(built.problems(), PackedStringArray())


func test_a_new_shark_from_data_only_runs_the_shark_brain() -> void:
	var data := (_creature(&"reef_shark")).duplicate() as CreatureData
	data.id = &"tiburon_prueba"
	FsHelpers.save_content(TEMP_ROOT, "creatures", "tiburon_prueba", data)
	var catalog := ContentCatalog.new(TEMP_ROOT)
	var made := Creature.make(catalog.get_entry(&"creatures", &"tiburon_prueba") as CreatureData)
	add_child_autofree(made)
	assert_true(made.brain is PatrolCircleStrike)
