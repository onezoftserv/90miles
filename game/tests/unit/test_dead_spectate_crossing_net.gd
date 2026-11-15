extends GutTest
## ui-shell "Spectating a teammate" through a real crossing and a real landing, over ENet on
## localhost (NetHarness). Each branch builds the sandbar and its IslandTravel, launches a crossing on
## every route start and hands the travel keeper the crossing's end, as the shell does, with a run HUD
## bound per branch. The tests read the watched body, its camera's `enabled` and its limits, never
## which camera is current, because every branch shares one viewport here.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const TIMEOUT_S: float = 6.0
const COAST: StringName = &"coast_cay"

var net: NetHarness
var rng := RandomNumberGenerator.new()
var islands: Array[Node] = []
# Freed before the sessions they read.
var huds: Array[Node] = []


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	for hud: Node in huds:
		if is_instance_valid(hud):
			hud.free()
	huds.clear()
	net.teardown()
	for island: Node in islands:
		if is_instance_valid(island):
			island.free()
	islands.clear()


# The shell's order: the island, the session's ground, furnish, the travel keeper, and a crossing
# launched on each route start whose end goes to the travel keeper.
func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.with_creatures = false
	session.get_parent().add_child(island)
	islands.append(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)
	var travel := IslandTravel.new()
	travel.name = "Travel"
	session.add_child(travel)
	travel.setup(session, island)
	travel.island_loaded.connect(func(loaded: SandbarIsland) -> void: islands.append(loaded))
	var routes := session.get_node("Routes") as IslandRoutes
	routes.route_started.connect(func(id: StringName, peers: Array[int]) -> void:
		var route := GameState.content.get_entry(&"routes", id) as RouteData
		var integrity: float = routes.departure_integrity.get(id, float(route.vessel_integrity))
		var crossing := Crossing.launch(session, route, peers, integrity, DataEnums.DistanceBand.COAST, rng)
		crossing.ended.connect(func(result: CrossingResult) -> void:
			travel.crossing_ended(result)
			crossing.queue_free()))


func _as(player_name: String) -> Callable:
	return func(session: CoopSession) -> void:
		_setup(session)
		session.local_name = player_name


func _travel(session: CoopSession) -> IslandTravel:
	return session.get_node("Travel") as IslandTravel


func _hud(session: CoopSession) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	huds.append(hud)
	hud.bind(session, net.peer_id(session), false)
	return hud


# Yuni hosts and Papo joins, both on the sandbar on both peers.
func _pair() -> Array[CoopSession]:
	var host := net.add_host(_as("Yuni"))
	var client := await net.join(_as("Papo"))
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	return [host, client] as Array[CoopSession]


# Papo swims off with the binoculars and Yuni stays; the host's crossing gets a 600 s plan.
func _papo_swims(host: CoopSession, papo_id: int) -> Crossing:
	WeatherManager.sky.weather.apply(&"calm", 100.0, &"", -1.0)
	host.body(papo_id).inventory.add(&"binoculars", 1)
	host.body(papo_id).meters.energy = 100.0
	assert_true(host.start_route_for(papo_id, &"binoculars_swim"), "Papo swims off")
	var crossing := host.get_node_or_null("Crossing0") as Crossing
	if crossing != null:
		crossing.plan = CrossingPlan.create(600.0)
	return crossing


func _watching(hud: RunHud, body: PlayerBody) -> Callable:
	return func() -> bool:
		hud.refresh()
		return hud.spectate.watched() == body


func _assert_limits(camera: Camera2D, rect: Rect2, what: String) -> void:
	assert_eq(Rect2i(camera.limit_left, camera.limit_top, camera.limit_right - camera.limit_left, camera.limit_bottom - camera.limit_top), Rect2i(rect), what)


func test_a_dead_player_watches_a_rider_at_sea_and_on_the_next_island() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	if client == null:
		return
	var papo_id: int = net.peer_id(client)
	var yuni_hud := _hud(host)
	var crossing := _papo_swims(host, papo_id)
	assert_not_null(crossing)
	if crossing == null:
		return
	host.body(CoopSession.HOST_ID).meters.dead = true
	var papo := host.body(papo_id)
	assert_true(await wait_until(_watching(yuni_hud, papo), TIMEOUT_S), "the dead Yuni watches Papo in the crossing")
	assert_false(papo.left_island, "a rider at sea is still playing")
	assert_true(papo.camera.enabled, "Papo's camera shows Yuni's view")
	_assert_limits(papo.camera, crossing.sea_rect(), "the view keeps to the crossing's sea")
	assert_eq(yuni_hud.watching_label.text, "Mirando a: Papo  [A] [D] Cambiar")
	crossing._finish()
	var landed := func() -> bool: return _travel(host).island.layout.id == COAST and not papo.left_island
	assert_true(await wait_until(landed, TIMEOUT_S), "with Yuni dead the coast cay loads and Papo lands")
	assert_true(await wait_until(_watching(yuni_hud, papo), TIMEOUT_S), "Yuni still watches Papo")
	assert_true(papo.camera.enabled)
	_assert_limits(papo.camera, Rect2(_travel(host).island.bounds), "the view keeps to the coast cay")


func test_a_waiting_rider_watches_the_one_on_the_sandbar_until_landing() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	if client == null:
		return
	var papo_id: int = net.peer_id(client)
	var papo_hud := _hud(client)
	var crossing := _papo_swims(host, papo_id)
	assert_not_null(crossing)
	if crossing == null:
		return
	var own := client.body(papo_id)
	var yuni := client.body(CoopSession.HOST_ID)
	papo_hud.refresh()
	assert_false(papo_hud.spectate.active(), "a living rider at sea plays his own crossing")
	crossing._finish()
	assert_true(await wait_until(func() -> bool: return own.left_island, TIMEOUT_S), "Papo waits on the shore")
	assert_true(await wait_until(_watching(papo_hud, yuni), TIMEOUT_S), "the waiting Papo watches Yuni on the sandbar")
	assert_true(yuni.camera.enabled)
	assert_false(own.camera.enabled)
	assert_false(papo_hud.strip.visible, "the waiting rider's strip stays hidden")
	host.body(CoopSession.HOST_ID).meters.dead = true
	var landed := func() -> bool: return _travel(client).island.layout.id == COAST and not own.left_island
	assert_true(await wait_until(landed, TIMEOUT_S), "the coast cay loads and Papo lands")
	var stopped := func() -> bool:
		papo_hud.refresh()
		return not papo_hud.spectate.active()
	assert_true(await wait_until(stopped, TIMEOUT_S), "the landed Papo plays again, with nobody else alive to watch")
	assert_true(own.camera.enabled, "his own camera is back")
	assert_false(yuni.camera.enabled)
	assert_same(papo_hud.meters.shown(), own.meters)
	await wait_process_frames(2)
	assert_true(papo_hud.strip.visible, "the strip is back")
	assert_false(papo_hud.watching_panel.visible)
