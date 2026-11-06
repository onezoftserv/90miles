extends GutTest
## island-generation over ENet on localhost (NetHarness): a hosted run on the sandbar, a client's
## pick-up and the refresh as the client sees them.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TIMEOUT_S: float = 5.0

var net: NetHarness
var islands: Array[SandbarIsland] = []


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	net.teardown()
	for island: SandbarIsland in islands:
		island.free()
	islands.clear()


# The shell's order: the island, the session's terrain and spawn points, furnish. The harness
# calls this before start(); the host's pick-ups go down once its peer is open (host()).
func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	add_child(island)
	islands.append(island)
	session.terrain = island.terrain
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)


func _host() -> CoopSession:
	var host := net.add_host(_setup)
	islands[0].place_pickups(host)
	return host


func _pickups(session: CoopSession) -> Dictionary:
	var counts: Dictionary = {}
	for node: Node in session.pickups.get_children():
		var item := node as WorldItem
		if not item.is_queued_for_deletion():
			counts[item.item_id] = counts.get(item.item_id, 0) + item.count
	return counts


func _find(session: CoopSession, item_id: StringName) -> WorldItem:
	for node: Node in session.pickups.get_children():
		if (node as WorldItem).item_id == item_id and not node.is_queued_for_deletion():
			return node as WorldItem
	return null


func test_spawns_are_10_to_20_tiles_apart_and_the_client_sees_the_pickups() -> void:
	var host := _host()
	var a := await net.join(_setup)
	var b := await net.join(_setup)
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	assert_true(await net.settle())
	var ids: Array[int] = host.peer_ids()
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var tiles: float = host.body(ids[i]).position.distance_to(host.body(ids[j]).position) / 16.0
			assert_between(tiles, 10.0, 20.0)
	var same := func() -> bool: return _pickups(a) == _pickups(host) and _pickups(host).size() > 0
	assert_true(await wait_until(same, TIMEOUT_S), "the client sees the host's pick-ups")
	assert_eq(a.pickups.get_child_count(), 19)


func test_a_clients_pickup_is_applied_by_the_host() -> void:
	var host := _host()
	var a := await net.join(_setup)
	assert_not_null(a)
	if a == null:
		return
	assert_true(await net.settle())
	var a_id: int = net.peer_id(a)
	var tube := _find(host, &"inner_tube")
	host.body(a_id).global_position = tube.global_position
	tube.interactable.interacted.emit(host.body(a_id))
	var taken := func() -> bool:
		return host.body(a_id).inventory.count_id(&"inner_tube") == 1 and _pickups(a).get(&"inner_tube", 0) == 1
	assert_true(await wait_until(taken, TIMEOUT_S), "the host gave it and the tube vanished on the client")
	var synced := func() -> bool: return net.own_body(a).inventory.count_id(&"inner_tube") == 1
	assert_true(await wait_until(synced, TIMEOUT_S), "the client's inventory shows it")


func test_the_client_sees_the_refresh_and_never_places_one() -> void:
	var host := _host()
	var a := await net.join(_setup)
	assert_not_null(a)
	if a == null:
		return
	assert_true(await net.settle())
	var jug := _find(host, &"plastic_jug")
	jug.interactable.interacted.emit(host.body(1))
	var gone := func() -> bool: return _pickups(a).get(&"plastic_jug", 0) == 2
	assert_true(await wait_until(gone, TIMEOUT_S))
	WeatherManager.sky.weather.start_weather(&"squall")
	WeatherManager.sky.weather.start_weather(&"calm")
	var back := func() -> bool: return _pickups(a).get(&"plastic_jug", 0) == 3
	assert_true(await wait_until(back, TIMEOUT_S), "the client sees the jug again")
	await wait_seconds(0.3)
	assert_eq(_pickups(a), _pickups(host), "no extras from the client's own weather signal")


# A client's own intents cross the network the way a real client's do (PlayerNet sends the
# body's intent every frame); the host's body runs the interaction.
func _hold_interact(a: CoopSession, seconds: float) -> void:
	net.own_body(a).intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	await wait_seconds(seconds)
	net.own_body(a).intent = MoveIntent.new()
	await wait_seconds(0.2)


func test_a_client_holding_interact_next_to_a_pickup_takes_it() -> void:
	var host := _host()
	var a := await net.join(_setup)
	assert_not_null(a)
	if a == null:
		return
	assert_true(await net.settle())
	var a_id: int = net.peer_id(a)
	var tube := _find(host, &"inner_tube")
	host.body(a_id).global_position = tube.global_position
	await wait_physics_frames(3)
	await _hold_interact(a, 0.5)
	assert_eq(host.body(a_id).inventory.count_id(&"inner_tube"), 1, "in that client's inventory on the host")
	assert_eq(host.body(1).inventory.count_id(&"inner_tube"), 0, "not the host's")
	var gone := func() -> bool:
		return _pickups(a).get(&"inner_tube", 0) == 1 and _pickups(host).get(&"inner_tube", 0) == 1
	assert_true(await wait_until(gone, TIMEOUT_S), "one tube left on both peers")


func test_a_client_out_of_reach_takes_nothing() -> void:
	var host := _host()
	var a := await net.join(_setup)
	assert_not_null(a)
	if a == null:
		return
	assert_true(await net.settle())
	var a_id: int = net.peer_id(a)
	var tube := _find(host, &"inner_tube")
	host.body(a_id).global_position = tube.global_position + Vector2(64.0, 0.0)
	await wait_physics_frames(3)
	await _hold_interact(a, 0.5)
	assert_eq(host.body(a_id).inventory.count_id(&"inner_tube"), 0)
	assert_eq(_pickups(host).get(&"inner_tube", 0), 2, "the tube is still there")


func test_a_client_climbs_a_palm_and_pays_the_energy() -> void:
	var host := _host()
	var a := await net.join(_setup)
	assert_not_null(a)
	if a == null:
		return
	assert_true(await net.settle())
	var a_id: int = net.peer_id(a)
	var palm := islands[0].get_node("Palms").get_child(0) as Palm
	var body := host.body(a_id)
	body.meters.energy = 80.0
	body.global_position = palm.global_position
	await wait_physics_frames(3)
	var before: int = palm.coconuts
	await _hold_interact(a, islands[0].layout.climb_hold_s + 0.5)
	assert_eq(palm.coconuts, before - 1)
	assert_eq(body.inventory.count_id(&"coco"), 1)
	assert_almost_eq(body.meters.energy, 75.0, 0.5)
	var synced := func() -> bool: return net.own_body(a).inventory.count_id(&"coco") == 1
	assert_true(await wait_until(synced, TIMEOUT_S), "the client's inventory shows the coconut")


func test_a_client_out_of_reach_cannot_climb_a_palm() -> void:
	var host := _host()
	var a := await net.join(_setup)
	assert_not_null(a)
	if a == null:
		return
	assert_true(await net.settle())
	var a_id: int = net.peer_id(a)
	var palm := islands[0].get_node("Palms").get_child(0) as Palm
	var body := host.body(a_id)
	body.meters.energy = 80.0
	body.global_position = palm.global_position + Vector2(64.0, 0.0)
	await wait_physics_frames(3)
	var before: int = palm.coconuts
	await _hold_interact(a, islands[0].layout.climb_hold_s + 0.5)
	assert_eq(palm.coconuts, before)
	assert_eq(body.inventory.count_id(&"coco"), 0)
	assert_almost_eq(body.meters.energy, 80.0, 0.5)
