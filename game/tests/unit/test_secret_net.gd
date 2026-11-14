extends GutTest
## secret-cay with a host and clients over ENet on localhost (NetHarness): both see the pieces on
## the same hiding spots; the client's player coming within 3 tiles reveals a piece on both peers;
## the client's 1.5 s hold puts the map in its inventory and removes it on both; the needle shows
## only on the carrier's HUD; the client's 1 s hold opens the chest on both with the same entry and
## one note; a client that joins after the opening sees it open with that entry and no second
## note; two players reaching for the hat leave one holder; a client that leaves holding the
## compass has it laid at its last position; a client that left the island first has nothing laid.
## Each branch builds its island, session and HUD as the dev scenes do.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const HUNT_PATH: String = "res://scenes/dev/secret_hunt_layout.tres"
const CAY_PATH: String = "res://resources/islands/cayo_sin_norte.tres"
const TIMEOUT_S: float = 6.0
const TILE: float = 16.0
const HAT: StringName = &"sombrero_cinta_roja"
const NOTE: StringName = &"nota_llegaste_tarde"

var net: NetHarness
var tuning: SecretTuning = SecretTuning.standard()
var _layout_path: String = HUNT_PATH


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	net.teardown()
	WeatherManager.stop()


# The dev scenes' order: the island beside the session, the session's ground and spawn points,
# furnish, the hunt node. The harness calls this before start().
func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.name = "Island"
	island.layout = load(_layout_path) as IslandLayoutData
	session.get_parent().add_child(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)
	var hunt := SecretHunt.new()
	session.add_child(hunt)
	hunt.setup(session, island)


func _island(session: CoopSession) -> SandbarIsland:
	return session.get_parent().get_node("Island") as SandbarIsland


func _hunt(session: CoopSession) -> SecretHunt:
	return session.get_node(NodePath(SecretHunt.NAME)) as SecretHunt


func _hud(session: CoopSession) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	session.get_parent().add_child(hud)
	hud.bind(session, net.peer_id(session), false)
	hud.needle.set_process(false)
	hud.note_label.set_process(false)
	return hud


func _lying(session: CoopSession, item_id: StringName) -> Array[WorldItem]:
	var found: Array[WorldItem] = []
	for node: Node in session.pickups.get_children():
		var item := node as WorldItem
		if item != null and item.item_id == item_id and not item.is_queued_for_deletion():
			found.append(item)
	return found


# A host and one client on `layout_path`; the host has placed the pick-ups (and, on the hunt, the
# pieces from the dev seed).
func _pair(layout_path: String) -> Array[CoopSession]:
	_layout_path = layout_path
	var host := net.add_host(_setup)
	_island(host).place_pickups(host)
	if layout_path == HUNT_PATH:
		assert_true(_hunt(host).place_from_seed(SecretHuntPlayground.DEV_SEED), "the host places the pieces")
	var client := await net.join(_setup)
	assert_not_null(client, "the client joins")
	if client == null:
		return [] as Array[CoopSession]
	assert_true(await net.settle())
	net.silence_input()
	return [host, client] as Array[CoopSession]


# Puts the client's player at `at` on both peers (its own prediction and the host's copy).
func _place_client(host: CoopSession, client: CoopSession, at: Vector2) -> void:
	var id: int = net.peer_id(client)
	host.body(id).position = at
	net.own_body(client).position = at


# The client holds interact (its intents reach the host, which runs the hold) until `done` holds
# on the host, then lets go; the host's hold time decides when it happens, not the wall clock.
# Returns whether it happened.
func _client_holds_until(host: CoopSession, client: CoopSession, done: Callable) -> bool:
	var mine := net.own_body(client)
	var copy := host.body(net.peer_id(client))
	mine.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	var happened: bool = await wait_until(done, TIMEOUT_S)
	mine.intent = MoveIntent.new()
	var sent: int = mine.net.buffer.last_seq
	await wait_until(func() -> bool: return copy.net.net_ack_seq >= sent, TIMEOUT_S)
	return happened


func test_both_see_the_pieces_on_the_same_hiding_spots() -> void:
	var pair := await _pair(HUNT_PATH)
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var spots: Array[Vector2i] = _island(host).built.hiding_spots(tuning)
	for item_id: StringName in [tuning.map_item_id, tuning.compass_item_id]:
		var on_host: Array[WorldItem] = _lying(host, item_id)
		var on_client: Array[WorldItem] = _lying(client, item_id)
		assert_eq(on_host.size(), 1, "%s on the host" % item_id)
		assert_eq(on_client.size(), 1, "%s on the client" % item_id)
		if on_host.size() == 1 and on_client.size() == 1:
			assert_eq(on_client[0].position, on_host[0].position, "%s at the same cell on both" % item_id)
			assert_has(spots, Vector2i(on_host[0].position / TILE), "%s on a hiding spot" % item_id)
			assert_true(on_client[0].concealed, "%s concealed on the client" % item_id)
	assert_ne(_lying(host, tuning.map_item_id)[0].position, _lying(host, tuning.compass_item_id)[0].position, "different spots")


