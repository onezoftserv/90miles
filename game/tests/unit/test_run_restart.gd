extends GutTest
## endings-progression "Restart from the summary" and "A fresh run starts clean", with exactly 1
## player offline: "Otra vez" starts a clean solo run on the sandbar, nothing from the run before
## stays, a co-op summary offers only "Volver al inicio", and a client keeps its summary when the
## host leaves.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_run_restart_settings.cfg"
const HOST_LEFT_NOTE: String = "El anfitrión cerró la partida."

var _seeds: Array[int] = []


func before_each() -> void:
	_seeds = [11, 12, 13, 14]
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	WeatherManager.stop()
	get_tree().paused = false
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	shell.seed_source = func() -> int: return _seeds.pop_front()
	add_child_autofree(shell)
	return shell


func _solo() -> GameShell:
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session.body(1).player_input.enabled = false
	return shell


func _kill(body: PlayerBody) -> void:
	body.meters.solo = true
	body.meters.thirst = 0.0
	body.meters.health = 2.0
	body.meters.tick(1.0, MeterContext.new())


# A solo run with the raft built and launched; the crossing's plan is 60 s with no beats.
func _launch() -> Array:
	var shell := _solo()
	var body := shell.session.body(1)
	var site := shell.session.get_node("RaftSite") as BuildSite
	body.global_position = site.global_position
	body.inventory.add(&"driftwood", 6)
	body.inventory.add(&"inner_tube", 2)
	body.inventory.add(&"rope", 3)
	site.deposit(body)
	site.work(1.0)
	(shell.session.get_node("Raft") as Raft).interactable.interacted.emit(body)
	var crossing := shell.crossings[0] as Crossing
	crossing.plan = CrossingPlan.create(60.0, [] as Array[RefCounted])
	return [shell, crossing]


func _crossings_under(session: CoopSession) -> int:
	var count: int = 0
	for child: Node in session.get_children():
		if child is Crossing:
			count += 1
	return count


func test_solo_again_starts_clean() -> void:
	var shell := _solo()
	await wait_frames(2)
	var entities: int = shell.session.entities.get_child_count()
	var pickups: int = shell.session.pickups.get_child_count()
	shell.travel.travel(&"coast_cay")
	await wait_process_frames(2)
	WeatherManager.sky.clock.set_time(500.0, 2)
	var shark := GameState.content.get_entry(&"creatures", &"reef_shark") as CreatureData
	shell.session.spawn_creature(shark, Vector2.ZERO)
	var old_session: CoopSession = shell.session
	_kill(shell.session.body(1))
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
	(shell.screen as SummaryScreen).restart_button.pressed.emit()
	assert_eq(shell.flow, GameShell.Flow.RUN)
	assert_null(shell.screen)
	assert_eq(shell.island.layout.id, &"sandbar")
	assert_eq(shell.session.peer_ids(), [1] as Array[int])
	var meters := shell.session.body(1).meters
	assert_eq(meters.thirst, 100.0)
	assert_eq(meters.hunger, 100.0)
	assert_eq(meters.heat, 0.0)
	assert_eq(meters.energy, 100.0)
	assert_eq(meters.morale, 100.0)
	assert_eq(meters.health, 100.0)
	assert_false(meters.dead)
	assert_eq(meters.death_cause, &"")
	var sky := WeatherManager.sky
	assert_eq(sky.clock.day, 1)
	assert_eq(sky.clock.time_of_day_s, 0.0)
	assert_eq(sky.weather.current.id, &"calm")
	assert_null(sky.weather.pending)
	assert_true(WeatherManager.running)
	assert_true(shell.crossings.is_empty())
	assert_true(shell.crossing_results.is_empty())
	assert_true(shell.session.removed_names().is_empty())
	assert_eq(Crossing.next_serial(shell.session), 0)
	assert_eq(shell.travel.islands_reached, 1)
	assert_eq(shell.session.world_state["run_seed"], 12, "a new run seed")
	assert_false(get_tree().paused)
	assert_not_null(shell.hud)
	await wait_frames(2)
	assert_false(is_instance_valid(old_session), "the old session is gone")
	assert_eq(shell.session.entities.get_child_count(), entities, "only the sandbar's own creatures")
	assert_eq(shell.session.pickups.get_child_count(), pickups)


func test_drowned_mid_crossing_then_again() -> void:
	var launched := _launch()
	var shell := launched[0] as GameShell
	var crossing := launched[1] as Crossing
	crossing.throw_in(1)
	var rider := crossing.body_of(1)
	rider.meters.solo = true
	rider.meters.energy = 0.0
	CrossingRig.run(crossing, 10.0)
	await wait_frames(2)
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
	assert_eq((shell.screen as SummaryScreen).rows(), ["Balsero: Murió (ahogamiento)"] as Array[String])
	(shell.screen as SummaryScreen).restart_button.pressed.emit()
	assert_true(shell.crossings.is_empty())
	assert_eq(_crossings_under(shell.session), 0)
	assert_eq(shell.island.layout.id, &"sandbar")
	await wait_frames(2)
	assert_false(is_instance_valid(crossing), "the crossing left with the old session")


func test_the_solo_buttons() -> void:
	var shell := _solo()
	_kill(shell.session.body(1))
	var summary := shell.screen as SummaryScreen
	assert_true(summary.restart_button.visible)
	assert_eq(summary.restart_button.text, "Otra vez")
	assert_true(summary.restart_button.has_focus())
	assert_true(summary.home_button.visible)
	assert_eq(summary.home_button.text, "Volver al inicio")


func test_a_new_run_never_starts_paused() -> void:
	var shell := _solo()
	_kill(shell.session.body(1))
	get_tree().paused = true
	(shell.screen as SummaryScreen).restart_button.pressed.emit()
	assert_false(get_tree().paused)
	assert_eq(shell.flow, GameShell.Flow.RUN)


func test_a_co_op_summary_offers_only_home() -> void:
	var shell := _shell()
	shell.port = 0
	shell.start_host()
	shell.session.begin_run()
	assert_eq(shell.flow, GameShell.Flow.RUN)
	_kill(shell.session.body(1))
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
	var summary := shell.screen as SummaryScreen
	assert_false(summary.restart_button.visible)
	assert_true(summary.home_button.has_focus())
	# End the run here: the session must go before the peer closes.
	summary.home_button.pressed.emit()
	assert_eq(shell.flow, GameShell.Flow.TITLE)


func test_a_client_keeps_its_summary_when_the_host_leaves() -> void:
	var shell := _solo()
	_kill(shell.session.body(1))
	var shown: Control = shell.screen
	shell._on_host_lost()
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
	assert_eq(shell.screen, shown, "the summary stays")
	var summary := shell.screen as SummaryScreen
	assert_true(summary.note.visible)
	assert_eq(summary.note.text, HOST_LEFT_NOTE)
	assert_false(summary.restart_button.visible)
	await wait_frames(2)
	assert_null(shell.session, "the run behind it is freed")
	summary.home_button.pressed.emit()
	assert_eq(shell.flow, GameShell.Flow.TITLE)
