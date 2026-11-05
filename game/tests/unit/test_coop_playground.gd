extends GutTest
## coop-networking: the co-op dev playground, started from command-line arguments
## (-- --host[=port], -- --join=address[:port], -- --solo) or its panel.

const PLAYGROUND_SCENE: PackedScene = preload("res://scenes/dev/coop_playground.tscn")


func after_each() -> void:
	NetManager.leave()


func _args(text: String) -> PackedStringArray:
	return PackedStringArray(text.split(" ", false))


func test_no_arguments_shows_the_panel() -> void:
	assert_eq(CoopPlayground.parse_args(_args("")), {"mode": "", "address": "", "port": NetPeers.DEFAULT_PORT})


func test_host_on_the_default_or_a_given_port() -> void:
	assert_eq(CoopPlayground.parse_args(_args("--host")), {"mode": "host", "address": "", "port": 7777})
	assert_eq(CoopPlayground.parse_args(_args("--host=7780")), {"mode": "host", "address": "", "port": 7780})


func test_join_an_address_with_or_without_a_port() -> void:
	assert_eq(CoopPlayground.parse_args(_args("--join=192.168.1.20")), {"mode": "join", "address": "192.168.1.20", "port": 7777})
	assert_eq(CoopPlayground.parse_args(_args("--join=127.0.0.1:7780")), {"mode": "join", "address": "127.0.0.1", "port": 7780})


func test_solo() -> void:
	assert_eq(CoopPlayground.parse_args(_args("--solo")), {"mode": "solo", "address": "", "port": 7777})


func test_bad_arguments_fall_back_to_the_panel() -> void:
	for text: String in ["--host=abc", "--host=70000", "--join=", "--join=1.2.3.4:0", "--fly"]:
		assert_eq(CoopPlayground.parse_args(_args(text))["mode"], "", text)


func test_the_playground_opens_on_its_panel_with_no_players() -> void:
	var playground := PLAYGROUND_SCENE.instantiate() as CoopPlayground
	add_child_autofree(playground)
	assert_true(playground.panel.visible)
	assert_eq(playground.session.peer_ids().size(), 0)
	assert_string_contains(playground.note.text, "UDP")


func test_solo_spawns_one_player_on_the_beach_terrain() -> void:
	var playground := PLAYGROUND_SCENE.instantiate() as CoopPlayground
	add_child_autofree(playground)
	playground.start({"mode": "solo", "address": "", "port": NetPeers.DEFAULT_PORT})
	assert_false(playground.panel.visible)
	assert_eq(playground.session.peer_ids(), [1] as Array[int])
	var body := playground.session.body(1)
	assert_eq(body.position, CoopPlayground.SPAWN_POINTS[0])
	assert_eq(body.terrain, playground.terrain)
	assert_eq(body.terrain.terrain_at(body.cell()), DataEnums.Terrain.BEACH)


func test_the_wheel_says_through_the_session() -> void:
	var playground := PLAYGROUND_SCENE.instantiate() as CoopPlayground
	add_child_autofree(playground)
	playground.start({"mode": "solo", "address": "", "port": NetPeers.DEFAULT_PORT})
	watch_signals(playground.session)
	playground.wheel.open()
	playground.wheel.aim(Vector2.UP)
	playground.wheel.release()
	assert_signal_emitted_with_parameters(playground.session, "quick_chat_shown", [1, 0])


func test_losing_the_host_shows_the_host_lost_screen() -> void:
	var playground := PLAYGROUND_SCENE.instantiate() as CoopPlayground
	add_child_autofree(playground)
	playground.session.host_lost.emit()
	var screens: int = 0
	for child: Node in playground.get_children():
		if child is HostLostScreen:
			screens += 1
	assert_eq(screens, 1)
