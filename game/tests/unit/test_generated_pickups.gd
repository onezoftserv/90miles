extends GutTest
## island-generator design §7 ("Party scaling on generated islands", "Dawn refill"): the host scales
## the reef's driftwood with the party it reads the way the creature spawner does, never below the
## raft recipe, keeps handmade counts, and puts the seep's cups back when a dawn begins. Each case
## runs one offline session; the solo cases have exactly 1 player.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")

var island: GeneratedIsland


func before_all() -> void:
	island = ReefSamples.island(1)


func before_each() -> void:
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()


# An offline session of `players` with the island `layout` furnished and its pick-ups placed.
func _placed(players: int, layout: IslandLayoutData = island.layout) -> SandbarIsland:
	var session := CrossingRig.make_session(self, players)
	var scene := ISLAND_SCENE.instantiate() as SandbarIsland
	scene.layout = layout
	scene.with_creatures = false
	session.get_parent().add_child(scene)
	autofree(scene)
	session.terrain = scene.terrain
	scene.furnish(session)
	scene.place_pickups(session)
	return scene


func _lying(scene: SandbarIsland, item_id: StringName) -> Array[WorldItem]:
	var found: Array[WorldItem] = []
	for node: Node in scene._session.pickups.get_children():
		var item := node as WorldItem
		if item != null and item.item_id == item_id and not item.is_queued_for_deletion():
			found.append(item)
	return found


func _units(scene: SandbarIsland, item_id: StringName) -> int:
	var units: int = 0
	for item: WorldItem in _lying(scene, item_id):
		units += item.count
	return units


func test_the_reefs_driftwood_by_party_size() -> void:
	var expected: Array[int] = [8, 6, 6, 6]
	for players: int in range(1, 5):
		var scene := _placed(players)
		assert_eq(scene._session.island_difficulty().players, players, "%d living, connected players" % players)
		assert_eq(_units(scene, &"driftwood"), expected[players - 1], "driftwood for %d players" % players)


func test_party_pickups_keep_the_first_cells_in_reading_order() -> void:
	var raft := GameState.content.get_entry(&"recipes", &"raft") as RecipeData
	var three: Array[Dictionary] = SandbarIsland.party_pickups(island.built.pickups, 3, raft)
	var driftwood: Array[Vector2i] = []
	for spec: Dictionary in island.built.pickups:
		if spec["item_id"] == &"driftwood":
			driftwood.append(spec["cell"])
	var kept: Array[Vector2i] = []
	for spec: Dictionary in three:
		if spec["item_id"] == &"driftwood":
			kept.append(spec["cell"])
	assert_eq(kept, driftwood.slice(0, 6), "the first 6 driftwood cells")


func test_a_solo_reef_keeps_every_driftwood() -> void:
	var scene := _placed(1)
	assert_eq(_units(scene, &"driftwood"), 8)
	assert_eq(_lying(scene, &"driftwood").size() + _lying(scene, &"rope").size() + _lying(scene, &"inner_tube").size() + _lying(scene, &"plastic_jug").size() + _lying(scene, &"rain_cup").size(), island.built.pickups.size(), "every pick-up lies there")


func test_four_players_never_lose_the_raft() -> void:
	var scene := _placed(4)
	assert_eq(_units(scene, &"driftwood"), 6)
	assert_eq(_units(scene, &"inner_tube"), 2)
	assert_eq(_units(scene, &"rope"), 8, "6 trap rope and 2 flotsam rope")
	assert_eq(IslandSource.hash_of(scene.layout), island.island_hash, "the island hash is the 1-player one")
	assert_eq(IslandLayoutWriter.digest(scene.layout), island.island_hash)


func test_the_coast_cay_keeps_its_counts_for_four_players() -> void:
	var coast := GameState.content.get_entry(&"islands", &"coast_cay") as IslandLayoutData
	var scene := _placed(4, coast)
	assert_eq(scene._placed.size(), scene.built.pickups.size(), "every handmade pick-up for 4 players")


func test_a_solo_players_seep_fills_again() -> void:
	var scene := _placed(1)
	var body := scene._session.body(1)
	var cups: Array[WorldItem] = _lying(scene, &"rain_cup")
	assert_eq(cups.size(), 1, "one seep pick-up")
	var anchor: Vector2 = cups[0].global_position
	var trap_rope: int = _units(scene, &"rope")
	body.global_position = anchor
	cups[0].interactable.interacted.emit(body)
	assert_eq(body.inventory.count_id(&"rain_cup"), 2, "both cups taken")
	var rope := _lying(scene, &"rope")[0]
	body.global_position = rope.global_position
	rope.interactable.interacted.emit(body)
	await wait_process_frames(1)
	WeatherManager.phase_changed.emit(DataEnums.DayPhase.DAWN)
	var again: Array[WorldItem] = _lying(scene, &"rain_cup")
	assert_eq(again.size(), 1, "a pick-up lies on the anchor again")
	if again.size() == 1:
		assert_eq(again[0].count, 2, "two cups")
		assert_eq(again[0].global_position, anchor)
	assert_eq(_units(scene, &"rope"), trap_rope - 1, "the taken rope is not back")
	WeatherManager.phase_changed.emit(DataEnums.DayPhase.DAWN)
	assert_eq(_lying(scene, &"rain_cup").size(), 1, "a cup still lying is not doubled")
	WeatherManager.phase_changed.emit(DataEnums.DayPhase.NIGHT)
	assert_eq(_lying(scene, &"rain_cup").size(), 1, "only a dawn refills")
