extends GutTest
## guardacostas-stealth, group 8 (design.md decision 10; spec "Patrols on every peer" and "Spot meter"):
## a host and a client over ENet on localhost (NetHarness), each peer with its own sandbar terrain and
## the host with the real creature spawner. The host runs every boat, meter and trigger; a client draws
## the boat from the synced clock, state and aim and never decides anything.
## - The cone matches: over 5 s at night the client's boat and beam stay within one sync interval's
##   movement (0.1 s of the boat's speed, 3 degrees of beam) of the host's.
## - A mid-lap join gets the host's pose and aim on the client's first frame.
## - A client sending crouch on open sand in the beam is spotted at 2 s.
## - The meter rides on net_spot to both peers; two players get two boats 90 s apart.
## - Nothing alert-related runs on the client.
## Where a test needs the cone on a player for a fixed time, the boat's clock is held by hand (its
## physics process off) and the spawner's watch stepped once per frame at 1/60 s.

const LAYOUT: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const TIMEOUT_S: float = 5.0
const DT: float = 1.0 / 60.0
const TILE: float = 16.0
const NIGHT := DataEnums.DayPhase.NIGHT

var net: NetHarness
var spawner: CreatureSpawner


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	spawner = null


func after_each() -> void:
	net.teardown()
	WeatherManager.stop()


func _setup(session: CoopSession) -> void:
	session.terrain = IslandLayout.build(LAYOUT).terrain


# The host's real spawner on the sandbar, at night, calm, for `players` players: its permanent
# creatures (the patrol boats) spawn at once.
func _spawn_boats(host: CoopSession, players: int = 1) -> Array[Creature]:
	spawner = CreatureSpawner.new()
	spawner.name = SandbarIsland.CREATURES_NAME
	host.add_child(spawner)
	spawner.setup(host, LAYOUT)
	spawner.party_size = players
	spawner.world.phase = NIGHT
	spawner.world.weather_override = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	spawner.spawn_permanent()
	return spawner.creatures(&"patrol_boat")


# The host and the client share one scene tree here, so the host's world would also see the client
# branch's copies of the bodies (a real host sees only its own). The copies leave the players group.
func _client_bodies_are_not_players(client: CoopSession) -> void:
	for peer: int in client.peer_ids():
		client.body(peer).remove_from_group(PlayerBody.GROUP)


func _brain(boat: Creature) -> PatrolRoute:
	return boat.brain as PatrolRoute


# The boat's clock at `lap_s` seconds into its lap, settled with a zero-length tick.
func _lap_at(boat: Creature, lap_s: float) -> void:
	_brain(boat).set_clock(boat.data.patrol.horizon_warning_s + lap_s)
	boat.advance(0.0)


func _theirs(client: CoopSession, boat: Creature) -> Creature:
	return client.entities.get_node_or_null(NodePath(boat.name)) as Creature


func _client_has(client: CoopSession, boat: Creature) -> bool:
	return await wait_until(func() -> bool: return _theirs(client, boat) != null, TIMEOUT_S)


# A sand cell (BEACH, no roof) the held boat's light covers at its current clock, in reading order;
# the cell's centre in pixels, or (-1, -1) when the light is on no sand.
func _lit_sand(boat: Creature, terrain: GridTerrain) -> Vector2:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in terrain.cells:
		if terrain.cells[cell] == DataEnums.Terrain.BEACH and not terrain.shaded.has(cell):
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in cells:
		var centre: Vector2 = IslandLayout.cell_center(cell)
		var tiles: float = boat.position.distance_to(centre) / TILE
		if tiles >= 4.0 and tiles <= 8.0 and _brain(boat).lights(centre):
			return centre
	return Vector2(-1.0, -1.0)


# Holds the boat on the lap at a clock where its light covers open sand; returns that sand's centre.
func _hold_light_on_sand(boat: Creature, terrain: GridTerrain) -> Vector2:
	boat.set_physics_process(false)
	spawner.set_physics_process(false)
	for lap_s: float in [5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0]:
		_lap_at(boat, lap_s)
		var sand: Vector2 = _lit_sand(boat, terrain)
		if sand.x >= 0.0:
			return sand
	return Vector2(-1.0, -1.0)


