extends GutTest
## island-pressure tasks 2.3, 3.3 and 5.2, a host and a client over ENet on localhost (NetHarness), on
## the sandbar with its patrol boat on the host: by day a client's launch request is seen, nobody leaves
## on either peer, the alert names the client's player and both peers see the boat dock; at night out
## of the light the host starts the raft for both; the client's own prompt shows the day warning and a
## staged site's stage line and stage bar as the host has them (inventory-hud "Launch warning", "Progress
## seen by a client"; guardacostas-stealth "Co-op party spotted"; escape-routes "Client asks, host picks").

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const SANDBAR: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
const TIMEOUT_S: float = 6.0
const HOUR_S: float = 30.0
const AFTERNOON_S: float = 8.0 * HOUR_S
const NIGHT_S: float = 16.0 * HOUR_S
const RAFT_TIME_S: float = 120.0

var net: NetHarness
var patrol: PatrolData
var huds: Array[Node] = []
var started: Dictionary[StringName, Array] = {}


func before_each() -> void:
	net = NetHarness.new(self)
	patrol = (GameState.content.get_entry(&"creatures", &"patrol_boat") as CreatureData).patrol
	huds.clear()
	started.clear()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	WeatherManager.sky.weather.start_weather(&"calm")


func after_each() -> void:
	for hud: Node in huds:
		if is_instance_valid(hud):
			hud.free()
	huds.clear()
	net.teardown()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.with_creatures = false
	session.get_parent().add_child(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)


func _pair() -> Array[CoopSession]:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return []
	assert_true(await net.settle())
	net.silence_input()
	for session: CoopSession in [host, client]:
		var routes := session.get_node("Routes") as IslandRoutes
		var key: StringName = &"host" if session == host else &"client"
		started[key] = []
		routes.route_started.connect(func(id: StringName, peers: Array[int]) -> void: started[key].append([id, peers]))
	return [host, client] as Array[CoopSession]


# The host's spawner with the sandbar's boat, out of sight, in calm weather.
func _boat(host: CoopSession) -> Creature:
	var spawner := CreatureSpawner.new()
	spawner.name = SandbarIsland.CREATURES_NAME
	host.add_child(spawner)
	spawner.setup(host, SANDBAR)
	spawner.party_size = 2
	spawner.world.phase = host.climate.phase
	spawner.world.weather_override = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	spawner.spawn_permanent()
	var boat: Creature = spawner.creatures(&"patrol_boat")[0]
	(boat.brain as PatrolRoute).set_clock(patrol.horizon_warning_s + patrol.route_lap_s + 1.0)
	boat.advance(0.0)
	return boat


func _client_boat(client: CoopSession) -> Creature:
	var boats := LaunchSight.boats_of(client)
	return boats[0] if not boats.is_empty() else null


# The host builds the raft; both players stand beside it on both peers.
func _beside_the_raft(host: CoopSession, client: CoopSession) -> bool:
	var site := host.get_node("RaftSite") as BuildSite
	for id: StringName in site.recipe.inputs:
		site.deposited[id] = site.recipe.inputs[id]
	site.work(1.0)
	var built := func() -> bool: return client.get_node_or_null("Raft") is Raft
	if not await wait_until(built, TIMEOUT_S):
		return false
	var at: Vector2 = (host.get_node("Raft") as Raft).global_position
	var me: int = net.peer_id(client)
	for peer: int in [CoopSession.HOST_ID, me]:
		var offset := Vector2(0.0 if peer == CoopSession.HOST_ID else 6.0, 0.0)
		host.body(peer).global_position = at + offset
		client.body(peer).global_position = at + offset
	return true


func _hud(session: CoopSession) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	huds.append(hud)
	hud.bind(session, net.peer_id(session), false)
	return hud


