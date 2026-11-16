extends GutTest
## guardacostas-capture, group 10 (design.md §13, specs "Capture on every peer", "Captives",
## "Whole-party capture", "The capture scene", "Island history") over ENet on localhost (NetHarness).
## The host decides every capture and every rescue; a client frees a captive with the ordinary interact
## hold, and a hold from out of reach frees nobody. A captive's intents are ignored while their quick
## chat goes through. A joiner sees a squad ashore (its soldiers, the dinghy and the captive in it), or
## joins a scene on its current line, held. Both peers show the same line, a downed teammate goes along
## and stands at 30 health, a captive client that drops and rejoins is still a captive, and both
## peers' summaries count the same islands reached.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const TIMEOUT_S: float = 6.0
const COAST: StringName = &"coast_cay"
const TILE: float = 16.0

var net: NetHarness
var patrol: PatrolData
var papo: PlayerIdentity


func before_each() -> void:
	net = NetHarness.new(self)
	papo = PlayerIdentity.create()
	patrol = (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	net.teardown()


func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.with_creatures = false
	session.get_parent().add_child(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)
	var travel := IslandTravel.new()
	travel.name = "Travel"
	session.add_child(travel)
	travel.setup(session, island)


func _as(identity: PlayerIdentity) -> Callable:
	return func(session: CoopSession) -> void:
		_setup(session)
		session.local_identity = identity
		session.local_name = "Papo"


func _travel(session: CoopSession) -> IslandTravel:
	return session.get_node("Travel") as IslandTravel


func _pair(identity: PlayerIdentity = null) -> Array[CoopSession]:
	var host := net.add_host(_setup)
	var client := await net.join(_as(identity) if identity != null else _setup)
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	return [host, client] as Array[CoopSession]


func _landing(session: CoopSession) -> Vector2:
	return IslandLayout.cell_center(_travel(session).island.built.landing_cells()[0])


# The host seats `peer`'s player in a dinghy on the landing beach.
func _seat(host: CoopSession, peer: int) -> PlayerBody:
	var captive := host.body(peer)
	CaptureRules.capture(captive, host.body(CoopSession.HOST_ID) if peer != CoopSession.HOST_ID else captive, patrol)
	captive.seat_captive(_landing(host))
	return captive


# --- freeing ----------------------------------------------------------------------------------------

# Spec "A client frees a captive": the host's player sits captive with no soldier near; the client's
# player holds interact on them for 1 s.
func test_a_client_frees_the_hosts_captive_player_and_both_peers_show_them_standing() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var id: int = net.peer_id(client)
	var captive := _seat(host, CoopSession.HOST_ID)
	# Two players: the host's capture is not the whole party's.
	assert_false(CaptureScene.of(host).playing)
	var theirs := client.body(CoopSession.HOST_ID)
	assert_true(await wait_until(func() -> bool: return theirs.captive, TIMEOUT_S), "the client sees the captive")
	# The client's player walks up beside them and holds interact.
	host.body(id).global_position = captive.global_position + Vector2(10.0, 0.0)
	client.body(id).global_position = captive.global_position + Vector2(10.0, 0.0)
	client.body(id).player_input.enabled = false
	client.body(id).intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	assert_true(await wait_until(func() -> bool: return not captive.captive, TIMEOUT_S), "the host frees them")
	assert_true(await wait_until(func() -> bool: return not theirs.captive, TIMEOUT_S), "both peers show them standing")
	client.body(id).intent = MoveIntent.new()


# Spec "A client cannot free from afar".
func test_a_client_holding_interact_6_tiles_away_frees_nobody() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var id: int = net.peer_id(client)
	var captive := _seat(host, CoopSession.HOST_ID)
	host.body(id).global_position = captive.global_position + Vector2(6.0 * TILE, 0.0)
	client.body(id).global_position = captive.global_position + Vector2(6.0 * TILE, 0.0)
	client.body(id).player_input.enabled = false
	client.body(id).intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	await wait_seconds(2.0)
	assert_true(captive.captive, "the captive stays a captive")
	client.body(id).intent = MoveIntent.new()


# --- a captive's intents ------------------------------------------------------------------------

# Spec "A captive cannot act".
func test_a_captive_clients_moves_and_uses_are_ignored_and_its_quick_chat_goes_through() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var id: int = net.peer_id(client)
	var captive := _seat(host, id)
	captive.inventory.add(&"coco", 1)
	assert_true(await wait_until(func() -> bool: return client.body(id).captive, TIMEOUT_S))
	var at: Vector2 = captive.global_position
	client.body(id).player_input.enabled = false
	client.body(id).intent = MoveIntent.create(Vector2.RIGHT, true, false, false)
	await wait_seconds(1.0)
	client.body(id).intent = MoveIntent.new()
	assert_eq(captive.global_position, at, "the host ignores its moves")
	client.use_item(0, 0)
	await wait_seconds(0.3)
	assert_eq(captive.inventory.count_id(&"coco"), 1, "and its use")
	var shown: Array[int] = []
	host.quick_chat_shown.connect(func(peer: int, _slot: int) -> void: shown.append(peer))
	client.say(0)
	assert_true(await wait_until(func() -> bool: return shown.has(id), TIMEOUT_S), "its quick chat reaches the host")


# --- the squad ashore -------------------------------------------------------------------------------

# The host's spawner on the sandbar by day, with its one boat docked and its squad ashore.
func _squad_ashore(host: CoopSession) -> Creature:
	var spawner := CreatureSpawner.new()
	spawner.name = SandbarIsland.CREATURES_NAME
	host.add_child(spawner)
	spawner.setup(host, SANDBAR)
	spawner.party_size = 1
	spawner.world.phase = DataEnums.DayPhase.DAY
	spawner.world.weather_override = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	spawner.spawn_permanent()
	var boat: Creature = spawner.creatures(&"patrol_boat")[0]
	var brain := boat.brain as PatrolRoute
	brain.set_clock(patrol.horizon_warning_s + 10.0)
	boat.advance(0.0)
	var body := host.body(CoopSession.HOST_ID)
	body.global_position = IslandLayout.cell_center(IslandLayout.build(SANDBAR).solo_spawn)
	brain.spot(body, &"sight")
	assert_eq(boat.state_name(), &"DOCKED")
	for i: int in 100:
		if boat.squad_state == PatrolRoute.Squad.ASHORE:
			break
		boat.advance(0.1)
	assert_eq(boat.squad_state, PatrolRoute.Squad.ASHORE)
	return boat


# Spec "Joining while the squad is ashore".
func test_a_client_joining_while_the_squad_is_ashore_sees_its_soldiers_the_dinghy_and_the_captive() -> void:
	var pair := await _pair()
	var host := pair[0]
	var first := pair[1]
	var first_id: int = net.peer_id(first)
	var boat := _squad_ashore(host)
	var captive := _seat(host, first_id)
	(boat.brain as PatrolRoute).seat(captive)
	var joiner := await net.join(_setup)
	assert_not_null(joiner)
	assert_true(await net.settle())
	var theirs_boat := joiner.entities.get_node_or_null(NodePath(boat.name)) as Creature
	assert_true(await wait_until(func() -> bool:
		theirs_boat = joiner.entities.get_node_or_null(NodePath(boat.name)) as Creature
		return theirs_boat != null and theirs_boat.squad_state == PatrolRoute.Squad.ASHORE, TIMEOUT_S), "the dinghy on the beach")
	assert_eq(theirs_boat.landing, boat.landing)
	var soldiers: int = 0
	for soldier: Creature in (boat.brain as PatrolRoute).soldiers:
		var copy := joiner.entities.get_node_or_null(NodePath(soldier.name)) as Creature
		if copy != null and copy.position.distance_to(soldier.position) < TILE:
			soldiers += 1
	assert_eq(soldiers, 3, "the three soldiers where the host has them")
	assert_true(await wait_until(func() -> bool: return joiner.body(first_id) != null and joiner.body(first_id).captive, TIMEOUT_S), "and the captive in it")


# --- the scene ----------------------------------------------------------------------------------------

# Spec "Every peer reads the same line" and "A downed teammate goes along".
func test_both_peers_show_the_same_lines_and_a_downed_teammate_stands_at_30_health_after_it() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var id: int = net.peer_id(client)
	# Spec "A downed teammate goes along": downed with 40 s left.
	host.body(id).meters.health = 0.0
	host.body(id).meters.downed = true
	host.body(id).meters.downed_time_left_s = 40.0
	host.body(id).set_downed(true)
	var host_lines: Array[StringName] = []
	var client_lines: Array[StringName] = []
	CaptureScene.of(host).line_changed.connect(func() -> void: host_lines.append(CaptureScene.of(host).current_line_id))
	CaptureScene.of(client).line_changed.connect(func() -> void: client_lines.append(CaptureScene.of(client).current_line_id))
	CaptureRules.capture(host.body(CoopSession.HOST_ID), host.body(CoopSession.HOST_ID), patrol)
	CaptureScene.of(host).on_captured(host.body(CoopSession.HOST_ID), null)
	assert_true(await wait_until(func() -> bool: return CaptureScene.of(client).playing, TIMEOUT_S), "la_captura plays at once on both")
	assert_true(client.body(id).left_island, "neither player can move")
	assert_true(client.body(CoopSession.HOST_ID).left_island)
	assert_true(await wait_until(func() -> bool: return client_lines.size() == host_lines.size(), TIMEOUT_S))
	assert_eq(client_lines, host_lines, "the same line on both peers")
	assert_true(host_lines.has(&"captura_open_plural_1"), "two players: the plural")
	while CaptureScene.of(host).playing:
		CaptureScene.of(host).skip()
		await wait_process_frames(1)
	assert_true(await wait_until(func() -> bool: return not CaptureScene.of(client).playing and client_lines.size() == host_lines.size(), TIMEOUT_S))
	assert_eq(client_lines, host_lines)
	assert_true(await wait_until(func() -> bool: return not host.body(id).left_island, TIMEOUT_S), "both landed")
	assert_false(host.body(id).meters.downed, "the downed teammate stands")
	assert_almost_eq(host.body(id).meters.health, host.body(id).meters.tuning.revive_health, 0.001, "at 30 health")


# Spec "Joining during the scene".
func test_a_client_joining_during_the_scene_sees_its_current_line_and_lands_with_the_party() -> void:
	var host := net.add_host(_setup)
	await wait_process_frames(2)
	var keeper := CaptureScene.of(host)
	CaptureRules.capture(host.body(CoopSession.HOST_ID), host.body(CoopSession.HOST_ID), patrol)
	keeper.on_captured(host.body(CoopSession.HOST_ID), null)
	await wait_process_frames(2)
	assert_true(keeper.playing)
	keeper.skip()
	keeper.skip()
	assert_eq(keeper.current_serial, 3, "on its third line")
	var joiner := await net.join(_setup)
	assert_not_null(joiner)
	var theirs := CaptureScene.of(joiner)
	assert_true(await wait_until(func() -> bool: return theirs.playing and theirs.current_serial == 3, TIMEOUT_S), "the scene from its current line")
	assert_eq(theirs.current_line_id, keeper.current_line_id)
	var id: int = net.peer_id(joiner)
	assert_true(await wait_until(func() -> bool: return host.body(id) != null and host.body(id).left_island, TIMEOUT_S), "held out of play on the host")
	while keeper.playing:
		keeper.skip()
		await wait_process_frames(1)
	assert_true(await wait_until(func() -> bool: return host.body(id) != null and not host.body(id).left_island, TIMEOUT_S), "lands with the party")


# --- a dropped captive ------------------------------------------------------------------------------

func test_a_captive_client_that_drops_and_rejoins_is_still_a_captive() -> void:
	var pair := await _pair(papo)
	var host := pair[0]
	var client := pair[1]
	var id: int = net.peer_id(client)
	var captive := _seat(host, id)
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(id), TIMEOUT_S))
	assert_true(captive.captive, "the dropped body keeps the captive flag")
	assert_false(CaptureScene.of(host).playing, "the host is free: no whole-party capture")
	var back := await net.join(_as(papo))
	assert_not_null(back)
	assert_true(await net.settle())
	var new_id: int = net.peer_id(back)
	assert_eq(host.body(new_id), captive, "it takes the captive body back")
	assert_true(captive.captive, "still a captive")
	assert_true(await wait_until(func() -> bool: return back.body(new_id) != null and back.body(new_id).captive, TIMEOUT_S), "and its own peer sees it")


# --- the islands reached ------------------------------------------------------------------------

# Spec "Both peers count the same": caught on the coast cay, restarted on the sandbar, the run ends.
func test_both_peers_count_the_same_islands_after_a_restart() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	_travel(host).travel(COAST)
	assert_true(await wait_until(func() -> bool: return _travel(client).island.layout.id == COAST, TIMEOUT_S))
	var keeper := CaptureScene.of(host)
	for peer_id: int in host.peer_ids():
		CaptureRules.capture(host.body(peer_id), host.body(peer_id), patrol)
	keeper.on_captured(host.body(CoopSession.HOST_ID), null)
	assert_true(await wait_until(func() -> bool: return keeper.playing, TIMEOUT_S))
	while keeper.playing:
		keeper.skip()
		await wait_process_frames(1)
	assert_true(await wait_until(func() -> bool: return _travel(client).island.layout.id == &"sandbar", TIMEOUT_S), "restarted on the sandbar")
	assert_eq(_travel(host).islands_reached, 2)
	assert_eq(_travel(client).islands_reached, 2, "both peers count 2 islands reached (each shell's summary shows this number)")
