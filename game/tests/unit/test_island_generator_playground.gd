extends GutTest
## island-generator "Walking generated reefs alone": the dev scene loads with reef_traps, run seed 1
## and index 3, one offline player stands on the first landing cell, the next seed builds that
## island and moves the player, and the label says what the generator did.

const PLAYGROUND: PackedScene = preload("res://scenes/dev/island_generator_playground.tscn")

var playground: IslandGeneratorPlayground


func before_each() -> void:
	playground = PLAYGROUND.instantiate() as IslandGeneratorPlayground
	add_child_autofree(playground)
	await wait_process_frames(2)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


func _body() -> PlayerBody:
	return playground.session.body(playground.session.multiplayer.get_unique_id())


func _first_cell() -> Vector2i:
	return playground.travel.island.built.landing_cells()[0]


func test_it_loads_the_reef_with_one_offline_player_on_the_first_landing_cell() -> void:
	assert_eq(playground.chain.id, &"reef_traps")
	assert_eq(playground.run_seed, 1)
	assert_eq(playground.index, 3)
	assert_eq(playground.session.peer_ids(), [1] as Array[int], "one player")
	assert_false(playground.multiplayer.multiplayer_peer is ENetMultiplayerPeer, "offline")
	assert_eq(IslandSource.hash_of(playground.travel.island.layout), ReefSamples.island(1).island_hash)
	assert_eq(CreatureNav.cell_of(_body().global_position), _first_cell())


func test_the_next_seed_builds_that_island_and_moves_the_player() -> void:
	playground.step(1)
	await wait_process_frames(2)
	assert_eq(playground.run_seed, 2)
	assert_eq(IslandSource.hash_of(playground.travel.island.layout), ReefSamples.island(2).island_hash, "run seed 2's island")
	assert_eq(CreatureNav.cell_of(_body().global_position), _first_cell(), "on its first landing cell")
	playground.step(-1)
	await wait_process_frames(2)
	assert_eq(IslandSource.hash_of(playground.travel.island.layout), ReefSamples.island(1).island_hash, "back to run seed 1")
	playground.regenerate()
	await wait_process_frames(2)
	assert_eq(IslandSource.hash_of(playground.travel.island.layout), ReefSamples.island(1).island_hash, "the same island again")


func test_the_label_says_what_the_generator_did() -> void:
	var text: String = playground.label.text
	for part: String in ["land cells", "attempts", "fallback", "walk to raft site", "walk to lobster_traps", "walk to limestone_cave", "walk to flotsam_line", "generated in"]:
		assert_string_contains(text, part)


func test_it_prints_the_time_per_attempt() -> void:
	playground.log_timings(1, 20)
	assert_string_contains(playground.summary(), "generated in", "the timing reads after twenty run seeds")
