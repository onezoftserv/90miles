extends GutTest
## secret-cay "Existence roll": once per run, from the run seed, one roll decides whether the run
## holds the secret; on success the map and the compass go on two different run indices inside
## the tuning's window (2 to 5). The same seed gives the same plan, a 1-player run rolls the same
## way, and the roll has its own random stream. Pure: no scene, no peer.

const SEEDS: int = 3000

var tuning: SecretTuning


func before_all() -> void:
	tuning = SecretTuning.standard()


func _with_chance(chance: float) -> SecretTuning:
	var copy := tuning.duplicate() as SecretTuning
	copy.run_chance = chance
	return copy


func _assert_pieces(plan: Dictionary, where: String) -> void:
	var pieces: Dictionary = plan.get("pieces", {})
	assert_eq(pieces.keys(), [tuning.map_item_id, tuning.compass_item_id], "map first, then compass %s" % where)
	var map_index: int = pieces.get(tuning.map_item_id, -1)
	var compass_index: int = pieces.get(tuning.compass_item_id, -1)
	assert_between(map_index, tuning.index_min, tuning.index_max, "map index %s" % where)
	assert_between(compass_index, tuning.index_min, tuning.index_max, "compass index %s" % where)
	assert_ne(map_index, compass_index, "two different islands %s" % where)


func test_one_run_in_three() -> void:
	var held: int = 0
	for run_seed: int in SEEDS:
		var plan: Dictionary = SecretPlan.roll(run_seed, tuning)
		if plan["held"]:
			held += 1
			_assert_pieces(plan, "for seed %d" % run_seed)
		else:
			assert_eq(plan.get("pieces", {}), {}, "no pieces without the secret (seed %d)" % run_seed)
	var share: float = float(held) / SEEDS
	assert_between(share, 0.30, 0.36, "%d of %d seeds hold the secret" % [held, SEEDS])


func test_every_index_pair_is_drawn() -> void:
	var pairs: Dictionary[Vector2i, bool] = {}
	for run_seed: int in SEEDS:
		var plan: Dictionary = SecretPlan.roll(run_seed, tuning)
		if plan["held"]:
			var pieces: Dictionary = plan["pieces"]
			pairs[Vector2i(pieces[tuning.map_item_id], pieces[tuning.compass_item_id])] = true
	# 4 indices, ordered pairs of different ones: 12.
	assert_eq(pairs.size(), 12, "every ordered pair of different indices from 2 to 5 shows up")


func test_same_seed_same_plan() -> void:
	var found: int = -1
	for run_seed: int in SEEDS:
		var plan: Dictionary = SecretPlan.roll(run_seed, tuning)
		if plan["held"] and plan["pieces"][tuning.map_item_id] == 3 and plan["pieces"][tuning.compass_item_id] == 5:
			found = run_seed
			break
	assert_gt(found, -1, "some seed puts the map on index 3 and the compass on index 5")
	if found < 0:
		return
	var again: Dictionary = SecretPlan.roll(found, tuning)
	assert_true(again["held"])
	assert_eq(again["pieces"][tuning.map_item_id], 3)
	assert_eq(again["pieces"][tuning.compass_item_id], 5)
	assert_eq(again, SecretPlan.roll(found, tuning), "the whole plan repeats")


func test_never_with_chance_0() -> void:
	var never := _with_chance(0.0)
	for run_seed: int in 100:
		assert_false(SecretPlan.roll(run_seed, never)["held"], "seed %d" % run_seed)


func test_always_with_chance_1() -> void:
	var always := _with_chance(1.0)
	for run_seed: int in 100:
		var plan: Dictionary = SecretPlan.roll(run_seed, always)
		assert_true(plan["held"], "seed %d" % run_seed)
		_assert_pieces(plan, "for seed %d" % run_seed)


func test_the_roll_has_its_own_stream() -> void:
	seed(4242)
	var expected: int = randi()
	seed(4242)
	SecretPlan.roll(7, tuning)
	assert_eq(randi(), expected, "the global stream did not move")
	var island_rng := RandomNumberGenerator.new()
	island_rng.seed = 7
	var first: int = island_rng.randi()
	island_rng.seed = 7
	SecretPlan.roll(7, tuning)
	assert_eq(island_rng.randi(), first, "another generator seeded from the run seed is untouched")
