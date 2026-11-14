extends GutTest
## creature-perch-ride "Perched creature on every peer" and "Sighting effects" over ENet on
## localhost (NetHarness): the host runs the galleguito, every peer draws it on its rider's head,
## a client's shoo is a request the host checks for reach, a late joiner sees it perched, and a
## rider who drops and rejoins keeps it without being paid twice.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const FIXTURES: String = "res://tests/fixtures/content"
const GULL: StringName = &"galleguito_prueba"
const TIMEOUT_S: float = 6.0
const STEP_S: float = 0.1

var net: NetHarness
var islands: Array[SandbarIsland] = []
var catalog: ContentCatalog = ContentCatalog.new(FIXTURES)
var papo: PlayerIdentity = PlayerIdentity.create()
var rng := RandomNumberGenerator.new()


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	net.teardown()
	for island: SandbarIsland in islands:
		island.free()
	islands.clear()


func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.with_creatures = false
	add_child(island)
	islands.append(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	session.creature_catalog = catalog
	island.furnish(session)


func _as_papo(session: CoopSession) -> void:
	_setup(session)
	session.local_identity = papo
	session.local_name = "Papo"


# A final crossing for every player in `sessions` (the host first), launched on each, with the
# galleguito rolled on the host. Returns the host's crossing.
func _final_crossing(sessions: Array[CoopSession]) -> Crossing:
	var host := sessions[0]
	var route := GameState.content.get_entry(&"routes", &"raft") as RouteData
	var riders: Array[int] = host.peer_ids()
	for index: int in range(sessions.size() - 1, 0, -1):
		Crossing.launch(sessions[index], route, riders, 100.0, DataEnums.DistanceBand.COAST, rng)
	var crossing := Crossing.launch(host, route, riders, 100.0, DataEnums.DistanceBand.COAST, rng)
	crossing.plan = CrossingPlan.create(600.0)
	CrossingCreatures.attach(crossing, DataEnums.ChainFamily.FINAL, DataEnums.DistanceBand.COAST)
	return crossing


func _gull_on(session: CoopSession) -> Creature:
	for child: Node in session.entities.get_children():
		var creature := child as Creature
		if creature != null and creature.data.id == GULL and not creature.is_queued_for_deletion():
			return creature
	return null


# Steps the host's crossing and gull by hand until it is perched.
func _perch(crossing: Crossing, gull: Creature) -> void:
	var waited: float = 0.0
	while gull.state_name() != &"PERCH" and waited < 30.0:
		crossing.advance(STEP_S)
		gull.advance(STEP_S)
		waited += STEP_S


func _look_on(gull: Creature) -> CreatureLook:
	return gull.get_node(^"Look") as CreatureLook


# Whether `session` draws its gull on the head of the player of `peer`.
func _drawn_on(session: CoopSession, peer: int) -> bool:
	var gull := _gull_on(session)
	var rider := session.body(peer)
	if gull == null or rider == null or gull.perch_peer != peer:
		return false
	return _look_on(gull).global_position == rider.global_position + Vector2(0.0, CreatureLook.PERCH_SORT_PX)


func test_a_client_rider_sees_the_gull_on_its_own_head_while_walking() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var client_id: int = net.peer_id(client)
	host.body(client_id).inventory.add(&"coco", 3)
	var crossing := _final_crossing([host, client] as Array[CoopSession])
	var gull := _gull_on(host)
	assert_not_null(gull)
	if gull == null:
		return
	_perch(crossing, gull)
	assert_eq(gull.perch_peer, client_id, "the client holds the most food")
	var drawn := func() -> bool: return _drawn_on(client, client_id)
	assert_true(await wait_until(drawn, TIMEOUT_S), "the client draws it on its own player's head")
	var mine := net.own_body(client)
	mine.intent = MoveIntent.create(Vector2.RIGHT)
	await wait_physics_frames(6)
	mine.intent = MoveIntent.new()
	await wait_process_frames(1)
	assert_true(_drawn_on(client, client_id), "still on the head of the walking player, not trailing it")
	await wait_process_frames(1)
	assert_true(_drawn_on(host, client_id), "the host draws it on the client's player too")


func test_a_clients_shoo_from_beside_hops_it_and_one_from_6_tiles_is_refused() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var client_id: int = net.peer_id(client)
	host.body(CoopSession.HOST_ID).inventory.add(&"coco", 3)
	var crossing := _final_crossing([host, client] as Array[CoopSession])
	var gull := _gull_on(host)
	if gull == null:
		fail_test("no galleguito")
		return
	_perch(crossing, gull)
	assert_eq(gull.perch_peer, CoopSession.HOST_ID)
	var mirrored := func() -> bool: return _gull_on(client) != null
	assert_true(await wait_until(mirrored, TIMEOUT_S))
	client.shoo(String(gull.name))
	var hopped := func() -> bool: return gull.state_name() == &"HOP" or gull.perch_peer == client_id
	assert_true(await wait_until(hopped, TIMEOUT_S), "the host takes the client's shoo from beside its player")
	_perch(crossing, gull)
	assert_eq(gull.perch_peer, client_id, "on the client's player's head")
	var on_client := func() -> bool: return _drawn_on(client, client_id)
	assert_true(await wait_until(on_client, TIMEOUT_S), "and drawn there on the client")
	host.body(CoopSession.HOST_ID).global_position = gull.global_position + Vector2(6.0 * CreatureNav.TILE, 0.0)
	host.shoo(String(gull.name))
	await wait_physics_frames(4)
	assert_eq(gull.state_name(), &"PERCH", "a shoo from 6 tiles is refused")
	assert_eq(gull.perch_peer, client_id)


func test_a_client_that_joins_mid_crossing_sees_it_on_the_host_players_head() -> void:
	var host := net.add_host(_setup)
	net.silence_input()
	var crossing := _final_crossing([host] as Array[CoopSession])
	var gull := _gull_on(host)
	if gull == null:
		fail_test("no galleguito")
		return
	_perch(crossing, gull)
	assert_eq(gull.perch_peer, CoopSession.HOST_ID)
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	var drawn := func() -> bool: return _drawn_on(late, CoopSession.HOST_ID)
	assert_true(await wait_until(drawn, TIMEOUT_S), "the joiner draws it on the host player's head")


func test_a_rider_who_rejoins_keeps_the_gull_and_is_paid_once() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_as_papo)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var old_id: int = net.peer_id(client)
	var papo_body := host.body(old_id)
	papo_body.inventory.add(&"coco", 3)
	papo_body.meters.morale = 50.0
	var crossing := _final_crossing([host, client] as Array[CoopSession])
	var gull := _gull_on(host)
	if gull == null:
		fail_test("no galleguito")
		return
	_perch(crossing, gull)
	assert_eq(gull.perch_peer, old_id)
	assert_almost_eq(papo_body.meters.morale, 60.0, 1.0, "+10 when it landed (real frames tick morale a hair)")
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(old_id), TIMEOUT_S), "Papo drops")
	var back := await net.join(_as_papo)
	assert_not_null(back, "Papo rejoins")
	if back == null:
		return
	var new_id: int = net.peer_id(back)
	assert_same(host.body(new_id), papo_body, "the same body")
	gull.advance(STEP_S)
	assert_eq(gull.state_name(), &"PERCH", "still on Papo's head")
	assert_eq(gull.perch_peer, new_id, "under his new peer")
	gull.shoo(papo_body)
	_perch(crossing, gull)
	assert_almost_eq(papo_body.meters.morale, 60.0, 1.0, "+10 once, not again after the rejoin (twice would be 70)")
	var drawn := func() -> bool: return _drawn_on(back, gull.perch_peer)
	assert_true(await wait_until(drawn, TIMEOUT_S), "the rejoined client draws it on the right head")
