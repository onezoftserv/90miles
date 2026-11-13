extends GutTest
## art-pass "Player look slots" and "Four slots, four looks" over ENet on localhost (NetHarness;
## task 5.5; design.md D5, C2): the host gives each new body the lowest free look slot and sends it
## as the spawn payload's `look`, the only look data on the wire; every peer and every late joiner
## reads it into the body's plain `look_slot` and draws that slot's look from balsero_art.tres; a
## removed body frees its slot, a rejoin keeps it, a joiner while a dropped body waits takes the
## dropped body's slot. A solo player is slot 0.

const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const TIMEOUT_S: float = 5.0
const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const ART_PATH: String = "res://assets/art/characters/balsero_art.tres"
const PAYLOAD_KEYS: Array[String] = ["look", "peer", "position"]

var net: NetHarness
## Every player spawn payload a session received, by session.
var payloads: Dictionary = {}


func before_each() -> void:
	net = NetHarness.new(self)
	payloads.clear()


func after_each() -> void:
	net.teardown()
	payloads.clear()
	NetManager.leave()


# Spawn points, and every player payload recorded on its way into the session's spawn function.
func _island(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()
	var seen: Array[Dictionary] = []
	payloads[session] = seen
	var record := func(data: Variant) -> Node:
		if data is Dictionary:
			seen.append(data)
		return session._spawn_player(data)
	session.player_spawner.spawn_function = record


func _as(identity: PlayerIdentity, player_name: String) -> Callable:
	return func(session: CoopSession) -> void:
		_island(session)
		session.local_identity = identity
		session.local_name = player_name


func _slot(session: CoopSession, peer_id: int) -> int:
	var found: PlayerBody = session.body(peer_id)
	return found.look_slot if found != null else -1


func _look_of(body: PlayerBody) -> PlayerLook:
	return body.get_node(^"Look") as PlayerLook


func _slots_everywhere(peer_id: int, slot: int) -> bool:
	for session: CoopSession in net.sessions:
		if is_instance_valid(session) and session.body(peer_id) != null and session.body(peer_id).look_slot != slot:
			return false
	return true


func test_a_solo_player_is_slot_0() -> void:
	NetManager.start_solo()
	var session := SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	var body: PlayerBody = session.body(CoopSession.HOST_ID)
	assert_eq(body.look_slot, 0)
	var art: BodyArt = load(ART_PATH) as BodyArt
	assert_same(_look_of(body).look_data, art.look_for_slot(0), "and draws slot 0's look")


func test_joiners_take_the_lowest_free_slot_and_a_removed_one_frees_its_slot() -> void:
	var host := net.add_host(_island)
	assert_eq(_slot(host, CoopSession.HOST_ID), 0, "the host is slot 0")
	var first := await net.join(_island)
	var second := await net.join(_island)
	assert_not_null(first)
	assert_not_null(second)
	if first == null or second == null:
		return
	var first_id: int = net.peer_id(first)
	var second_id: int = net.peer_id(second)
	assert_eq(_slot(host, first_id), 1)
	assert_eq(_slot(host, second_id), 2)
	net.drop(first)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(first_id), TIMEOUT_S))
	host._physics_process(CoopSession.DISCONNECT_DOWNED_S + 1.0)
	assert_null(host.body(first_id), "the first client is removed")
	var third := await net.join(_island)
	assert_not_null(third)
	if third == null:
		return
	var third_id: int = net.peer_id(third)
	assert_eq(_slot(host, third_id), 1, "the third client gets the freed slot 1")
	assert_eq(_slot(host, second_id), 2, "the second keeps slot 2")
	assert_true(await net.settle())
	assert_true(await wait_until(func() -> bool: return _slots_everywhere(third_id, 1) and _slots_everywhere(second_id, 2), TIMEOUT_S), "every peer draws the same slots")


func test_a_late_joiner_draws_every_body_in_the_hosts_slot() -> void:
	var host := net.add_host(_island)
	var first := await net.join(_island)
	var second := await net.join(_island)
	assert_not_null(first)
	assert_not_null(second)
	if first == null or second == null:
		return
	var late := await net.join(_island)
	assert_not_null(late)
	if late == null:
		return
	assert_true(await net.settle())
	for peer_id: int in host.peer_ids():
		assert_eq(_slot(late, peer_id), _slot(host, peer_id), "peer %d" % peer_id)
	assert_eq(_slot(late, net.peer_id(late)), 3)


