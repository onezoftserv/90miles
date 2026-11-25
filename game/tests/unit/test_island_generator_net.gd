extends GutTest
## island-generator design §6 and §7 over ENet on localhost (NetHarness): host and client build the
## same generated reef from the run seed, a bad travel message changes nothing, a late joiner builds
## the host's island from the world state, a client whose template differs takes the host's text
## once, and a client sees the dawn refill without placing anything.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TIMEOUT_S: float = 6.0
const REEF: StringName = &"reef_traps"
const RUN_SEED: int = 1

var net: NetHarness
var island: GeneratedIsland


func before_all() -> void:
	island = ReefSamples.island(RUN_SEED)


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	net.teardown()
	WeatherManager.stop()


# The shell's order (as test_coast_cay_net.gd builds it), with the run seed the host keeps.
func _setup(session: CoopSession) -> void:
	session.world_state["run_seed"] = RUN_SEED
	var scene := ISLAND_SCENE.instantiate() as SandbarIsland
	scene.with_creatures = false
	session.get_parent().add_child(scene)
	session.terrain = scene.terrain
	session.climate = scene.climate
	session.spawn_points = scene.spawn_points(false)
	scene.furnish(session)
	var travel := IslandTravel.new()
	travel.name = "Travel"
	session.add_child(travel)
	travel.setup(session, scene)


# A client whose reef template is a tampered copy: it builds another island from the same seed.
func _tampered_setup(session: CoopSession) -> void:
	_setup(session)
	_travel(session).chain_overrides = {REEF: _tampered()}


func _tampered() -> ChainData:
	var copy := ReefSamples.chain().duplicate() as ChainData
	copy.poi_chances = {&"palm_grove": 0.0 if not island.built.palms.is_empty() else 1.0}
	return copy


func _travel(session: CoopSession) -> IslandTravel:
	return session.get_node("Travel") as IslandTravel


func _layout(session: CoopSession) -> IslandLayoutData:
	return _travel(session).island.layout


func _arrivals(sessions: Array[CoopSession]) -> Dictionary:
	var arrivals: Dictionary = {}
	for session: CoopSession in sessions:
		arrivals[session.multiplayer.get_unique_id()] = {"health": 100.0, "energy": 100.0}
	return arrivals


func _pair(client_setup: Callable = _setup) -> Array[CoopSession]:
	var host := net.add_host(_setup)
	var client := await net.join(client_setup)
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	return [host, client] as Array[CoopSession]


func _on_reef(sessions: Array[CoopSession]) -> Callable:
	return func() -> bool:
		for session: CoopSession in sessions:
			if _layout(session).id != &"reef_traps_3":
				return false
		return true


# Host: the party goes to island 3 of the reef, with the hash the host generated.
func _to_reef(host: CoopSession, sessions: Array[CoopSession]) -> void:
	var resolved: Dictionary = _travel(host).resolve(REEF, 3)
	host.travel_to.rpc(String(REEF), 3, resolved["island_hash"], _arrivals(sessions), 0.0)


func test_host_and_client_land_on_the_same_reef() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	_to_reef(host, pair)
	assert_true(await wait_until(_on_reef(pair), TIMEOUT_S), "both peers build the reef")
	assert_eq(IslandSource.hash_of(_layout(host)), island.island_hash, "the host's is island 3 for run seed 1")
	assert_eq(IslandSource.hash_of(_layout(client)), island.island_hash, "the client's is the same")
	assert_eq(_layout(client).rows, _layout(host).rows)
	assert_eq(_travel(client).history.current_id(), REEF)
	assert_eq(_travel(client).history.current_index(), 3)
	assert_eq(client.body(1).position, host.body(1).position, "the same landing on both peers")


func test_a_solo_island_is_the_same_with_a_client() -> void:
	var pair := await _pair()
	_to_reef(pair[0], pair)
	assert_true(await wait_until(_on_reef(pair), TIMEOUT_S))
	var solo: GeneratedIsland = IslandGenerator.generate(RUN_SEED, 3, ReefSamples.chain())
	for session: CoopSession in pair:
		assert_eq(IslandLayoutWriter.write(_layout(session)), IslandLayoutWriter.write(solo.layout), "the island one player gets")


