extends GutTest
## guardacostas-capture, group 11 (design.md §12, spec "Fade with distance"): the patrol boat's third
## spawn rule. A mid-chain island (mangrove, reef, rocky key, lighthouse) gets its boats 30% of the time,
## rolled from the run seed and the island, then as many as a coast island (1 or 2 for one player); a
## far-chain island (storm key, shipwreck reef) gets none. Over 1,000 run seeds the REEF fixture has
## boats in 26-34% of them; the same seed sets the island up the same way twice.

const SEEDS: int = 1000
const MID: Array[DataEnums.ChainFamily] = [DataEnums.ChainFamily.MANGROVE, DataEnums.ChainFamily.REEF,
	DataEnums.ChainFamily.ROCK, DataEnums.ChainFamily.LIGHTHOUSE]
const FAR: Array[DataEnums.ChainFamily] = [DataEnums.ChainFamily.STORM, DataEnums.ChainFamily.SHIPWRECK]

var boat: CreatureData
var net: NetHarness = null


func before_each() -> void:
	boat = GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData
	FixtureIslands.put_in()


func after_each() -> void:
	FixtureIslands.take_out()
	if net != null:
		net.teardown()
		net = null


# The boats a fresh set-up of `family`'s island `layout_id` gets under `run_seed` for `players`.
func _boats(run_seed: int, layout_id: StringName, family: DataEnums.ChainFamily, players: int = 1) -> int:
	var dice := CreatureSpawner.patrol_stream(run_seed, layout_id)
	var total: int = 0
	for rule: CreatureSpawnRuleData in boat.spawn_rules:
		if rule.chain_families.has(family) and rule.phases.is_empty():
			total += CreatureSpawner.roll_patrol(boat, rule, dice, players)
	return total


func test_the_mid_chain_rule_is_data() -> void:
	var mid: Array[CreatureSpawnRuleData] = []
	for rule: CreatureSpawnRuleData in boat.spawn_rules:
		for family: DataEnums.ChainFamily in MID:
			if rule.chain_families.has(family) and not mid.has(rule):
				mid.append(rule)
	assert_eq(mid.size(), 1, "one rule for the four mid families")
	var rule: CreatureSpawnRuleData = mid[0]
	for family: DataEnums.ChainFamily in MID:
		assert_true(rule.chain_families.has(family))
	assert_almost_eq(rule.chance, 0.3, 0.000001)
	assert_eq(rule.count, Vector2i(1, 2), "the coast rule's count")


# Spec "Mid chains have fewer patrols".
func test_a_mid_chain_island_has_boats_in_26_to_34_percent_of_1000_seeds() -> void:
	var with_boats: int = 0
	for seed_value: int in range(1, SEEDS + 1):
		var count: int = _boats(seed_value, &"reef_test", DataEnums.ChainFamily.REEF)
		if count > 0:
			with_boats += 1
			assert_true(count == 1 or count == 2, "one or two boats, not %d" % count)
	var share: float = 100.0 * with_boats / SEEDS
	gut.p("REEF fixture: %.1f%% of %d seeds have boats" % [share, SEEDS])
	assert_between(share, 26.0, 34.0)


# Spec "Far chain".
func test_a_far_chain_island_has_no_patrol() -> void:
	for rule: CreatureSpawnRuleData in boat.spawn_rules:
		for family: DataEnums.ChainFamily in FAR:
			assert_false(rule.chain_families.has(family), "no rule names a far family")
	for seed_value: int in range(1, 101):
		assert_eq(_boats(seed_value, &"reef_test", DataEnums.ChainFamily.STORM), 0)


func test_one_player_gets_the_base_count() -> void:
	var counts: Dictionary[int, bool] = {}
	for seed_value: int in range(1, 301):
		var count: int = _boats(seed_value, &"reef_test", DataEnums.ChainFamily.REEF, 1)
		if count > 0:
			counts[count] = true
	assert_eq(counts.keys().size(), 2, "1 and 2, the base count")
	for count: int in counts:
		assert_true(count == 1 or count == 2)


# Spec "The same island keeps its patrol": the real spawner, set up twice from the same run seed.
func test_the_same_seed_sets_the_island_up_with_the_same_boats_twice() -> void:
	var layout := GameState.content.get_entry(&"islands", &"reef_test") as IslandLayoutData
	var seed_value: int = 1
	while _boats(seed_value, &"reef_test", DataEnums.ChainFamily.REEF) == 0:
		seed_value += 1
	var expected: int = _boats(seed_value, &"reef_test", DataEnums.ChainFamily.REEF)
	net = NetHarness.new(self)
	var host := net.add_host()
	host.world_state["run_seed"] = seed_value
	var first: int = _spawned(host, layout)
	var second: int = _spawned(host, layout)
	assert_eq(first, expected, "the roll the spawner made")
	assert_eq(second, first, "the same number of boats again")


func _spawned(host: CoopSession, layout: IslandLayoutData) -> int:
	var spawner := CreatureSpawner.new()
	host.add_child(spawner)
	spawner.setup(host, layout)
	spawner.party_size = 1
	spawner.spawn_permanent()
	var count: int = spawner.creatures(&"patrol_boat").size()
	for creature: Creature in spawner.creatures():
		creature.get_parent().remove_child(creature)
		creature.queue_free()
	host.remove_child(spawner)
	spawner.queue_free()
	return count
