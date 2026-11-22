extends GutTest
## guardacostas-capture, group 8 (spec "Taken captives", design.md §7) over ENet on localhost
## (NetHarness): a squad that rows out with a captive while another player is free takes them. The
## taken player is out of play like a rider on the next shore, keeps only their keepsakes, leaves their
## secret items on the landing beach for every peer to see, counts as gone from the island, and lands
## with the party on the next island loaded. Each branch builds the island and its IslandTravel the way
## the shell does; the squad's leaving is the host keeper's `on_rowed_out`, as a docked boat calls it.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const FOTO: ItemData = preload("res://tests/fixtures/content/items/foto_test.tres")
const TIMEOUT_S: float = 6.0
const COAST: StringName = &"coast_cay"
const SANDBAR: StringName = &"sandbar"

var net: NetHarness
var patrol: PatrolData


func before_each() -> void:
	net = NetHarness.new(self)
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


func _travel(session: CoopSession) -> IslandTravel:
	return session.get_node("Travel") as IslandTravel


func _island_id(session: CoopSession) -> StringName:
	return _travel(session).island.layout.id


func _pair() -> Array[CoopSession]:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	return [host, client] as Array[CoopSession]


func _on_both(sessions: Array[CoopSession], island_id: StringName) -> Callable:
	return func() -> bool:
		for session: CoopSession in sessions:
			if _island_id(session) != island_id:
				return false
		return true


func _landing(session: CoopSession) -> Vector2:
	return IslandLayout.cell_center(_travel(session).island.built.landing_cells()[0])


# The host's copy of `peer`'s body is captured, seated on the landing and rowed out with.
func _take(host: CoopSession, peer: int) -> PlayerBody:
	var captive := host.body(peer)
	CaptureRules.capture(captive, host.body(CoopSession.HOST_ID), patrol)
	captive.seat_captive(_landing(host))
	CaptureScene.of(host).on_rowed_out([captive] as Array[PlayerBody], _landing(host))
	return captive


func _result(peer: int) -> CrossingResult:
	var result := CrossingResult.new()
	result.route_id = &"raft"
	result.integrity = 70.0
	result.riders[peer] = {"health": 90.0, "energy": 50.0, "aboard": true, "dead": false}
	return result


func _end_crossing(peer: int) -> void:
	var result := _result(peer)
	for session: CoopSession in net.sessions:
		if is_instance_valid(session) and session.body(peer) != null:
			_travel(session).crossing_ended(result)


# Spec "Taken, and back on the next island": a knife, 2 rope and the Foto; only the Foto lands.
func test_a_taken_client_lands_on_the_next_island_with_the_foto_only() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var id: int = net.peer_id(client)
	for session: CoopSession in pair:
		session.body(id).inventory.register(FOTO)
	var captive := host.body(id)
	captive.inventory.add(&"knife", 1)
	captive.inventory.add(&"rope", 2)
	captive.inventory.add(&"foto_test", 1)
	_take(host, id)
	assert_true(captive.taken, "taken")
	assert_false(captive.captive, "out of play, not sitting in the dinghy")
	assert_true(captive.left_island, "held like a rider on the next shore")
	assert_false(captive.visible)
	assert_eq(captive.inventory.count_id(&"knife"), 0, "every item gone")
	assert_eq(captive.inventory.count_id(&"rope"), 0)
	assert_eq(captive.inventory.count_id(&"foto_test"), 1, "but the keepsake")
	assert_eq(_island_id(host), SANDBAR, "the host's player is still free on the sandbar")
	assert_true(await wait_until(func() -> bool: return client.body(id).left_island and not client.body(id).visible, TIMEOUT_S), "out of play on the client too")
	await wait_frames(5)
	assert_eq(_island_id(host), SANDBAR)
	# The host's player crosses to the coast cay: both land there.
	_end_crossing(CoopSession.HOST_ID)
	assert_true(await wait_until(_on_both(pair, COAST), TIMEOUT_S), "the coast cay loads on both peers")
	for session: CoopSession in pair:
		var landed := session.body(id)
		assert_false(landed.left_island, "the taken player lands with the party")
		assert_true(landed.visible)
	assert_false(captive.taken, "no longer taken once landed")
	var shown := func() -> bool:
		var theirs := client.body(id)
		return theirs.inventory.count_id(&"foto_test") == 1 and theirs.inventory.count_id(&"knife") == 0 and theirs.inventory.count_id(&"rope") == 0
	assert_true(await wait_until(shown, TIMEOUT_S), "the client sees only the Foto")


# Spec "The compass stays behind": the broken compass lies on the landing beach on every peer.
func test_a_taken_captives_compass_stays_on_the_landing_beach() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var id: int = net.peer_id(client)
	host.body(id).inventory.add(&"brujula_rota", 1)
	_take(host, id)
	assert_eq(host.body(id).inventory.count_id(&"brujula_rota"), 0, "it does not go with them")
	var lying := func(session: CoopSession) -> bool:
		for node: Node in session.pickups.get_children():
			var item := node as WorldItem
			if item != null and item.item_id == &"brujula_rota" and item.global_position.distance_to(_landing(host)) < 1.0:
				return true
		return false
	assert_true(lying.call(host), "on the host's landing beach")
	assert_true(await wait_until(func() -> bool: return lying.call(client), TIMEOUT_S), "and on the client's")


# Spec "The island empties": the first player waits on the coast cay's shore, the second is taken.
func test_the_island_empties_when_the_only_other_player_waits_on_the_next_shore() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var id: int = net.peer_id(client)
	_end_crossing(CoopSession.HOST_ID)
	await wait_frames(3)
	assert_eq(_island_id(host), SANDBAR, "the client's player is still on the sandbar")
	_take(host, id)
	assert_true(await wait_until(_on_both(pair, COAST), TIMEOUT_S), "the coast cay loads, and both players land on it")
	for session: CoopSession in pair:
		assert_false(session.body(CoopSession.HOST_ID).left_island)
		assert_false(session.body(id).left_island)
