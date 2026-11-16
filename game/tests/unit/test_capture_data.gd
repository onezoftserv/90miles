extends GutTest
## guardacostas-capture, group 1 (design.md §15, spec "Shore squad data"): PatrolData's chase, squad,
## soldier and freeing fields with their defaults, the shipped capture content (the shore soldier,
## Rodríguez, la_captura and the two stub backgrounds) under the content check, the boat's squad,
## scene and commander references, the validator's squad rules, and the fixtures later groups use.

const FIXTURES: String = "res://tests/fixtures/content"
const BROKEN: String = "res://tests/fixtures/squad_broken"
const TOLERANCE: float = 0.000001
const CONTRACTIONS: Array[String] = ["pa'", "'tá", "'toy", "na'", "to'", "saca'o", "pasa'o"]


func _boat() -> CreatureData:
	return GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData


func _messages_for(errors: PackedStringArray, prefix: String) -> Array[String]:
	var mine: Array[String] = []
	for message: String in errors:
		if message.begins_with(prefix):
			mine.append(message)
	return mine


# --- PatrolData ----------------------------------------------------------------------------------

func test_the_new_fields_default_to_the_design_numbers_with_no_squad_and_no_calls() -> void:
	var data := PatrolData.new()
	assert_eq(data.haul_tiles, 1.0)
	assert_eq(data.haul_s, 2.0)
	assert_eq(data.chase_break_tiles, 10.0)
	assert_eq(data.landing_speed_tiles_s, 2.0)
	assert_eq(data.point_search_s, 3.0)
	assert_eq(data.point_search_tiles, 2.0)
	assert_eq(data.capture_grace_s, 60.0)
	assert_eq(data.soldier_day_sight_deg, 120.0)
	assert_eq(data.soldier_day_sight_tiles, 6.0)
	assert_eq(data.soldier_night_sight_deg, 60.0)
	assert_eq(data.soldier_night_sight_tiles, 5.0)
	assert_eq(data.soldier_chase_tiles_s, 5.0)
	assert_eq(data.capture_touch_tiles, 1.0)
	assert_eq(data.free_hold_s, 1.0)
	for lines: PackedStringArray in [data.squad_land_lines_es, data.squad_land_lines_en, data.squad_spot_lines_es,
			data.squad_spot_lines_en, data.squad_leave_lines_es, data.squad_leave_lines_en]:
		assert_eq(lines, PackedStringArray())
	# The squad stays off until a patrol names one, so a patrol kind with no squad keeps the plain alert.
	assert_eq(data.squad_creature_id, &"")
	assert_eq(data.squad_size, 0)
	assert_false(data.has_squad())


func test_the_patrol_boat_carries_every_number_of_section_15() -> void:
	var patrol := _boat().patrol
	assert_almost_eq(patrol.chase_speed_mult, 2.0, TOLERANCE)
	assert_eq(patrol.chase_speed_ref, PatrolData.SpeedRef.SWIMMER)
	assert_almost_eq(patrol.haul_tiles, 1.0, TOLERANCE)
	assert_almost_eq(patrol.haul_s, 2.0, TOLERANCE)
	assert_almost_eq(patrol.chase_break_tiles, 10.0, TOLERANCE)
	assert_eq(patrol.squad_creature_id, &"shore_soldier")
	assert_eq(patrol.squad_size, 3)
	assert_almost_eq(patrol.search_duration_s, 180.0, TOLERANCE)
	assert_eq(patrol.search_order, [PatrolData.SearchTarget.FIRE, PatrolData.SearchTarget.LAST_KNOWN_POSITION,
		PatrolData.SearchTarget.RANDOM_WALK] as Array[PatrolData.SearchTarget])
	assert_almost_eq(patrol.landing_speed_tiles_s, 2.0, TOLERANCE)
	assert_almost_eq(patrol.point_search_s, 3.0, TOLERANCE)
	assert_almost_eq(patrol.point_search_tiles, 2.0, TOLERANCE)
	assert_almost_eq(patrol.capture_grace_s, 60.0, TOLERANCE)
	assert_almost_eq(patrol.soldier_day_sight_deg, 120.0, TOLERANCE)
	assert_almost_eq(patrol.soldier_day_sight_tiles, 6.0, TOLERANCE)
	assert_almost_eq(patrol.soldier_night_sight_deg, 60.0, TOLERANCE)
	assert_almost_eq(patrol.soldier_night_sight_tiles, 5.0, TOLERANCE)
	assert_almost_eq(patrol.soldier_chase_tiles_s, 5.0, TOLERANCE)
	assert_almost_eq(patrol.capture_touch_s, 2.0, TOLERANCE)
	assert_almost_eq(patrol.capture_touch_tiles, 1.0, TOLERANCE)
	assert_almost_eq(patrol.free_guard_radius_tiles, 3.0, TOLERANCE)
	assert_almost_eq(patrol.free_hold_s, 1.0, TOLERANCE)
	assert_eq(patrol.capture_dialogue_id, &"beat_la_captura")
	assert_eq(patrol.commander_npc_id, &"rodriguez")
	assert_true(patrol.has_squad())
	assert_almost_eq(patrol.chase_speed_tiles_s(0.0), 6.0, TOLERANCE, "2x the 3 tiles/s swim speed")


