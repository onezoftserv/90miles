extends GutTest
## guardacostas-capture, group 2 (design.md §8; specs "Release at the next island", "Island history",
## main spec "Previous island after capture"), with exactly 1 player, offline: the restart on the
## previous island rebuilt as on first arrival, island 1 restarting island 1, a release from the
## sandbar onto the coast cay with no raft beached, a release from the coast cay ending the run, and
## landing cells within 5 tiles. The scene that decides between them is group 9's; here the host's
## IslandTravel is called directly.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_capture_travel_settings.cfg"
const COAST: StringName = &"coast_cay"
const SANDBAR: StringName = &"sandbar"
const LANDING_SPREAD_TILES: float = 5.0


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	FixtureIslands.put_in()


func after_each() -> void:
	FixtureIslands.take_out()
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(1).player_input.enabled = false
	return shell


func _go(shell: GameShell, id: StringName) -> void:
	shell.travel.travel(id)
	await wait_process_frames(2)


func _pickups(shell: GameShell, item_id: StringName) -> Array[WorldItem]:
	var found: Array[WorldItem] = []
	for node: Node in shell.session.pickups.get_children():
		var item := node as WorldItem
		if item != null and item.item_id == item_id and not item.is_queued_for_deletion():
			found.append(item)
	return found


func _landing_center(shell: GameShell, index: int = 0) -> Vector2:
	return IslandLayout.cell_center(shell.island.built.landing_cells()[index])


# Main spec "Previous island is fresh": the driftwood taken on island 2 lies there again when the
# party restarts it from island 3, and the player keeps the one they took.
func test_a_restart_from_island_3_rebuilds_island_2_as_on_first_arrival() -> void:
	var shell := _shell()
	var body := shell.session.body(1)
	await _go(shell, &"chain_b")
	assert_eq(shell.travel.islands_reached, 2)
	var wood := _pickups(shell, &"driftwood")
	assert_eq(wood.size(), 1, "island 2 has its driftwood")
	var first_spot: Vector2 = wood[0].global_position
	body.global_position = first_spot
	wood[0].interactable.interacted.emit(body)
	assert_eq(body.inventory.count_id(&"driftwood"), 1, "taken")
	await wait_process_frames(1)
	assert_eq(_pickups(shell, &"driftwood").size(), 0, "none left on island 2")
	await _go(shell, &"chain_c")
	assert_eq(shell.travel.islands_reached, 3)
	assert_eq(shell.travel.previous(), &"chain_b")
	body.meters.health = 70.0
	body.meters.energy = 40.0
	shell.travel.restart()
	await wait_process_frames(2)
	assert_eq(shell.island.layout.id, &"chain_b", "the previous island")
	var again := _pickups(shell, &"driftwood")
	assert_eq(again.size(), 1, "its driftwood lies there again")
	if again.size() == 1:
		assert_eq(again[0].global_position, first_spot, "where it lay on first arrival")
	assert_eq(body.inventory.count_id(&"driftwood"), 1, "the player keeps the one they took")
	assert_eq(body.meters.health, 70.0, "meters carry on")
	assert_eq(body.meters.energy, 40.0)
	assert_eq(body.position, _landing_center(shell), "alone, on the first landing cell")
	assert_eq(shell.travel.islands_reached, 3, "nothing counted twice")
	assert_eq(shell.travel.previous(), SANDBAR, "island 2's previous island is island 1")
	assert_null(shell.session.get_node_or_null("Raft"), "no raft beached on a restart")


# Main spec "Caught on the sandbar": island 1 has no previous island, so it is rebuilt.
func test_on_island_1_a_restart_rebuilds_island_1() -> void:
	var shell := _shell()
	var body := shell.session.body(1)
	var knives := _pickups(shell, &"knife")
	assert_eq(knives.size(), 1, "the hut's knife")
	body.global_position = knives[0].global_position
	knives[0].interactable.interacted.emit(body)
	assert_eq(body.inventory.count_id(&"knife"), 1)
	assert_eq(shell.travel.previous(), SANDBAR)
	shell.travel.restart()
	await wait_process_frames(2)
	assert_eq(shell.island.layout.id, SANDBAR, "island 1 again")
	assert_eq(_pickups(shell, &"knife").size(), 1, "the hut has its knife again")
	assert_eq(body.inventory.count_id(&"knife"), 1, "and the player keeps theirs")
	assert_eq(body.position, _landing_center(shell))
	assert_eq(shell.travel.islands_reached, 1)
	assert_eq(shell.flow, GameShell.Flow.RUN)
	assert_not_null(shell.session.events, "the world event bus outlives the island")
	assert_true(is_instance_valid(shell.session.events))


# Spec "A solo player released from the sandbar": on the coast cay's first landing cell, everything
# kept, and the raft build site empty.
func test_a_release_from_the_sandbar_lands_on_the_coast_cay_with_no_raft() -> void:
	var shell := _shell()
	var body := shell.session.body(1)
	body.inventory.add(&"lighter", 1)
	body.inventory.add(&"rope", 3)
	shell.travel.release()
	await wait_process_frames(2)
	assert_eq(shell.island.layout.id, COAST)
	assert_eq(body.position, _landing_center(shell), "the first landing cell")
	assert_eq(body.inventory.count_id(&"lighter"), 1, "a release keeps every item")
	assert_eq(body.inventory.count_id(&"rope"), 3)
	assert_null(shell.session.get_node_or_null("Raft"), "no vessel beached")
	assert_not_null(shell.session.get_node_or_null("RaftSite"), "the build site is empty")
	assert_eq(shell.travel.islands_reached, 2, "the coast cay counts as reached")
	assert_eq(shell.flow, GameShell.Flow.RUN)


# Spec "Released from the last island": the coast cay names no next island, so the run ends as
# leaving it does, and the summary shows.
func test_a_release_from_the_coast_cay_ends_the_run() -> void:
	var shell := _shell()
	await _go(shell, COAST)
	shell.travel.release()
	await wait_process_frames(2)
	assert_eq(shell.flow, GameShell.Flow.SUMMARY, "the run summary shows")


# Spec "Release at the next island": the party lands on the landing cells within 5 tiles of each
# other. Every island a release lands on is island 2 or later; island 1's landing cells are the run's
# four start spots, where a restart of island 1 puts each player back.
func test_the_landing_cells_of_every_island_after_the_first_lie_within_5_tiles() -> void:
	for id: StringName in [COAST, &"chain_a", &"chain_b", &"chain_c"]:
		var built := IslandLayout.build(GameState.content.get_entry(&"islands", id) as IslandLayoutData)
		var cells := built.landing_cells()
		assert_eq(cells.size(), 4, "%s lands four" % id)
		for a: Vector2i in cells:
			for b: Vector2i in cells:
				assert_true(Vector2(a).distance_to(Vector2(b)) <= LANDING_SPREAD_TILES + 0.000001,
					"%s: %s and %s within 5 tiles" % [id, a, b])
