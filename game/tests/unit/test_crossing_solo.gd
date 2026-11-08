extends GutTest
## crossing with exactly 1 player, offline: launch, cross alone, tie down, fall in, climb back,
## swim the whole way, and the coast cay opening when the crossing ends (the run ends only in a death).

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_crossing_settings.cfg"
const SQUALL := CrossingBeat.Kind.SQUALL


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


# A solo shell run with the raft built and launched; the crossing's plan is replaced by `beats`.
func _launch(beats: Array[RefCounted]) -> Array:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	var body := shell.session.body(1)
	body.player_input.enabled = false
	var site := shell.session.get_node("RaftSite") as BuildSite
	body.global_position = site.global_position
	body.inventory.add(&"driftwood", 6)
	body.inventory.add(&"inner_tube", 2)
	body.inventory.add(&"rope", 3)
	site.deposit(body)
	site.work(1.0)
	(shell.session.get_node("Raft") as Raft).interactable.interacted.emit(body)
	var crossing := shell.crossings[0] as Crossing
	crossing.plan = CrossingPlan.create(60.0, beats)
	return [shell, crossing]


func test_solo_launch_enters_crossing_not_summary() -> void:
	var launched := _launch([])
	var shell := launched[0] as GameShell
	var crossing := launched[1] as Crossing
	assert_eq(shell.flow, GameShell.Flow.RUN)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD)
	assert_eq(crossing.integrity.value, 100.0)
	assert_true(crossing.body_of(1).visible)


func test_solo_finishes_coast_crossing() -> void:
	var launched := _launch([])
	var shell := launched[0] as GameShell
	var crossing := launched[1] as Crossing
	CrossingRig.run(crossing, 59.9)
	assert_false(crossing.finished)
	assert_eq(shell.flow, GameShell.Flow.RUN)
	CrossingRig.run(crossing, 0.1)
	assert_eq(shell.crossing_results.size(), 1)
	var result := shell.crossing_results[0] as CrossingResult
	assert_eq(result.integrity, 100.0)
	assert_false(result.broken)
	assert_eq(result.drift_offset_tiles, 0.0, "a coast crossing has no drift")
	assert_true(result.riders[1]["aboard"])
	assert_false(result.riders[1]["dead"])
	await wait_frames(2)
	assert_eq(shell.flow, GameShell.Flow.RUN, "the crossing ends on the coast cay, not in the summary")
	assert_eq(shell.island.layout.id, &"coast_cay")


func test_solo_ties_down_through_squall() -> void:
	var launched := _launch([CrossingRig.beat(5.0, SQUALL)])
	var shell := launched[0] as GameShell
	var crossing := launched[1] as Crossing
	var body := crossing.body_of(1)
	CrossingRig.hold(crossing, body, 1.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.TIED)
	CrossingRig.release(crossing, body)
	CrossingRig.run(crossing, 4.0)
	assert_eq(crossing.integrity.value, 70.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.TIED, "still aboard")
	CrossingRig.run(crossing, 55.0)
	var result := shell.crossing_results[0] as CrossingResult
	assert_eq(result.integrity, 70.0)
	assert_false(result.broken)
	assert_true(result.riders[1]["aboard"])


func test_solo_falls_in_climbs_back_and_finishes() -> void:
	var launched := _launch([CrossingRig.beat(5.0, SQUALL)])
	var shell := launched[0] as GameShell
	var crossing := launched[1] as Crossing
	var body := crossing.body_of(1)
	CrossingRig.run(crossing, 5.1)
	assert_eq(crossing.rider_state(1), Crossing.Rider.IN_WATER)
	CrossingRig.hold(crossing, body, 3.0)
	assert_eq(crossing.rider_state(1), Crossing.Rider.ABOARD)
	CrossingRig.release(crossing, body)
	CrossingRig.run(crossing, 51.8)
	assert_eq(shell.crossing_results.size(), 1)
	var result := shell.crossing_results[0] as CrossingResult
	assert_true(result.riders[1]["aboard"])
	assert_eq(result.integrity, 70.0)
	await wait_frames(2)
	assert_eq(shell.flow, GameShell.Flow.RUN)
	assert_eq(shell.island.layout.id, &"coast_cay")


func test_solo_swimmer_finishes_swim_route() -> void:
	var crossing := CrossingRig.make(self, &"binoculars_swim", 1, 0.0, 60.0)
	var finished: Array[CrossingResult] = []
	crossing.ended.connect(func(result: CrossingResult) -> void: finished.append(result))
	CrossingRig.run(crossing, 59.9)
	assert_eq(finished.size(), 0)
	CrossingRig.run(crossing, 0.1)
	assert_eq(finished.size(), 1)
	assert_almost_eq(float(finished[0].riders[1]["energy"]), 28.0, 0.01)
	assert_false(finished[0].riders[1]["dead"])
	assert_false(finished[0].broken)
	assert_false(finished[0].riders[1]["aboard"])
	assert_eq(finished[0].integrity, 0.0, "no vessel, no integrity")


func test_solo_dying_in_the_crossing_ends_the_run_as_a_death() -> void:
	var launched := _launch([])
	var shell := launched[0] as GameShell
	var crossing := launched[1] as Crossing
	crossing.body_of(1).meters.dead = true
	CrossingRig.run(crossing, 0.2)
	await wait_frames(2)
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