func test_the_squads_calls_are_formal_spanish_with_an_english_line_each() -> void:
	var patrol := _boat().patrol
	for pair: Array in [[patrol.squad_land_lines_es, patrol.squad_land_lines_en],
			[patrol.squad_spot_lines_es, patrol.squad_spot_lines_en], [patrol.squad_leave_lines_es, patrol.squad_leave_lines_en]]:
		var spanish := pair[0] as PackedStringArray
		var english := pair[1] as PackedStringArray
		assert_gt(spanish.size(), 0)
		assert_eq(spanish.size(), english.size(), "one English line per Spanish line")
		for line: String in spanish:
			for contraction: String in CONTRACTIONS:
				assert_false(line.contains(contraction), "on duty, the squad speaks formal Spanish: %s" % line)


# --- content ------------------------------------------------------------------------------------

func test_the_capture_content_loads_and_passes_the_content_check() -> void:
	var errors := ContentValidator.validate(GameState.content)
	assert_eq(errors, PackedStringArray(), "the content check reports nothing")
	for pair: Array in [[&"creatures", &"shore_soldier"], [&"npcs", &"rodriguez"], [&"dialogue", &"beat_la_captura"],
			[&"backgrounds", &"maestro"], [&"backgrounds", &"medico"]]:
		assert_not_null(GameState.content.get_entry(pair[0], pair[1]), "%s/%s loads" % pair)


func test_the_shore_soldier_is_a_land_human_that_searches_and_captures() -> void:
	var soldier := GameState.content.get_entry(&"creatures", &"shore_soldier") as CreatureData
	assert_eq(soldier.category, CreatureData.Category.HUMAN)
	assert_eq(soldier.domains, [CreatureData.Domain.LAND] as Array[CreatureData.Domain])
	assert_eq(soldier.behavior, CreatureData.Behavior.SEARCH_CAPTURE)
	assert_almost_eq(soldier.speed_tiles_s, 3.0, TOLERANCE)
	assert_eq(soldier.health, 0)
	assert_eq(soldier.senses, [DataEnums.Sense.SIGHT] as Array[DataEnums.Sense])
	assert_true(soldier.spawn_rules.is_empty(), "only a squad spawns it")


func test_the_boats_squad_scene_and_commander_resolve() -> void:
	var patrol := _boat().patrol
	var soldier := GameState.content.get_entry(&"creatures", patrol.squad_creature_id) as CreatureData
	assert_not_null(soldier)
	assert_eq(soldier.behavior, CreatureData.Behavior.SEARCH_CAPTURE)
	var scene := GameState.content.get_entry(&"dialogue", patrol.capture_dialogue_id) as DialogueData
	assert_not_null(scene)
	assert_eq(scene.kind, DialogueData.Kind.STORY_BEAT)
	assert_eq(scene.npc_id, patrol.commander_npc_id)
	var commander := GameState.content.get_entry(&"npcs", patrol.commander_npc_id) as NpcData
	assert_not_null(commander)
	assert_eq(commander.category, NpcData.Category.IMPORTANT)
	assert_eq(commander.dialogue_mode, NpcData.DialogueMode.HANDWRITTEN)