func test_a_teammate_reveals_it_and_the_client_digs_out_the_map() -> void:
	var pair := await _pair(HUNT_PATH)
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var host_map: WorldItem = _lying(host, tuning.map_item_id)[0]
	var client_map: WorldItem = _lying(client, tuning.map_item_id)[0]
	host.body(CoopSession.HOST_ID).position = host_map.position + Vector2(20.0 * TILE, 0.0)
	_place_client(host, client, host_map.position + Vector2(10.0 * TILE, 0.0))
	host_map.step(0.0)
	client_map.step(0.0)
	assert_false(host_map.revealed, "hidden on the host while everyone is far")
	assert_false(client_map.revealed, "hidden on the client")
	_place_client(host, client, host_map.position + Vector2(0.5 * TILE, 0.0))
	host_map.step(0.0)
	client_map.step(0.0)
	assert_true(host_map.revealed, "the client's approach reveals it on the host")
	assert_true(client_map.revealed, "and on the client")
	var host_hud := _hud(host)
	var client_hud := _hud(client)
	var started_s: float = Time.get_ticks_msec() / 1000.0
	var gone := func() -> bool: return _lying(host, tuning.map_item_id).is_empty()
	assert_true(await _client_holds_until(host, client, gone), "the host ran the client's hold")
	assert_gte(Time.get_ticks_msec() / 1000.0 - started_s, 1.5 - 0.05, "it took the 1.5 s hold")
	var client_id: int = net.peer_id(client)
	var taken := func() -> bool: return net.own_body(client).inventory.count_id(tuning.map_item_id) == 1 and _lying(client, tuning.map_item_id).is_empty()
	assert_true(await wait_until(taken, TIMEOUT_S), "the map is in the client's inventory and gone on the client")
	assert_eq(host.body(client_id).inventory.count_id(tuning.map_item_id), 1, "the host put it there")
	assert_true(_lying(host, tuning.map_item_id).is_empty(), "gone on the host")
	var hint := func() -> bool: return client_hud.note_label.shown_text() != "" and host_hud.note_label.shown_text() != ""
	assert_true(await wait_until(hint, TIMEOUT_S), "both peers show the map's text")
	assert_eq(client_hud.note_label.shown_text(), SecretHunt.map_text(tuning, _hunt(host).compass_kind, "es"))
	assert_eq(host_hud.note_label.shown_text(), client_hud.note_label.shown_text(), "the same hint on both")


func test_the_needle_shows_only_on_the_carriers_hud() -> void:
	var pair := await _pair(HUNT_PATH)
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var host_hud := _hud(host)
	var client_hud := _hud(client)
	host.body(net.peer_id(client)).inventory.add(tuning.compass_item_id, 1)
	var carried := func() -> bool: return net.own_body(client).inventory.count_id(tuning.compass_item_id) == 1
	assert_true(await wait_until(carried, TIMEOUT_S), "the client's inventory replicates")
	client_hud.needle.step(0.05)
	host_hud.needle.step(0.05)
	assert_true(client_hud.needle.visible, "the carrier's HUD shows the needle")
	assert_false(host_hud.needle.visible, "the host's does not")


func test_one_opening_for_everyone_and_a_late_joiner_sees_it() -> void:
	var pair := await _pair(CAY_PATH)
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var host_chest := host.get_node(NodePath(Chest.NAME)) as Chest
	var client_chest := client.get_node(NodePath(Chest.NAME)) as Chest
	var host_hud := _hud(host)
	var client_hud := _hud(client)
	_place_client(host, client, host_chest.position + Vector2(-TILE, 0.0))
	host.body(CoopSession.HOST_ID).position = host_chest.position + Vector2(0.0, 8.0 * TILE)
	assert_true(await _client_holds_until(host, client, func() -> bool: return host_chest.opened), "the host ran the client's hold")
	var opened := func() -> bool: return host_chest.opened and client_chest.opened
	assert_true(await wait_until(opened, TIMEOUT_S), "open on both peers")
	assert_eq(client_chest.entry_id, host_chest.entry_id, "the same entry")
	var notes := func() -> bool: return _lying(client, NOTE).size() == 1
	assert_true(await wait_until(notes, TIMEOUT_S), "one note on the client")
	assert_eq(_lying(host, NOTE).size(), 1, "one note on the host")
	var entry := host_chest.entry(host_chest.entry_id)
	assert_eq(client_hud.note_label.shown_text(), entry.body_es, "the client reads the entry")
	assert_eq(host_hud.note_label.shown_text(), entry.body_es, "the host reads it too")
	var late := await net.join(_setup)
	assert_not_null(late, "a client joins after the opening")
	if late == null:
		return
	var late_hud := _hud(late)
	var late_chest := late.get_node(NodePath(Chest.NAME)) as Chest
	assert_true(await wait_until(func() -> bool: return late_chest.opened, TIMEOUT_S), "the late joiner's chest is open")
	assert_eq(late_chest.entry_id, host_chest.entry_id, "with the same entry")
	assert_eq(late_hud.note_label.shown_text(), "", "and no label pops up")
	await wait_physics_frames(10)
	assert_eq(_lying(late, NOTE).size(), 1, "no second note")
	assert_eq(_lying(host, NOTE).size(), 1)