# One held tick: the boat on its clock, then the watch's meter step.
func _hold_tick(boat: Creature, lap_s: float) -> void:
	_lap_at(boat, lap_s)
	spawner.watch.step(DT)


func _lap_time_of(boat: Creature) -> float:
	return boat.route_t - boat.data.patrol.horizon_warning_s


# --- the cone matches -----------------------------------------------------------------------------

func test_the_clients_boat_and_beam_match_the_hosts_for_5_s_at_night() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	var boats := _spawn_boats(host)
	assert_eq(boats.size(), 1)
	var boat: Creature = boats[0]
	_lap_at(boat, 10.0)
	assert_true(await _client_has(client, boat))
	var theirs: Creature = _theirs(client, boat)
	await wait_seconds(0.5)
	assert_eq(theirs.state_name(), &"LAP")
	assert_true(theirs.light_on, "the light is on at night in the lap, as the host says")
	var speed_px: float = theirs.view().loop.speed_tiles_s() * TILE
	var position_limit: float = 0.1 * speed_px
	var worst_px: float = 0.0
	var worst_deg: float = 0.0
	var seen: Dictionary[Vector2, bool] = {}
	var frames: int = 0
	var started: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - started < 5.0:
		await wait_physics_frames(1)
		frames += 1
		worst_px = maxf(worst_px, boat.position.distance_to(theirs.position))
		worst_deg = maxf(worst_deg, absf(wrapf(boat.beam - theirs.beam, -180.0, 180.0)))
		seen[theirs.position] = true
	gut.p("client boat vs host over %d frames: worst %.2f px (limit %.2f), worst beam %.2f deg (limit 3), %d distinct client positions" % [frames, worst_px, position_limit, worst_deg, seen.size()])
	assert_lte(worst_px, position_limit, "the boat is within one sync interval's movement")
	assert_lte(worst_deg, 3.0, "the beam is within 3 degrees")
	assert_gt(seen.size(), frames / 3, "the client advances the boat every frame between syncs, not only at the 10 Hz syncs")


# --- a mid-lap join -----------------------------------------------------------------------------

func test_a_client_that_joins_40_s_into_the_lap_has_the_boat_and_its_aim_on_its_first_frame() -> void:
	var host := net.add_host(_setup)
	var boats := _spawn_boats(host)
	var boat: Creature = boats[0]
	_lap_at(boat, 40.0)
	var first: Dictionary = {}
	var on_ready := func(creature: Creature) -> void:
		first["position"] = creature.position
		first["beam"] = creature.beam
		first["state"] = creature.state_id
		first["light_on"] = creature.light_on
		first["host_position"] = boat.position
		first["host_beam"] = boat.beam
		first["host_route_t"] = boat.route_t
	var catch_first := func(node: Node) -> void:
		var creature := node as Creature
		if creature != null and creature.name == boat.name:
			creature.ready.connect(on_ready.bind(creature), CONNECT_ONE_SHOT)
	var client := net.add_client(func(session: CoopSession) -> void:
		_setup(session)
		session.entities.child_entered_tree.connect(catch_first))
	assert_true(await wait_until(func() -> bool: return not first.is_empty(), TIMEOUT_S), "the boat reached the client")
	var loop: PatrolLoop = boat.view().loop
	var limit: float = 0.1 * loop.speed_tiles_s() * TILE + 1.0
	assert_eq(first["state"], PatrolRoute.State.LAP)
	assert_true(first["light_on"])
	assert_lte((first["position"] as Vector2).distance_to(first["host_position"] as Vector2), limit, "at the host's place on the loop")
	assert_lte(absf(wrapf(float(first["beam"]) - float(first["host_beam"]), -180.0, 180.0)), 3.0, "with the cone at the host's aim")
	assert_gt(float(first["host_route_t"]), boat.data.patrol.horizon_warning_s + 39.5, "the host was about 40 s into its lap")
	assert_not_null(client)


# --- the client cannot claim hidden ---------------------------------------------------------------