func test_the_stub_backgrounds_have_names_and_no_starting_items() -> void:
	for id: StringName in [&"maestro", &"medico"]:
		var background := GameState.content.get_entry(&"backgrounds", id) as BackgroundData
		assert_false(background.name_es.is_empty())
		assert_false(background.name_en.is_empty())
		assert_true(background.starting_items.is_empty(), "%s is a stub" % id)


# design.md §9: open → act → plea → outcome, each state's entries by priority and conditions.
func test_la_captura_is_the_state_table_of_section_9() -> void:
	var scene := GameState.content.get_entry(&"dialogue", &"beat_la_captura") as DialogueData
	var by_state: Dictionary[StringName, Array] = {}
	for entry: DialogueStateData in scene.states:
		if not by_state.has(entry.state):
			by_state[entry.state] = []
		by_state[entry.state].append(entry)
	assert_eq(by_state.keys().size(), 4)
	for state: StringName in [&"open", &"act", &"plea", &"outcome"]:
		assert_true(by_state.has(state), "state %s" % state)
	assert_eq(by_state[&"open"].size(), 4, "again + plural, again, plural, singular")
	assert_eq(by_state[&"act"].size(), 1)
	assert_eq(by_state[&"plea"].size(), 3, "Médico, Maestro, nobody")
	assert_eq(by_state[&"outcome"].size(), 3, "release, car return, return")
	for entry: DialogueStateData in by_state[&"open"]:
		assert_eq(entry.next_state, &"act")
	assert_eq((by_state[&"act"][0] as DialogueStateData).next_state, &"plea")
	for entry: DialogueStateData in by_state[&"plea"]:
		assert_eq(entry.next_state, &"outcome")
	for entry: DialogueStateData in by_state[&"outcome"]:
		assert_eq(entry.next_state, &"", "the outcome closes the scene")
		assert_false(entry.on_enter_effects.is_empty())
		assert_false(entry.lines.is_empty())
	# Every line has both languages.
	for entry: DialogueStateData in scene.states:
		for line: DialogueLineData in entry.lines:
			assert_false(line.text_es.is_empty(), "%s has Spanish" % line.id)
			assert_false(line.text_en.is_empty(), "%s has English" % line.id)


func test_the_formal_act_speaks_no_contractions_and_the_captain_speaks_cuban() -> void:
	var scene := GameState.content.get_entry(&"dialogue", &"beat_la_captura") as DialogueData
	var cuban: int = 0
	for entry: DialogueStateData in scene.states:
		for line: DialogueLineData in entry.lines:
			var contracted: bool = false
			for contraction: String in CONTRACTIONS:
				contracted = contracted or line.text_es.contains(contraction)
			if String(line.id).ends_with("_acta"):
				assert_false(contracted, "the act is formal: %s" % line.text_es)
			elif contracted:
				cuban += 1
	assert_gt(cuban, 2, "Rodríguez speaks Cuban in person")


# --- the validator's squad rules ----------------------------------------------------------------

func test_each_broken_squad_is_reported_once_with_its_reason() -> void:
	var expected: Dictionary[StringName, String] = {
		&"squad_no_brain": "SEARCH_CAPTURE",
		&"squad_no_calls": "squad_spot_lines_es",
		&"squad_size_zero": "squad_size",
		&"squad_no_scene": "capture_dialogue_id",
	}
	var errors := ContentValidator.validate(ContentCatalog.new(BROKEN))
	for id: StringName in expected:
		var mine := _messages_for(errors, "creatures/%s:" % id)
		assert_eq(mine.size(), 1, "%s reports exactly one problem: %s" % [id, mine])
		if mine.size() == 1:
			assert_true(expected[id] in mine[0], "%s names %s: %s" % [id, expected[id], mine[0]])
	assert_eq(errors.size(), expected.size(), "nothing else is reported: %s" % [errors])


func test_a_patrol_with_no_squad_is_not_held_to_the_squad_rules() -> void:
	var catalog := ContentCatalog.new(FIXTURES)
	var plain := catalog.get_entry(&"creatures", &"patrol_test") as CreatureData
	assert_eq(ContentValidator._check_squad(catalog, "creatures/patrol_test", plain).size(), 0)


# --- fixtures (task 1.3) ------------------------------------------------------------------------

