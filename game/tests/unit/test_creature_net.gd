extends GutTest
## creatures-ai "Host-run creatures": the host spawns and runs them, a client only draws them.

const TIMEOUT_S: float = 5.0

var net: NetHarness


func before_each() -> void:
	net = NetHarness.new(self)


func after_each() -> void:
	net.teardown()


func _data(id: StringName) -> CreatureData:
	return GameState.content.get_entry(&"creatures", id) as CreatureData


func _client_has(client: CoopSession, count: int) -> bool:
	return await wait_until(func() -> bool: return client.entities.get_child_count() == count, TIMEOUT_S)


func test_a_client_draws_the_hosts_crab_and_cannot_move_it() -> void:
	var host := net.add_host()
	var client := await net.join()
	var crab := host.spawn_creature(_data(&"land_crab"), Vector2(40.0, 40.0))
	assert_true(await _client_has(client, 1))
	var theirs := client.entities.get_child(0) as Creature
	assert_eq(theirs.name, crab.name)
	assert_eq(theirs.position, crab.position)
	var before := theirs.position
	theirs.advance(5.0)
	assert_eq(theirs.position, before, "a client tick moves nothing")


func test_a_shoo_from_6_tiles_is_refused_and_from_1_tile_is_accepted() -> void:
	var host := net.add_host()
	var client := await net.join()
	var gull := host.spawn_creature(_data(&"seagull"), Vector2(200.0, 200.0))
	assert_true(await _client_has(client, 1))
	var body := host.body(net.peer_id(client))
	body.global_position = gull.position + Vector2(6.0 * 16.0, 0.0)
	client.shoo(gull.name)
	await wait_seconds(0.5)
	assert_eq(gull.state_name(), &"PERCH")
	body.global_position = gull.position + Vector2(16.0, 0.0)
	client.shoo(gull.name)
	assert_true(await wait_until(func() -> bool: return gull.state_name() == &"FLEE", TIMEOUT_S))


func test_a_late_joiner_sees_the_six_crabs() -> void:
	var host := net.add_host()
	for i: int in 6:
		host.spawn_creature(_data(&"land_crab"), Vector2(40.0 + 16.0 * i, 40.0))
	var client := await net.join()
	assert_true(await _client_has(client, 6))