func test_a_client_sending_crouch_on_open_sand_in_the_beam_is_spotted_at_2_s() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	_client_bodies_are_not_players(client)
	var boat: Creature = _spawn_boats(host)[0]
	var sand: Vector2 = _hold_light_on_sand(boat, host.terrain as GridTerrain)
	assert_gte(sand.x, 0.0, "the sandbar has open sand the light reaches")
	var id: int = net.peer_id(client)
	var host_body: PlayerBody = host.body(id)
	host_body.global_position = sand
	var theirs: PlayerBody = client.body(id)
	theirs.intent = MoveIntent.create(Vector2.ZERO, false, true)
	var lap_s: float = _lap_time_of(boat)
	_lap_at(boat, lap_s)
	watch_signals(boat)
	assert_true(await wait_until(func() -> bool: return host_body.intent.crouch and host_body.global_position.distance_to(sand) < 1.0, TIMEOUT_S), "the host reads the client's crouch")
	host_body.spot_meter.clear()
	assert_eq(host_body.stealth_state, MovementStep.Stealth.VISIBLE, "crouching on sand hides nobody")
	var steps: int = 0
	while steps < 200 and get_signal_emit_count(boat, "patrol_alerted") == 0:
		await wait_physics_frames(1)
		_hold_tick(boat, lap_s)
		steps += 1
	assert_signal_emit_count(boat, "patrol_alerted", 1)
	assert_eq((get_signal_parameters(boat, "patrol_alerted", 0) as Array)[0], &"sight")
	assert_almost_eq(steps * DT, 2.0, 0.05, "spotted at 2 s")
	assert_eq(host_body.stealth_state, MovementStep.Stealth.VISIBLE, "still visible when spotted")
	assert_eq(_brain(boat).locked, host_body)


# --- the meter follows its player ---------------------------------------------------------------

func test_the_meter_reads_1_s_for_the_clients_player_and_0_for_the_hosts_on_both_peers() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	_client_bodies_are_not_players(client)
	var boat: Creature = _spawn_boats(host)[0]
	var sand: Vector2 = _hold_light_on_sand(boat, host.terrain as GridTerrain)
	assert_gte(sand.x, 0.0)
	var id: int = net.peer_id(client)
	host.body(id).global_position = sand
	# The host's own player stays out of the light, far from the sand it covers.
	host.body(CoopSession.HOST_ID).global_position = Vector2(8.0, 8.0)
	await wait_seconds(0.5)
	var lap_s: float = _lap_time_of(boat)
	host.body(id).spot_meter.clear()
	for i: int in 60:
		await wait_physics_frames(1)
		_hold_tick(boat, lap_s)
	assert_almost_eq(host.body(id).spot_meter.value, 1.0, 0.02, "the host's meter for the client's player reads 1 s")
	assert_almost_eq(host.body(CoopSession.HOST_ID).spot_meter.value, 0.0, 0.0001)
	# The sim is held: wait for the host's net_spot to reach the client.
	var shown := func() -> bool:
		return absf(client.body(id).spot_shown - 0.5) < 0.02 and absf(client.body(CoopSession.HOST_ID).spot_shown) < 0.0001
	assert_true(await wait_until(shown, TIMEOUT_S), "the client shows half a meter on its own player and none on the host's")
	assert_almost_eq(host.body(id).spot_shown, 0.5, 0.02, "the host shows the same")
	assert_almost_eq(host.body(CoopSession.HOST_ID).spot_shown, 0.0, 0.0001)
	assert_almost_eq(client.body(id).net.net_spot, 0.5, 0.02, "through net_spot")


# --- two players --------------------------------------------------------------------------------

func test_a_host_and_one_client_on_the_sandbar_get_two_boats_90_s_apart_on_both_peers() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	var boats := _spawn_boats(host, host.island_difficulty().players)
	assert_eq(boats.size(), 2, "two players, two boats")
	assert_true(await _client_has(client, boats[0]))
	assert_true(await _client_has(client, boats[1]))
	var period: float = PatrolLoop.period_s(boats[0].data.patrol, 0)
	var apart: float = absf(boats[0].route_t - boats[1].route_t)
	assert_almost_eq(minf(apart, period - apart), 90.0, 0.001, "90 s apart on the host")
	var synced := func() -> bool:
		var a: float = _theirs(client, boats[0]).route_t
		var b: float = _theirs(client, boats[1]).route_t
		var gap: float = absf(a - b)
		return absf(minf(gap, period - gap) - 90.0) < 0.5
	assert_true(await wait_until(synced, TIMEOUT_S), "and on the client")


