extends GutTest
## coop-networking over ENet on localhost: a host and clients in one process (NetHarness).
## Joining, spawning, the player cap, intents, prediction against the host, and the RPC rules.

const TILE: float = 16.0
const EAST := Vector2.RIGHT
const ENTITY_SCENE: String = "res://tests/fixtures/fixture_entity.tscn"
const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const WORLD: Dictionary = {"island_seed": 1234, "weather": &"squall", "time_of_day_s": 360.0}
const TIMEOUT_S: float = 5.0

var net: NetHarness


func before_each() -> void:
	net = NetHarness.new(self)


func after_each() -> void:
	net.teardown()


# The host's island: spawn points, world state and the entity scenes it can spawn.
func _island(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()
	session.world_state = WORLD.duplicate()
	session.entity_spawner.add_spawnable_scene(ENTITY_SCENE)


# A client only needs to know which entity scenes exist; the rest comes from the host.
func _client(session: CoopSession) -> void:
	session.entity_spawner.add_spawnable_scene(ENTITY_SCENE)


func _sorted(ids: Array[int]) -> Array[int]:
	var copy: Array[int] = ids.duplicate()
	copy.sort()
	return copy


# An interactable that exists only on the host, as items will.
func _coconut(at: Vector2) -> Interactable:
	var coconut := Interactable.new()
	coconut.hold_time_s = 0.0
	coconut.position = at
	net.branches[0].add_child(coconut)
	return coconut


# --- host and join -----------------------------------------------------------------------

func test_second_player_joins_mid_island() -> void:
	var host := net.add_host(_island)
	var crate := (load(ENTITY_SCENE) as PackedScene).instantiate() as Node2D
	crate.name = "Crate"
	crate.position = Vector2(100.0, 120.0)
	host.entities.add_child(crate, true)
	var client := await net.join(_client)
	assert_not_null(client, "the client joined")
	if client == null:
		return
	var got_world: bool = await wait_until(func() -> bool: return not client.world_state.is_empty(), TIMEOUT_S)
	assert_true(got_world, "world state received")
	assert_eq(client.world_state, WORLD)
	assert_eq(client.peer_ids(), _sorted([1, net.peer_id(client)] as Array[int]))
	assert_eq(net.own_body(client).position, SPAWNS[1], "spawns at the next beach spawn point")
	var got_crate: bool = await wait_until(func() -> bool: return client.entities.get_node_or_null(^"Crate") != null, TIMEOUT_S)
	assert_true(got_crate, "existing entities reach the joiner")
	if got_crate:
		assert_eq((client.entities.get_node(^"Crate") as Node2D).position, Vector2(100.0, 120.0))


func test_a_late_joiner_receives_every_player() -> void:
	var host := net.add_host(_island)
	var a := await net.join(_client)
	var b := await net.join(_client)
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	assert_true(await net.settle(), "every peer sees every player")
	var expected := _sorted([1, net.peer_id(a), net.peer_id(b)] as Array[int])
	assert_eq(host.peer_ids(), expected)
	assert_eq(a.peer_ids(), expected)
	assert_eq(b.peer_ids(), expected)
	assert_eq(net.own_body(b).position, SPAWNS[2])


func test_a_peer_that_connected_before_the_host_started_still_gets_a_player() -> void:
	var host := net.add_host(_island, false)
	var client := net.add_client(_client)
	assert_true(await net.wait_connected(client))
	var id: int = net.peer_id(client)
	var host_knows_it := func() -> bool: return host.multiplayer.get_peers().has(id)
	assert_true(await wait_until(host_knows_it, TIMEOUT_S), "the host has the peer before start()")
	await wait_process_frames(5)
	host.start()
	var spawned := func() -> bool: return host.body(id) != null and client.body(id) != null
	assert_true(await wait_until(spawned, TIMEOUT_S), "the early peer is added at start()")


func test_fifth_player_is_refused() -> void:
	var host := net.add_host(_island)
	for i: int in 3:
		assert_not_null(await net.join(_client), "client %d joined" % (i + 1))
	var fifth := net.add_client(_client)
	await wait_seconds(1.0)
	assert_eq(host.peer_ids().size(), 4, "the four players stay")
	assert_ne(fifth.multiplayer.multiplayer_peer.get_connection_status(), MultiplayerPeer.CONNECTION_CONNECTED)
	assert_eq(fifth.peer_ids().size(), 0)


# --- host authority ----------------------------------------------------------------------

func test_a_clients_intents_move_it_on_the_host_and_the_prediction_matches_exactly() -> void:
	net.add_host(_island)
	var client := await net.join(_client)
	assert_not_null(client)
	if client == null:
		return
	var mine := net.own_body(client)
	var copy := net.sessions[0].body(net.peer_id(client))
	mine.intent = MoveIntent.create(EAST)
	await wait_physics_frames(30)
	mine.intent = MoveIntent.new()
	var predicted := mine.position
	assert_gt(predicted.x, SPAWNS[1].x + TILE, "the client's player walked east at once")
	var caught_up: bool = await wait_until(func() -> bool: return copy.position == predicted, TIMEOUT_S)
	assert_true(caught_up, "the host stepped the same intents to the same position")
	await wait_seconds(0.2)
	assert_eq(mine.position, predicted, "no correction was needed")
	assert_eq(copy.position, predicted)


func test_a_forced_correction_reconciles_to_the_host() -> void:
	net.add_host(_island)
	var client := await net.join(_client)
	assert_not_null(client)
	if client == null:
		return
	var mine := net.own_body(client)
	var copy := net.sessions[0].body(net.peer_id(client))
	mine.intent = MoveIntent.create(EAST)
	await wait_physics_frames(20)
	# The host moves the player somewhere the client did not predict (a current, a wall).
	copy.position += Vector2(3.0 * TILE, 0.0)
	await wait_physics_frames(10)
	mine.intent = MoveIntent.new()
	var reconciled: bool = await wait_until(func() -> bool: return mine.position == copy.position, TIMEOUT_S)
	assert_true(reconciled, "the client ends exactly where the host has it")
	assert_gt(mine.position.x, SPAWNS[1].x + 4.0 * TILE, "the correction and the walk both count")
	await wait_seconds(0.2)
	assert_eq(mine.position, copy.position)


func test_client_claims_an_item_it_is_not_near() -> void:
	net.add_host(_island)
	var client := await net.join(_client)
	assert_not_null(client)
	if client == null:
		return
	var far := _coconut(SPAWNS[1] + Vector2(10.0 * TILE, 0.0))
	watch_signals(far)
	var mine := net.own_body(client)
	var copy := net.sessions[0].body(net.peer_id(client))
	mine.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	await wait_physics_frames(20)
	mine.intent = MoveIntent.new()
	var sent: int = mine.net.buffer.last_seq
	assert_true(await wait_until(func() -> bool: return copy.net.net_ack_seq >= sent, TIMEOUT_S), "host processed the intents")
	assert_signal_not_emitted(far, "interacted")


func test_the_host_runs_the_interaction_of_a_client_in_reach() -> void:
	net.add_host(_island)
	var client := await net.join(_client)
	assert_not_null(client)
	if client == null:
		return
	var near := _coconut(SPAWNS[1] + Vector2(0.5 * TILE, 0.0))
	watch_signals(near)
	var mine := net.own_body(client)
	var copy := net.sessions[0].body(net.peer_id(client))
	mine.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	await wait_physics_frames(20)
	mine.intent = MoveIntent.new()
	var sent: int = mine.net.buffer.last_seq
	assert_true(await wait_until(func() -> bool: return copy.net.net_ack_seq >= sent, TIMEOUT_S))
	assert_signal_emitted_with_parameters(near, "interacted", [copy])


# --- RPC rules ---------------------------------------------------------------------------

func test_client_acts_as_a_teammate_and_only_its_own_player_moves() -> void:
	var host := net.add_host(_island)
	var a := await net.join(_client)
	var b := await net.join(_client)
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	assert_true(await net.settle())
	var a_copy := host.body(net.peer_id(a))
	var b_copy := host.body(net.peer_id(b))
	net.own_body(a).intent = MoveIntent.create(EAST)
	await wait_physics_frames(30)
	net.own_body(a).intent = MoveIntent.new()
	# The intent message names no player; even a broadcast from A lands as A's own.
	a.submit_intent.rpc(1000000, Vector2.LEFT, false, false, false, 0.05)
	await wait_seconds(0.3)
	assert_gt(a_copy.position.x, SPAWNS[1].x, "A's own player moved")
	assert_eq(b_copy.position, SPAWNS[2], "B's player stayed on the host")
	assert_eq(net.own_body(b).position, SPAWNS[2], "and on B")


func test_client_forges_a_host_message() -> void:
	var host := net.add_host(_island)
	var a := await net.join(_client)
	var b := await net.join(_client)
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	var both_got_world := func() -> bool: return not a.world_state.is_empty() and not b.world_state.is_empty()
	assert_true(await wait_until(both_got_world, TIMEOUT_S))
	a.receive_world_state.rpc({"island_seed": 666, "weather": &"hurricane", "time_of_day_s": 0.0})
	await wait_seconds(0.3)
	assert_eq(b.world_state, WORLD, "B ignores it")
	assert_eq(host.world_state, WORLD, "the host ignores it")
	assert_eq(a.world_state, WORLD, "A's own local call is ignored too")
	assert_engine_error("not allowed", "the host's engine refuses a non-authority call")