func test_the_new_fixtures_pass_the_content_check() -> void:
	var mine: Array[String] = []
	var prefixes: Array[String] = ["creatures/soldier_test", "items/foto_test",
		"islands/chain_a", "islands/chain_b", "islands/chain_c", "islands/chain_off", "islands/reef_test"]
	for message: String in ContentValidator.validate(ContentCatalog.new(FIXTURES)):
		# chain_b's pick-up is the shipped driftwood, which the fixture catalog does not hold.
		if message == "islands/chain_b: pickups[0].item_id references missing items/driftwood":
			continue
		for prefix: String in prefixes:
			if message.begins_with(prefix):
				mine.append(message)
	assert_eq(mine, [] as Array[String])
	assert_true(GameState.content.has_entry(&"items", &"driftwood"))
	# squad_test names the shipped scene and commander, which the fixture catalog does not hold: its
	# squad rules pass against the fixtures (its soldier is one), and its scene and commander are the
	# shipped ones.
	var catalog := ContentCatalog.new(FIXTURES)
	var squad := catalog.get_entry(&"creatures", &"squad_test") as CreatureData
	assert_eq(ContentValidator._check_squad(catalog, "creatures/squad_test", squad), PackedStringArray())
	assert_true(GameState.content.has_entry(&"dialogue", squad.patrol.capture_dialogue_id))
	assert_true(GameState.content.has_entry(&"npcs", squad.patrol.commander_npc_id))


func test_the_fixture_chain_runs_a_to_b_to_c_and_stops() -> void:
	var islands := FixtureIslands.put_in()
	assert_eq(islands[&"chain_a"].next_island, &"chain_b")
	assert_eq(islands[&"chain_b"].next_island, &"chain_c")
	assert_eq(islands[&"chain_c"].next_island, &"", "the last names no next island")
	assert_true(islands[&"chain_off"].off_graph)
	assert_eq(islands[&"reef_test"].chain_family, DataEnums.ChainFamily.REEF)
	for id: StringName in islands:
		var built := IslandLayout.build(islands[id])
		assert_eq(built.problems(), PackedStringArray(), "%s builds" % id)
		assert_eq(built.landing_cells().size(), 4, "%s has four landing cells" % id)
		assert_not_null(GameState.content.get_entry(&"islands", id), "%s is in the catalog's cache while put in" % id)
		assert_false(GameState.content.has_entry(&"islands", id), "%s is never in the catalog folder" % id)
	assert_false(islands[&"chain_b"].pickups.is_empty(), "chain_b has a pick-up to take and find again")
	FixtureIslands.take_out()
	for id: StringName in islands:
		assert_null(GameState.content.get_entry(&"islands", id), "%s is gone again" % id)


func test_the_fixture_backgrounds_set_the_background_id() -> void:
	var body := preload("res://scenes/player/player.tscn").instantiate() as PlayerBody
	add_child_autofree(body)
	assert_eq(body.background_id, &"", "no background until the backgrounds change")
	FixtureBackgrounds.give(body, &"medico")
	assert_eq(body.background_id, &"medico")
	FixtureBackgrounds.give(body, &"maestro")
	assert_eq(body.background_id, &"maestro")


func test_the_fixture_keepsake_is_a_keepsake() -> void:
	var foto := ContentCatalog.new(FIXTURES).get_entry(&"items", &"foto_test") as ItemData
	assert_not_null(foto)
	assert_true(foto.tags.has(DataEnums.ItemTag.KEEPSAKE))
	assert_false(foto.capabilities.has(DataEnums.Capability.LIGHT_FIRE))


func test_the_squad_test_patrol_lands_two_test_soldiers_for_120_s() -> void:
	var catalog := ContentCatalog.new(FIXTURES)
	var squad := catalog.get_entry(&"creatures", &"squad_test") as CreatureData
	assert_not_null(squad)
	assert_eq(squad.behavior, CreatureData.Behavior.PATROL_ROUTE)
	assert_eq(squad.patrol.squad_creature_id, &"soldier_test")
	assert_eq(squad.patrol.squad_size, 2)
	assert_almost_eq(squad.patrol.search_duration_s, 120.0, TOLERANCE)
	assert_true(squad.spawn_rules.is_empty(), "spawned by a test")
	var soldier := catalog.get_entry(&"creatures", &"soldier_test") as CreatureData
	assert_eq(soldier.behavior, CreatureData.Behavior.SEARCH_CAPTURE)