# --- nothing on the client --------------------------------------------------------------------------

func test_the_client_runs_no_trigger_and_no_spot_and_never_reports() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	_client_bodies_are_not_players(client)
	var boat: Creature = _spawn_boats(host)[0]
	var sand: Vector2 = _hold_light_on_sand(boat, host.terrain as GridTerrain)
	assert_gte(sand.x, 0.0)
	assert_true(await _client_has(client, boat))
	var theirs: Creature = _theirs(client, boat)
	watch_signals(theirs)
	watch_signals(boat)
	var id: int = net.peer_id(client)
	host.body(id).global_position = sand
	host.body(CoopSession.HOST_ID).global_position = Vector2(8.0, 8.0)
	await wait_seconds(0.3)
	var lap_s: float = _lap_time_of(boat)
	host.body(id).spot_meter.clear()
	for i: int in 150:
		await wait_physics_frames(1)
		_hold_tick(boat, lap_s)
	assert_signal_emit_count(boat, "patrol_alerted", 1, "the host spotted the player and reported once")
	await wait_seconds(0.4)
	# guardacostas-capture: a player spotted on land docks the boat for its squad.
	assert_eq(theirs.state_name(), &"DOCKED", "the client shows the host's alert")
	assert_signal_not_emitted(theirs, "patrol_alerted")
	assert_null(theirs.world, "a client's boat has no world to read")
	var brain: PatrolRoute = theirs.brain as PatrolRoute
	assert_null(brain.locked, "it locked nobody")
	assert_eq(brain.clock_s, 0.0, "its brain never ticked")
	var at: Vector2 = theirs.position
	var serial: int = theirs.alert_serial
	theirs.advance(10.0)
	assert_eq(theirs.position, at, "a client tick moves nothing")
	assert_eq(theirs.alert_serial, serial)
	assert_signal_not_emitted(theirs, "patrol_alerted")
	for peer: int in client.peer_ids():
		assert_eq(client.body(peer).spot_meter.value, 0.0, "a client's meters never step")


# A joiner builds its run on the first island and then follows the host to a later one, which swaps
# its session's terrain (IslandTravel). The boat it received meanwhile must redraw on the new island's
# loop, not the first island's (found in the two-process run: a rejoin on the coast cay drew the boat
# 392 px off the loop).
func test_a_joiner_that_travels_after_the_boat_arrives_draws_it_on_the_new_islands_loop() -> void:
	const COAST: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")
	var host := net.add_host(func(session: CoopSession) -> void: session.terrain = IslandLayout.build(COAST).terrain)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	_client_bodies_are_not_players(client)
	spawner = CreatureSpawner.new()
	spawner.name = SandbarIsland.CREATURES_NAME
	host.add_child(spawner)
	spawner.setup(host, COAST)
	spawner.party_size = 1
	spawner.world.phase = NIGHT
	spawner.world.weather_override = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	spawner.spawn_permanent()
	var boats: Array[Creature] = spawner.creatures(&"patrol_boat")
	assert_false(boats.is_empty(), "the coast cay has a boat")
	if boats.is_empty():
		return
	var made: Creature = boats[0]
	_lap_at(made, 40.0)
	assert_true(await _client_has(client, made), "the client receives the boat while still on the sandbar")
	var theirs := _theirs(client, made)
	await wait_physics_frames(2)
	# The client follows the host to the coast cay: its session's terrain is swapped.
	client.terrain = IslandLayout.build(COAST).terrain
	await wait_physics_frames(3)
	var mine: PatrolView = theirs.view()
	var host_view: PatrolView = made.view()
	assert_true(mine.valid and host_view.valid, "both peers have a loop")
	if not mine.valid or not host_view.valid:
		return
	assert_almost_eq(mine.start_px().distance_to(host_view.start_px()), 0.0, 0.5, "the client's loop is the coast cay's, not the sandbar's")
	assert_almost_eq(mine.loop.perimeter, host_view.loop.perimeter, 0.01, "the same loop length as the host's")
