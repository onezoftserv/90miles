extends GutTest
## island-generator design §4 step 1: seeds from SHA-256, one generator per stage, and no unstable
## randomness in the generation scripts.

const GENERATION_DIR: String = "res://scripts/levels/generation"
## seed_for(1, 3, reef_traps, 0, land), recorded the first time the test passed (a format guard).
const RECORDED_SEED: int = 355171497221103513


func test_the_seed_is_the_first_15_hex_digits_of_the_sha256() -> void:
	var text: String = "%d|%d|%s|%d|%s" % [1, 3, "reef_traps", 0, "land"]
	assert_eq(text, "1|3|reef_traps|0|land")
	assert_eq(IslandSeeds.seed_for(1, 3, &"reef_traps", 0, &"land"), text.sha256_text().substr(0, 15).hex_to_int())


func test_the_seed_is_stable_and_bounded() -> void:
	var first: int = IslandSeeds.seed_for(7, 2, &"reef_traps", 4, &"pois")
	assert_eq(IslandSeeds.seed_for(7, 2, &"reef_traps", 4, &"pois"), first, "the same on every call")
	for run_seed: int in range(1, 51):
		var value: int = IslandSeeds.seed_for(run_seed, 3, &"reef_traps", 0, &"land")
		assert_gte(value, 0)
		assert_lt(value, 1 << 60)


func test_every_input_moves_the_seed() -> void:
	var base: int = IslandSeeds.seed_for(1, 3, &"reef_traps", 0, &"land")
	assert_ne(IslandSeeds.seed_for(2, 3, &"reef_traps", 0, &"land"), base, "run seed")
	assert_ne(IslandSeeds.seed_for(1, 4, &"reef_traps", 0, &"land"), base, "island index")
	assert_ne(IslandSeeds.seed_for(1, 3, &"mangrove_maze", 0, &"land"), base, "chain")
	assert_ne(IslandSeeds.seed_for(1, 3, &"reef_traps", 1, &"land"), base, "attempt")
	assert_ne(IslandSeeds.seed_for(1, 3, &"reef_traps", 0, &"bands"), base, "stage")


func test_the_recorded_seed() -> void:
	assert_eq(IslandSeeds.seed_for(1, 3, &"reef_traps", 0, &"land"), RECORDED_SEED, "re-record only when the seed format changes on purpose")


func test_a_stage_generator_draws_the_same_numbers_twice() -> void:
	var a := IslandSeeds.rng_for(1, 3, &"reef_traps", 0, &"land")
	var b := IslandSeeds.rng_for(1, 3, &"reef_traps", 0, &"land")
	for i: int in 10:
		assert_eq(a.randi_range(0, 9999), b.randi_range(0, 9999), "draw %d" % i)


func test_generation_uses_no_unstable_randomness() -> void:
	var banned: PackedStringArray = ["hash(", "randf", "FastNoiseLite", "sin(", "cos(", "atan"]
	var files: PackedStringArray = DirAccess.get_files_at(GENERATION_DIR)
	var scanned: int = 0
	for file: String in files:
		if file.get_extension() != "gd":
			continue
		scanned += 1
		var source: String = FileAccess.get_file_as_string(GENERATION_DIR.path_join(file))
		for word: String in banned:
			assert_false(source.contains(word), "%s uses %s" % [file, word])
	assert_gt(scanned, 4, "the generation scripts were scanned")
