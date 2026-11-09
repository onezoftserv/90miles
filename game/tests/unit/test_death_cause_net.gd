extends GutTest
## survival-meters "Cause of death" (a client has the cause with the death), coop-networking
## "Removed player's cause" and endings-progression "One-liner picked by the run seed" (the seed
## reaches a joiner), over ENet on localhost (NetHarness).

const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const TIMEOUT_S: float = 5.0
const SHARK: StringName = &"reef_shark"

var net: NetHarness


func before_each() -> void:
	net = NetHarness.new(self)


func after_each() -> void:
	net.teardown()


func _island(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()


func _named(player_name: String) -> Callable:
	return func(session: CoopSession) -> void:
		session.local_identity = PlayerIdentity.create()
		session.local_name = player_name


# Dayana and Papo play; returns [host, dayana, papo, papo's peer id].
func _two_clients() -> Array:
	var host := net.add_host(_island)
	var dayana := await net.join(_named("Dayana"))
	var papo := await net.join(_named("Papo"))
	assert_not_null(dayana)
	assert_not_null(papo)
	if dayana == null or papo == null:
		return []
	assert_true(await net.settle())
	return [host, dayana, papo, net.peer_id(papo)]


# Papo's connection closes and the host's countdown runs out; waits for the removal.
func _remove_papo(host: CoopSession, papo: CoopSession, papo_id: int) -> void:
	net.drop(papo)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(papo_id), TIMEOUT_S))
	host._dropped[papo_id] = 0.01
	assert_true(await wait_until(func() -> bool: return host.removed_names().size() == 1, TIMEOUT_S))


func test_a_client_has_the_cause_when_its_copy_dies() -> void:
	var host := net.add_host(_island)
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	var seen: Array[StringName] = []
	net.own_body(client).meters.died.connect(func() -> void: seen.append(net.own_body(client).meters.death_cause))
	var meters := host.body(net.peer_id(client)).meters
	meters.harm(200.0, SHARK)
	assert_true(meters.downed, "two living players: downed, not dead")
	meters.tick(90.0, MeterContext.new())
	assert_true(meters.dead)
	assert_true(await wait_until(func() -> bool: return not seen.is_empty(), TIMEOUT_S), "the client's copy died")
	assert_eq(seen[0], SHARK, "the cause was already there when died fired")


func test_a_removed_player_has_the_removed_cause_on_every_peer() -> void:
	var made := await _two_clients()
	if made.is_empty():
		return
	var host := made[0] as CoopSession
	var dayana := made[1] as CoopSession
	await _remove_papo(host, made[2] as CoopSession, made[3] as int)
	assert_eq(host.removed_names(), ["Papo"] as Array[String])
	assert_eq(host.removed_causes(), [&"removed"] as Array[StringName])
	assert_true(await wait_until(func() -> bool: return dayana.removed_names().size() == 1, TIMEOUT_S))
	assert_eq(dayana.removed_causes(), [&"removed"] as Array[StringName])


func test_a_dropped_player_who_died_away_keeps_that_cause() -> void:
	var host := net.add_host(_island)
	var papo := await net.join(_named("Papo"))
	assert_not_null(papo)
	if papo == null:
		return
	var papo_id: int = net.peer_id(papo)
	var away := host.body(papo_id)
	net.drop(papo)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(papo_id), TIMEOUT_S))
	away.meters.harm(100.0, &"drowning")
	away.meters.tick(90.0, MeterContext.new())
	assert_true(away.meters.dead, "he drowned while away")
	host._dropped[papo_id] = 0.01
	assert_true(await wait_until(func() -> bool: return host.removed_names().size() == 1, TIMEOUT_S))
	assert_eq(host.removed_causes(), [&"drowning"] as Array[StringName])


func test_a_later_joiner_receives_the_removed_causes() -> void:
	var made := await _two_clients()
	if made.is_empty():
		return
	var host := made[0] as CoopSession
	await _remove_papo(host, made[2] as CoopSession, made[3] as int)
	var yuni := await net.join(_named("Yuni"))
	assert_not_null(yuni)
	if yuni == null:
		return
	assert_true(await wait_until(func() -> bool: return yuni.removed_names().size() == 1, TIMEOUT_S))
	assert_eq(yuni.removed_names(), ["Papo"] as Array[String])
	assert_eq(yuni.removed_causes(), [&"removed"] as Array[StringName])


func test_the_run_seed_reaches_a_joiner() -> void:
	var host := net.add_host(func(session: CoopSession) -> void:
		_island(session)
		session.world_state = {"run_seed": 7})
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	assert_true(await wait_until(func() -> bool: return client.world_state.has("run_seed"), TIMEOUT_S))
	assert_eq(client.world_state["run_seed"], 7)
	assert_eq(host.world_state["run_seed"], 7)
