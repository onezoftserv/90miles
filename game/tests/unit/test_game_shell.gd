extends GutTest
## ui-shell "Screen flow", "Settings", "Join screen" and "Run summary", driven through the
## shell's screens without a network (solo is the offline peer).

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_game_shell_settings.cfg"

var now_s: float = 0.0


func before_each() -> void:
	now_s = 0.0
	NetManager.start_solo()


func after_each() -> void:
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _shell() -> GameShell:
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	shell.clock = func() -> float: return now_s
	add_child_autofree(shell)
	return shell


func _cancel_event() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_cancel"
	event.pressed = true
	return event


func test_the_shell_is_the_main_scene() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/shell/game_shell.tscn")


func test_the_game_opens_on_the_title() -> void:
	var shell := _shell()
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	assert_true(shell.screen is TitleScreen)


func test_solo_from_the_title() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.RUN)
	assert_true(shell.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "no network port")
	assert_not_null(shell.session)
	assert_eq(shell.session.peer_ids(), [1] as Array[int])
	assert_eq(shell.session.body(1).position, shell.island.spawn_points(true)[0], "on the beach")
	assert_null(shell.screen, "no lobby or menu over the run")
	assert_not_null(shell.hud, "the run HUD")
	assert_true(shell.hud.solo)
	assert_null(shell.hud.wheel, "no quick chat in solo")


func test_settings_are_kept() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).settings_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.SETTINGS)
	var screen := shell.screen as SettingsScreen
	screen.name_field.text = "Dayana"
	screen.name_field.text_submitted.emit("Dayana")
	screen.scale_picker.select(2)
	screen.scale_picker.item_selected.emit(2)
	assert_eq(GameSettings.load_from(SETTINGS_PATH).player_name, "Dayana")
	assert_eq(GameSettings.load_from(SETTINGS_PATH).ui_scale, 2)
	screen.back_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.TITLE)


func test_esc_goes_back_from_menu_screens() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).settings_requested.emit()
	shell.screen._unhandled_input(_cancel_event())
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	(shell.screen as TitleScreen).join_requested.emit()
	assert_eq(shell.flow, GameShell.Flow.JOIN)
	shell.screen._unhandled_input(_cancel_event())
	assert_eq(shell.flow, GameShell.Flow.TITLE)


func test_join_addresses() -> void:
	assert_eq(JoinScreen.parse_address("192.168.1.20"), {"address": "192.168.1.20", "port": 7777, "error": ""})
	assert_eq(JoinScreen.parse_address(" 10.0.0.5:7780 "), {"address": "10.0.0.5", "port": 7780, "error": ""})
	assert_false(String(JoinScreen.parse_address("192.168.1.20:99999")["error"]).is_empty(), "bad port")
	assert_false(String(JoinScreen.parse_address("")["error"]).is_empty(), "blank")
	assert_false(String(JoinScreen.parse_address("host:abc")["error"]).is_empty(), "port not a number")


func test_a_bad_port_is_refused_on_the_join_screen() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).join_requested.emit()
	var screen := shell.screen as JoinScreen
	watch_signals(screen)
	screen.address_field.text = "192.168.1.20:99999"
	screen.connect_button.pressed.emit()
	assert_signal_not_emitted(screen, "connect_requested")
	assert_string_contains(screen.status.text, "puerto")
	assert_true(shell.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "nothing connects")


func test_end_of_a_solo_run() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	now_s = 180.0
	shell.session.body(1).meters.dead = true
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
	var summary := shell.screen as SummaryScreen
	assert_eq(summary.run_length.text, "3:00")
	assert_eq(summary.rows().size(), 1)
	assert_string_contains(summary.rows()[0], "Balsero")
	assert_string_contains(summary.rows()[0], "Murió")
	summary.home_button.pressed.emit()
	assert_eq(shell.flow, GameShell.Flow.TITLE)
	assert_null(shell.session, "the run is over")


func test_a_run_summary_formats_its_length() -> void:
	assert_eq(SummaryScreen.format_length(185.4), "3:05")
	assert_eq(SummaryScreen.format_length(3725.0), "62:05")
	assert_eq(SummaryScreen.format_length(-3.0), "0:00")


func test_a_run_ends_when_the_last_living_teammate_is_removed() -> void:
	# A dropped teammate keeps the run open until they are removed; the removal ends it.
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session._add_player(7)
	shell.session.body(1).meters.dead = true
	assert_eq(shell.flow, GameShell.Flow.RUN, "a teammate is still in the run")
	shell.session._remove_player(7)
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)


func test_enter_while_connecting_does_not_join_twice() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).join_requested.emit()
	var screen := shell.screen as JoinScreen
	var asked: Array[String] = []
	for connection: Dictionary in screen.connect_requested.get_connections():
		screen.connect_requested.disconnect(connection["callable"])
	screen.connect_requested.connect(func(address: String, _port: int) -> void: asked.append(address))
	screen.address_field.text = "192.168.1.20"
	screen.address_field.text_submitted.emit(screen.address_field.text)
	screen.address_field.text_submitted.emit(screen.address_field.text)
	assert_eq(asked, ["192.168.1.20"] as Array[String], "one attempt at a time")


