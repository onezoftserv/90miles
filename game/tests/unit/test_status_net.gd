extends GutTest
## status-sync over ENet on localhost (NetHarness): a player's statuses are host state that reaches
## every peer. A client bitten in a crossing knows it bleeds and learns when it stops; a late joiner
## sees who bleeds.

const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const BLEEDING := DataEnums.Status.BLEEDING
const TIMEOUT_S: float = 5.0

var net: NetHarness
var rng := RandomNumberGenerator.new()


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	net.teardown()


func _setup(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()


func test_a_client_bitten_in_a_crossing_knows_it_bleeds() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	var client_id: int = net.peer_id(client)
	var route := GameState.content.get_entry(&"routes", &"raft") as RouteData
	var riders: Array[int] = host.peer_ids()
	Crossing.launch(client, route, riders, 100.0, DataEnums.DistanceBand.COAST, rng)
	var crossing := Crossing.launch(host, route, riders, 100.0, DataEnums.DistanceBand.COAST, rng)
	crossing.plan = CrossingPlan.create(600.0)
	crossing.throw_in(client_id)
	var own := net.own_body(client)
	watch_signals(own.meters)
	crossing.bite_swimmer(client_id)
	var bleeds := func() -> bool: return own.meters.has_status(BLEEDING)
	assert_true(await wait_until(bleeds, TIMEOUT_S), "the client's own player bleeds there too")
	assert_signal_emitted(own.meters, "statuses_changed", "and the client hears of it")
	host.body(client_id).meters.set_status(BLEEDING, false)
	var stopped := func() -> bool: return not own.meters.has_status(BLEEDING)
	assert_true(await wait_until(stopped, TIMEOUT_S), "the host ends it and so does the client")


func test_a_client_cannot_start_a_status() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var client_id: int = net.peer_id(client)
	net.own_body(client).meters.set_status(BLEEDING, true)
	await wait_physics_frames(10)
	assert_false(host.body(client_id).meters.has_status(BLEEDING), "the host never takes it")
	var overwritten := func() -> bool: return not net.own_body(client).meters.has_status(BLEEDING)
	assert_true(await wait_until(overwritten, TIMEOUT_S), "and its own sync puts the host's back")


func test_a_late_joiner_sees_who_bleeds() -> void:
	var host := net.add_host(_setup)
	host.body(1).meters.set_status(BLEEDING, true)
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	var sees := func() -> bool: return late.body(1) != null and late.body(1).meters.has_status(BLEEDING)
	assert_true(await wait_until(sees, TIMEOUT_S), "the late joiner has the host's player bleeding")