func test_a_bad_travel_message_is_ignored() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	var arrivals := _arrivals(pair)
	var good: String = island.island_hash
	client.travel_to(String(REEF), 3, good, arrivals, 0.0)
	host.travel_to("no_such_island", 3, good, arrivals, 0.0)
	host.travel_to(String(REEF), 0, good, arrivals, 0.0)
	host.travel_to(String(REEF), 9, good, arrivals, 0.0)
	host.travel_to(String(REEF), 3, good.to_upper(), arrivals, 0.0)
	host.travel_to(String(REEF), 3, good.substr(1), arrivals, 0.0)
	host.travel_to(String(REEF), 3, "", arrivals, 0.0)
	host.travel_to("coast_cay", 2, good, arrivals, 0.0)
	await wait_frames(5)
	for session: CoopSession in pair:
		assert_eq(_layout(session).id, &"sandbar", "nothing loaded")
	assert_false(CoopSession.is_travel(REEF, 3, ""), "a chain with an empty hash")
	assert_false(CoopSession.is_travel(&"sandbar", 1, good), "a handmade layout with a hash")
	assert_true(CoopSession.is_travel(REEF, 3, good))
	assert_true(CoopSession.is_travel(&"coast_cay", 2, ""))


func test_a_late_joiner_builds_the_same_island() -> void:
	var host := net.add_host(_setup)
	_to_reef(host, [host] as Array[CoopSession])
	assert_true(await wait_until(_on_reef([host] as Array[CoopSession]), TIMEOUT_S))
	var state := host.join_state()
	assert_eq(state["island"], REEF, "the world state names the chain")
	assert_eq(state["island_index"], 3)
	assert_eq(state["island_hash"], StringName(island.island_hash))
	assert_eq(state["run_seed"], RUN_SEED)
	var client := await net.join(_setup)
	assert_not_null(client)
	assert_true(await wait_until(_on_reef([host, client] as Array[CoopSession]), TIMEOUT_S), "the joiner builds the reef")
	assert_eq(IslandSource.hash_of(_layout(client)), island.island_hash)


func test_a_mismatched_client_takes_the_hosts_island() -> void:
	var tampered: GeneratedIsland = IslandGenerator.generate(RUN_SEED, 3, _tampered())
	assert_ne(tampered.island_hash, island.island_hash, "the tampered template builds another island")
	var pair := await _pair(_tampered_setup)
	var host := pair[0]
	var client := pair[1]
	var asks: Array[int] = []
	host.island_text_requested.connect(func(peer_id: int, _id: StringName, _index: int) -> void: asks.append(peer_id))
	_to_reef(host, pair)
	assert_true(await wait_until(_on_reef(pair), TIMEOUT_S), "the client lands on the host's island")
	assert_eq(asks.size(), 1, "one request")
	assert_eq(IslandSource.hash_of(_layout(client)), island.island_hash, "the host's hash in the end")
	assert_eq(IslandLayoutWriter.write(_layout(client)), IslandLayoutWriter.write(_layout(host)), "the host's text")
	assert_eq(_travel(client)._received.size(), 1)
	client.request_island.rpc_id(CoopSession.HOST_ID, String(REEF), 3)
	await wait_frames(10)
	assert_eq(asks.size(), 1, "a second request on the same island is ignored")


func test_a_tampered_text_is_refused() -> void:
	var pair := await _pair(_tampered_setup)
	var client := pair[1]
	var travel := _travel(client)
	travel._pending = {"island_id": REEF, "arrivals": {}, "raft": 0.0, "index": 3, "island_hash": island.island_hash}
	travel._on_island_text_received(IslandLayoutWriter.write(island.layout).replace("~", "-"))
	assert_eq(_layout(client).id, &"sandbar", "a text that does not hash to the host's is ignored")
	assert_push_warning("does not match its hash")


func test_a_client_sees_the_dawn_refill_and_places_nothing() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	_to_reef(host, pair)
	assert_true(await wait_until(_on_reef(pair), TIMEOUT_S))
	var cups := func(session: CoopSession) -> Array[WorldItem]:
		var found: Array[WorldItem] = []
		for node: Node in session.pickups.get_children():
			if node is WorldItem and (node as WorldItem).item_id == &"rain_cup" and not node.is_queued_for_deletion():
				found.append(node as WorldItem)
		return found
	assert_true(await wait_until(func() -> bool: return cups.call(client).size() == 1, TIMEOUT_S), "the client sees the seep")
	var cup: WorldItem = cups.call(host)[0]
	host.body(1).global_position = cup.global_position
	cup.interactable.interacted.emit(host.body(1))
	assert_true(await wait_until(func() -> bool: return cups.call(client).is_empty(), TIMEOUT_S), "taken on the client too")
	WeatherManager.phase_changed.emit(DataEnums.DayPhase.DAWN)
	assert_true(await wait_until(func() -> bool: return cups.call(client).size() == 1, TIMEOUT_S), "the client sees the refilled cups")
	assert_eq(cups.call(host).size(), 1, "one on the host")
	assert_eq(_travel(client).island._placed.size(), 0, "the client never places a pick-up")
