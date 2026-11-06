extends GutTest
## weather-daynight "Weather sync": the host owns clock and weather; a joiner gets them on join,
## clients follow changes and the periodic resync, and ignore forged or never-rolled weather.
## A host and clients in one process (NetHarness), each branch with its own sky.

const TIMEOUT_S: float = 5.0

var net: NetHarness
var host_sky: WorldSky


func before_each() -> void:
	net = NetHarness.new(self)
	host_sky = WorldSky.from_catalog(GameState.content)


func after_each() -> void:
	net.teardown()


func _host(session: CoopSession) -> void:
	session.sky = host_sky


func _client(session: CoopSession) -> void:
	var sky := WorldSky.from_catalog(GameState.content)
	sky.weather.rolls_enabled = false
	session.sky = sky


func test_a_joiner_receives_squall_at_night() -> void:
	host_sky.start_at(450.0)
	host_sky.weather.start_weather(&"squall")
	net.add_host(_host)
	var client := await net.join(_client)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await wait_until(func() -> bool: return client.sky.weather.current.id == &"squall", TIMEOUT_S))
	assert_eq(client.sky.clock.phase(), DataEnums.DayPhase.NIGHT)
	assert_almost_eq(client.sky.clock.time_of_day_s, 450.0, 1.0)


func test_a_client_follows_the_hosts_squall() -> void:
	host_sky.start_at(200.0)
	net.add_host(_host)
	var client := await net.join(_client)
	if client == null:
		fail_test("join failed")
		return
	host_sky.weather.warn_weather(&"squall")
	assert_true(await wait_until(func() -> bool: return client.sky.weather.pending_in_s > 0.0, TIMEOUT_S), "the client sees the warning")
	host_sky.advance(60.0)
	assert_true(await wait_until(func() -> bool: return client.sky.weather.current.id == &"squall", TIMEOUT_S), "then the squall")


func test_a_client_takes_the_hosts_phase_change() -> void:
	host_sky.start_at(359.0)
	net.add_host(_host)
	var client := await net.join(_client)
	if client == null:
		fail_test("join failed")
		return
	host_sky.advance(2.0)
	assert_true(await wait_until(func() -> bool: return client.sky.clock.phase() == DataEnums.DayPhase.DUSK, TIMEOUT_S))


func test_the_host_resyncs_a_drifting_client() -> void:
	host_sky.start_at(100.0)
	host_sky.tuning = host_sky.tuning.duplicate()
	host_sky.tuning.resync_s = 0.2
	net.add_host(_host)
	var client := await net.join(_client)
	if client == null:
		fail_test("join failed")
		return
	client.sky.start_at(0.0)
	assert_true(await wait_until(func() -> bool: return absf(client.sky.clock.time_of_day_s - 100.0) < 5.0, TIMEOUT_S))


func test_a_forged_clock_message_is_ignored() -> void:
	host_sky.start_at(100.0)
	net.add_host(_host)
	var first := await net.join(_client)
	var second := await net.join(_client)
	if first == null or second == null:
		fail_test("join failed")
		return
	assert_true(await net.settle())
	second.sky.start_at(300.0)
	var forged: Dictionary = {"time_of_day_s": 10.0, "day": 1, "weather": &"squall", "weather_left_s": 50.0, "pending": &"", "pending_in_s": -1.0}
	first.receive_sky.rpc(forged)
	await wait_frames(30)
	assert_eq(second.sky.weather.current.id, &"calm")
	assert_gt(second.sky.clock.time_of_day_s, 299.0)


func test_a_client_never_rolls() -> void:
	host_sky.start_at(59.0)
	net.add_host(_host)
	var client := await net.join(_client)
	if client == null:
		fail_test("join failed")
		return
	client.sky.start_at(359.5)
	client.sky.advance(1.0)
	assert_null(client.sky.weather.pending)