# guardacostas-stealth "Co-op party spotted", and a client's day request refused on both peers.
func test_a_clients_day_launch_is_seen_and_both_see_the_boat_dock() -> void:
	WeatherManager.sky.start_at(AFTERNOON_S)
	var pair := await _pair()
	if pair.is_empty():
		return
	var host: CoopSession = pair[0]
	var client: CoopSession = pair[1]
	var me: int = net.peer_id(client)
	var boat := _boat(host)
	var alerts: Array = []
	boat.patrol_alerted.connect(func(cause: StringName, at: Vector2) -> void: alerts.append([cause, at]))
	assert_true(await _beside_the_raft(host, client), "the raft built on both peers")
	assert_true(await wait_until(func() -> bool: return _client_boat(client) != null, TIMEOUT_S), "the client has the boat")
	client.start_route(&"raft")
	assert_true(await wait_until(func() -> bool: return boat.state_id == PatrolRoute.State.DOCKED, TIMEOUT_S), "the host's boat docks")
	assert_eq(alerts.size(), 1)
	if alerts.size() == 1:
		assert_eq(alerts[0][0], &"launch")
		assert_eq(alerts[0][1], host.body(me).global_position, "the alert names the client's player")
	assert_eq((boat.brain as PatrolRoute).locked, host.body(me), "and the light follows them")
	var docked := func() -> bool: return _client_boat(client).state_id == PatrolRoute.State.DOCKED
	assert_true(await wait_until(docked, TIMEOUT_S), "the client sees the boat dock")
	await wait_physics_frames(10)
	for peer: int in [CoopSession.HOST_ID, me]:
		assert_false(host.has_left(peer), "nobody left on the host")
		assert_false(client.has_left(peer), "nobody left on the client")
	assert_eq(started[&"host"], [], "no route started on the host")
	assert_eq(started[&"client"], [], "nor on the client")
	assert_not_null(host.get_node_or_null("Raft"), "the raft stays on the beach")


# escape-routes "Client asks, host picks": at night, out of every searchlight.
func test_at_night_out_of_the_light_the_host_starts_the_raft_for_both() -> void:
	WeatherManager.sky.start_at(NIGHT_S)
	var pair := await _pair()
	if pair.is_empty():
		return
	var host: CoopSession = pair[0]
	var client: CoopSession = pair[1]
	var me: int = net.peer_id(client)
	var boat := _boat(host)
	assert_true(await _beside_the_raft(host, client))
	assert_null(LaunchSight.seen_in(host, host.body(me).global_position), "nobody sees it")
	client.start_route(&"raft")
	var both := func() -> bool: return host.has_left(CoopSession.HOST_ID) and host.has_left(me) and client.has_left(me) and client.has_left(CoopSession.HOST_ID)
	assert_true(await wait_until(both, TIMEOUT_S), "the raft leaves with both, on both peers")
	assert_eq(boat.state_id, PatrolRoute.State.AWAY, "the boat raised nothing")


# inventory-hud "A client sees the warning".
func test_a_client_sees_the_day_warning() -> void:
	WeatherManager.sky.start_at(AFTERNOON_S)
	var pair := await _pair()
	if pair.is_empty():
		return
	var host: CoopSession = pair[0]
	var client: CoopSession = pair[1]
	_boat(host)
	assert_true(await _beside_the_raft(host, client))
	assert_true(await wait_until(func() -> bool: return _client_boat(client) != null, TIMEOUT_S))
	var hud := _hud(client)
	hud.prompt.tick(0.1)
	var lines := hud.prompt.lines()
	assert_eq(lines[0] if not lines.is_empty() else "", "[E] Zarpar en la balsa")
	assert_true(lines.has("De día te ve la lancha."), "lines: %s" % lines)
	assert_true(lines.has("Sal de noche o con turbonada."))


# inventory-hud "Progress seen by a client": the host's site at 45 of 120 s.
func test_a_client_reads_the_stage_and_its_bar() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host: CoopSession = pair[0]
	var client: CoopSession = pair[1]
	var me: int = net.peer_id(client)
	var site := host.get_node("RaftSite") as BuildSite
	for id: StringName in site.recipe.inputs:
		site.deposited[id] = site.recipe.inputs[id]
	site.work(45.0 / RAFT_TIME_S)
	var mirror := client.get_node("RaftSite") as BuildSite
	var synced := func() -> bool: return absf(mirror.progress() - site.progress()) < 0.0001 and mirror.inputs_complete()
	assert_true(await wait_until(synced, TIMEOUT_S), "the client has the host's progress and deposits")
	host.body(me).global_position = site.global_position
	client.body(me).global_position = site.global_position
	var hud := _hud(client)
	hud.prompt.tick(0.1)
	assert_eq(hud.prompt.lines(), PackedStringArray(["[E] Construir Balsa", "Etapa 2/4: Armar el piso", "50 %"]))
	assert_almost_eq(hud.prompt.bar_progress(), 0.5, 0.001)