func test_the_cay_is_not_scaled_for_two_players() -> void:
	var pair := await _pair(CAY_PATH)
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var listed: Dictionary[StringName, int] = {}
	for pickup: Dictionary in _island(host).built.pickups:
		listed[pickup["item_id"]] = listed.get(pickup["item_id"], 0) + int(pickup["count"])
	for session: CoopSession in [host, client]:
		var lying: Dictionary[StringName, int] = {}
		var settled := func() -> bool: return session.pickups.get_child_count() == _island(host).built.pickups.size()
		assert_true(await wait_until(settled, TIMEOUT_S), "every listed pick-up arrived")
		for node: Node in session.pickups.get_children():
			var item := node as WorldItem
			lying[item.item_id] = lying.get(item.item_id, 0) + item.count
		assert_eq(lying, listed, "exactly the layout's pick-ups, as for one player")
	var coconuts: int = 0
	for palm: Node in _island(host).get_node(^"Palms").get_children():
		coconuts += (palm as Palm).coconuts
	assert_eq(coconuts, 7, "the same 7 coconuts")
	assert_null(host.get_node_or_null(NodePath(SandbarIsland.CREATURES_NAME)), "no creatures or patrols")


func test_two_players_reach_for_the_hat() -> void:
	var pair := await _pair(CAY_PATH)
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var hats: Array[WorldItem] = _lying(host, HAT)
	assert_eq(hats.size(), 1)
	if hats.size() != 1:
		return
	var host_body := host.body(CoopSession.HOST_ID)
	var client_copy := host.body(net.peer_id(client))
	host_body.position = hats[0].position + Vector2(-0.5 * TILE, 0.0)
	client_copy.position = hats[0].position + Vector2(0.5 * TILE, 0.0)
	hats[0].interactable.use(host_body)
	hats[0].interactable.use(client_copy)
	var holders: int = host_body.inventory.count_id(HAT) + client_copy.inventory.count_id(HAT)
	assert_eq(holders, 1, "exactly one holds it")
	assert_true(await wait_until(func() -> bool: return _lying(client, HAT).is_empty(), TIMEOUT_S), "gone on the client")
	assert_eq(_lying(host, HAT).size(), 0, "no second hat exists")


func test_a_client_that_leaves_holding_the_compass() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	var other := await net.join(_setup)
	assert_not_null(client)
	assert_not_null(other)
	if client == null or other == null:
		return
	assert_true(await net.settle())
	var id: int = net.peer_id(client)
	var copy := host.body(id)
	copy.inventory.add(tuning.compass_item_id, 1)
	copy.inventory.add(&"driftwood", 2)
	var spot := Vector2(30.5, 20.5) * TILE
	copy.position = spot
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(id), TIMEOUT_S), "dropped on the host")
	copy.position = spot
	host._physics_process(host.disconnect_time_left(id) + 0.1)
	assert_null(host.body(id), "removed")
	var laid: Array[WorldItem] = _lying(host, tuning.compass_item_id)
	assert_eq(laid.size(), 1, "the compass lies on the island")
	if laid.size() == 1:
		assert_eq(laid[0].position, spot, "at the last position")
	assert_eq(_lying(host, &"driftwood").size(), 0, "only secret items are laid down")
	var seen := func() -> bool: return _lying(other, tuning.compass_item_id).size() == 1
	assert_true(await wait_until(seen, TIMEOUT_S), "the remaining client sees it")
	if _lying(other, tuning.compass_item_id).size() == 1:
		assert_eq(_lying(other, tuning.compass_item_id)[0].position, spot)


func test_a_rider_who_already_left_the_island() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	var id: int = net.peer_id(client)
	var copy := host.body(id)
	copy.inventory.add(tuning.compass_item_id, 1)
	IslandArrival.hold(copy)
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(id), TIMEOUT_S), "dropped on the host")
	host._physics_process(host.disconnect_time_left(id) + 0.1)
	assert_null(host.body(id), "removed")
	assert_eq(_lying(host, tuning.compass_item_id).size(), 0, "no compass laid on the island")


func test_a_rider_still_at_sea_lays_nothing_either() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	var id: int = net.peer_id(client)
	host.body(id).inventory.add(tuning.compass_item_id, 1)
	# The route started for this rider (escape-routes), so it has left though its crossing runs on.
	(host.get_node(^"Routes") as IslandRoutes).departed[id] = &"raft"
	assert_true(host.has_left(id))
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(id), TIMEOUT_S), "dropped on the host")
	host._physics_process(host.disconnect_time_left(id) + 0.1)
	assert_eq(_lying(host, tuning.compass_item_id).size(), 0, "nothing laid on the island")