func test_a_removed_player_is_listed_as_dead_in_the_summary() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session._add_player(7)
	shell.session.roster[7] = "Papo"
	shell.session._remove_player(7)
	shell.session.body(1).meters.dead = true
	assert_eq(shell.flow, GameShell.Flow.SUMMARY)
	var summary := shell.screen as SummaryScreen
	assert_eq(summary.rows().size(), 2, "the solo player and the removed one")
	assert_string_contains(summary.rows()[1], "Papo")
	assert_string_contains(summary.rows()[1], "Murió")


# --- crossing-late-join: what a joiner's shell does with the host's progress ------------------

# A solo run with a teammate, peer 7, who left by raft; `crossing_s` > 0 puts their crossing under
# way with that much left, 0 means it ended before the progress arrived.
func _joined_after_7_left(crossing_s: float) -> Array:
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	shell.session._add_player(7)
	var routes := shell.session.get_node(^"Routes") as IslandRoutes
	routes._apply_departures({7: "raft"})
	var restored: Array[Crossing] = []
	if crossing_s > 0.0:
		var snapshot := CrossingSnapshot.new()
		snapshot.route_id = &"raft"
		snapshot.riders = [7] as Array[int]
		snapshot.plan = CrossingPlan.create(crossing_s)
		snapshot.maximum = 100.0
		snapshot.value = 100.0
		snapshot.states = {7: Crossing.Rider.ABOARD} as Dictionary[int, int]
		restored.append(Crossing.restore(shell.session, snapshot))
	routes.progress_received.emit(restored)
	return [shell, restored]


func test_a_restored_crossing_keeps_the_run_open_until_it_ends() -> void:
	var made := _joined_after_7_left(30.0)
	var shell := made[0] as GameShell
	var crossing := (made[1] as Array[Crossing])[0]
	assert_true(shell.crossings.has(crossing), "followed like a launched crossing")
	assert_true(shell.session.body(7).visible, "the rider is in the crossing")
	shell.session.body(1).meters.dead = true
	assert_eq(shell.flow, GameShell.Flow.RUN, "the teammate's crossing keeps the run open")
	crossing.advance(30.0)
	assert_true(crossing.finished)
	assert_false(shell.crossings.has(crossing))
	assert_false(shell.session.body(7).visible, "the rider leaves play when it ends")
	# coast-cay: with nobody living left on the sandbar, the rider goes on to the coast cay
	# instead of ending the run.
	assert_eq(shell.flow, GameShell.Flow.RUN, "the run goes on to the next island")
	await wait_frames(2)
	assert_eq(shell.island.layout.id, &"coast_cay", "the party travelled")
	assert_true(shell.session.body(7).visible, "the rider landed on the coast cay")
	assert_eq(shell.flow, GameShell.Flow.RUN)


func test_a_rider_whose_crossing_ended_before_the_join_stays_out_of_play() -> void:
	var made := _joined_after_7_left(0.0)
	var shell := made[0] as GameShell
	var rider := shell.session.body(7)
	assert_false(rider.visible, "held like on the host")
	assert_true(rider.left_island)
	assert_eq(rider.collision_layer, 0)
	assert_true(shell.session.body(1).visible, "the player who stayed is still on the island")
	assert_eq(shell.flow, GameShell.Flow.RUN)


func test_a_restored_crossing_already_followed_is_not_followed_twice() -> void:
	var made := _joined_after_7_left(30.0)
	var shell := made[0] as GameShell
	var routes := shell.session.get_node(^"Routes") as IslandRoutes
	routes.progress_received.emit(made[1] as Array[Crossing])
	assert_eq(shell.crossings.size(), 1)


func test_a_solo_crossing_rolls_its_creatures_from_the_departing_island() -> void:
	# creature-perch-ride "Crossing creature roll": the host attaches the roll right after launch.
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	var routes := shell.session.get_node(^"Routes") as IslandRoutes
	routes.route_started.emit(&"raft", [1] as Array[int])
	assert_eq(shell.crossings.size(), 1)
	if shell.crossings.is_empty():
		return
	var riders := shell.crossings[0].get_node_or_null(NodePath(CrossingCreatures.NODE_NAME)) as CrossingCreatures
	assert_not_null(riders, "the crossing rolled its creatures")
	if riders != null:
		assert_true(riders.creatures().is_empty(), "no creature in today's content has a crossing rule")


func test_solo_progress_with_nothing_changes_nothing() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	var routes := shell.session.get_node(^"Routes") as IslandRoutes
	routes.progress_received.emit([] as Array[Crossing])
	assert_true(shell.session.body(1).visible)
	assert_true(shell.crossings.is_empty())
	assert_eq(shell.flow, GameShell.Flow.RUN)


func test_the_run_carries_this_installs_identity() -> void:
	var shell := _shell()
	(shell.screen as TitleScreen).solo_requested.emit()
	assert_not_null(shell.session.local_identity)
	assert_eq(shell.session.local_identity.id, shell.settings.identity.id)
