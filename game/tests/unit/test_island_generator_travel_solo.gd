extends GutTest
## island-generator task 8.1, with exactly 1 player, offline (no hosting, no port, no second peer):
## a solo crossing from a test copy of the coast cay lands on the reef the run seed names, and the
## real coast cay still ends the run.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const REEF: StringName = &"reef_traps"
const ARRIVAL: Dictionary = {"health": 100.0, "energy": 100.0}

var settings_path: String = UserTmp.path("test_island_generator_travel_solo_settings.cfg")
var island: GeneratedIsland


func before_all() -> void:
	island = ReefSamples.island(1)


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(1).player_input.enabled = false
	shell.session.world_state["run_seed"] = 1
	return shell


## 8.1 "A solo crossing lands on a generated reef": a test copy of the coast cay whose next island is
## the reef, island index 2 and run seed 1.
func test_a_solo_crossing_lands_on_a_generated_reef() -> void:
	var coast := (GameState.content.get_entry(&"islands", &"coast_cay") as IslandLayoutData).duplicate() as IslandLayoutData
	coast.id = &"test_coast_to_reef"
	coast.next_island = REEF
	GameState.content._cache["islands/%s" % coast.id] = coast
	var shell := _shell()
	shell.session.travel_to(String(coast.id), 2, "", {1: ARRIVAL}, 0.0)
	await wait_process_frames(2)
	assert_eq(shell.travel.history.current_index(), 2, "the test coast cay is island 2")
	var body := shell.session.body(1)
	var result := CrossingResult.new()
	result.route_id = &"raft"
	result.integrity = 70.0
	result.riders[1] = {"health": 90.0, "energy": 60.0, "aboard": true, "dead": false}
	shell.travel.crossing_ended(result)
	assert_true(await wait_until(func() -> bool: return shell.travel.island.layout.id == &"reef_traps_3", 3.0), "the reef loads")
	assert_eq(IslandSource.hash_of(shell.travel.island.layout), island.island_hash, "island 3 of the reef for run seed 1")
	assert_eq(shell.travel.history.current_id(), REEF, "the history names the chain")
	assert_eq(shell.travel.history.current_index(), 3)
	assert_eq(CreatureNav.cell_of(body.global_position), shell.travel.island.built.landing_cells()[0], "on the first landing cell")
	var raft := shell.session.get_node_or_null("Raft") as Raft
	assert_not_null(raft, "the raft is beached on its site")
	if raft != null:
		assert_eq(raft.integrity, 70.0)
		assert_eq(CreatureNav.cell_of(raft.global_position), shell.travel.island.built.raft_site)
	assert_ne(shell.travel.check(), IslandTravel.Outcome.OVER, "the run goes on")
	assert_false(multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer is ENetMultiplayerPeer, "no port opened")
	GameState.content._cache.erase("islands/%s" % coast.id)


func test_the_real_coast_cay_still_ends_the_run() -> void:
	var shell := _shell()
	shell.session.travel_to("coast_cay", 2, "", {1: ARRIVAL}, 0.0)
	await wait_process_frames(2)
	var result := CrossingResult.new()
	result.route_id = &"raft"
	result.integrity = 70.0
	result.riders[1] = {"health": 90.0, "energy": 60.0, "aboard": true, "dead": false}
	shell.travel.crossing_ended(result)
	assert_eq(shell.travel.check(), IslandTravel.Outcome.OVER, "the coast cay names no next island")