func test_a_joiner_while_a_dropped_body_waits_takes_its_slot() -> void:
	# art-pass "A joiner while a dropped body waits".
	var host := net.add_host(_island)
	var joined: Array[CoopSession] = []
	for i: int in 3:
		var client := await net.join(_island)
		assert_not_null(client, "client %d joined" % (i + 1))
		if client == null:
			return
		joined.append(client)
	var before: Dictionary = {}
	for peer_id: int in host.peer_ids():
		before[peer_id] = _slot(host, peer_id)
	var slots: Array = before.values()
	slots.sort()
	assert_eq(slots, [0, 1, 2, 3], "four players in slots 0 to 3")
	assert_eq(_slot(host, net.peer_id(joined[1])), 2, "the second client is slot 2")
	var dropped_id: int = net.peer_id(joined[1])
	net.drop(joined[1])
	assert_true(await wait_until(func() -> bool: return host.is_dropped(dropped_id), TIMEOUT_S))
	var again := await net.join(_island)
	assert_not_null(again, "a new client joins within 90 s")
	if again == null:
		return
	assert_eq(_slot(host, net.peer_id(again)), 2, "the new client gets slot 2")
	assert_eq(_slot(host, dropped_id), 2, "while the dropped body is still drawn in slot 2")
	for peer_id: int in before:
		assert_eq(_slot(host, peer_id), before[peer_id], "no other body changes slot (peer %d)" % peer_id)


func test_a_rejoin_within_the_downed_window_keeps_slot_1() -> void:
	var papo := PlayerIdentity.create()
	var host := net.add_host(_island)
	var client := await net.join(_as(papo, "Papo"))
	assert_not_null(client)
	if client == null:
		return
	var old_id: int = net.peer_id(client)
	assert_eq(_slot(host, old_id), 1)
	var papo_body: PlayerBody = host.body(old_id)
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(old_id), TIMEOUT_S))
	var back := await net.join(_as(papo, "Papo"))
	assert_not_null(back)
	if back == null:
		return
	var new_id: int = net.peer_id(back)
	assert_same(host.body(new_id), papo_body, "the same body")
	assert_eq(_slot(host, new_id), 1, "still slot 1 on the host")
	assert_true(await wait_until(func() -> bool: return _slot(back, new_id) == 1, TIMEOUT_S), "and on the rejoined client")


func test_a_spawn_payload_with_a_missing_or_out_of_range_look_gives_0() -> void:
	var host := net.add_host(_island)
	var cases: Array = [
		[{"peer": 50, "position": Vector2.ZERO}, 0],
		[{"peer": 51, "position": Vector2.ZERO, "look": 4}, 0],
		[{"peer": 52, "position": Vector2.ZERO, "look": -1}, 0],
		[{"peer": 53, "position": Vector2.ZERO, "look": "2"}, 0],
		[{"peer": 54, "position": Vector2.ZERO, "look": 2.0}, 0],
		[{"peer": 55, "position": Vector2.ZERO, "look": 3}, 3],
	]
	for entry: Array in cases:
		var made := host._spawn_player(entry[0]) as PlayerBody
		assert_eq(made.look_slot, entry[1], str(entry[0]))
		host._bodies.erase((entry[0] as Dictionary)["peer"])
		host._spawn_peer.erase((entry[0] as Dictionary)["peer"])
		made.free()


func test_every_peer_draws_a_slot_from_the_same_look_and_sends_only_the_look_key() -> void:
	# art-pass "Four slots, four looks": no look data beyond the slot.
	var host := net.add_host(_island)
	var client := await net.join(_island)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	var client_id: int = net.peer_id(client)
	var expected: Dictionary = {CoopSession.HOST_ID: "balsero", client_id: "balsera_triguena"}
	for session: CoopSession in [host, client]:
		for peer_id: int in expected:
			var look: PlayerLook = _look_of(session.body(peer_id))
			assert_not_null(look.look_data)
			if look.look_data == null:
				continue
			assert_eq(look.look_data.resource_path.get_file().get_basename(), expected[peer_id], "peer %d" % peer_id)
	assert_same(_look_of(host.body(client_id)).composed, _look_of(client.body(client_id)).composed, "one composite per look")
	for session: CoopSession in [host, client]:
		var seen: Array[Dictionary] = payloads[session]
		assert_gt(seen.size(), 0)
		for payload: Dictionary in seen:
			var keys: Array[String] = []
			for key: Variant in payload.keys():
				keys.append(str(key))
			keys.sort()
			assert_eq(keys, PAYLOAD_KEYS, "the spawn payload adds only look")
