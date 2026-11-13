extends GutTest
## art-pass "Poses follow the replicated state" over ENet on localhost (NetHarness; task 5.5): a host
## and one client both draw the client's player in the dive, swim, crouch and downed poses, in that
## order, as it dives, surfaces, crouches on the beach and is downed. Each peer's look picks the
## pose from the states it already has (the host's simulation, the client's prediction of its own
## player). Keyboard input is off; intents are set on the client's own body.

const TIMEOUT_S: float = 5.0
const TILE: float = 16.0
const T := DataEnums.Terrain
const P := PlayerPose.Pose
## Deep water everywhere but a beach in the east.
const BEACH: Rect2i = Rect2i(20, 0, 10, 12)
const IN_WATER: Vector2i = Vector2i(10, 5)
const ON_BEACH: Vector2i = Vector2i(24, 5)

var net: NetHarness


func before_each() -> void:
	net = NetHarness.new(self)


func after_each() -> void:
	net.teardown()


func _centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func _setup(session: CoopSession) -> void:
	var grid := GridTerrain.new()
	grid.default_terrain = T.DEEP
	grid.fill_rect(BEACH, T.BEACH)
	session.terrain = grid
	session.spawn_points = [_centre(IN_WATER), _centre(IN_WATER + Vector2i(0, 2))] as Array[Vector2]


func _look(body: PlayerBody) -> PlayerLook:
	return body.get_node(^"Look") as PlayerLook


func _both_draw(bodies: Array[PlayerBody], poses: Array[PlayerPose.Pose]) -> bool:
	for body: PlayerBody in bodies:
		if not is_instance_valid(body) or not poses.has(_look(body).pose):
			return false
	return true


func test_both_peers_draw_dive_swim_crouch_and_downed_in_order() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	net.silence_input()
	var me: int = net.peer_id(client)
	var mine: PlayerBody = net.own_body(client)
	var bodies: Array[PlayerBody] = [host.body(me), mine]
	var swimming := func() -> bool: return _both_draw(bodies, [P.SWIM, P.FLOAT] as Array[PlayerPose.Pose])
	assert_true(await wait_until(swimming, TIMEOUT_S), "both draw the client swimming")

	mine.intent = MoveIntent.create(Vector2.ZERO, false, true)
	var diving := func() -> bool: return _both_draw(bodies, [P.DIVE, P.SUBMERGED] as Array[PlayerPose.Pose])
	assert_true(await wait_until(diving, TIMEOUT_S), "then diving, on both peers")
	for body: PlayerBody in bodies:
		assert_false((body.get_node(^"Look/Sprite") as CanvasItem).visible, "the body hidden")
		assert_true((body.get_node(^"Look/Ripple") as CanvasItem).visible, "only the ripple")

	mine.intent = MoveIntent.new()
	var surfaced := func() -> bool: return _both_draw(bodies, [P.SWIM, P.FLOAT] as Array[PlayerPose.Pose])
	assert_true(await wait_until(surfaced, TIMEOUT_S), "surfaced: swimming again on both")

	host.body(me).global_position = _centre(ON_BEACH)
	var landed := func() -> bool: return mine.global_position.distance_to(_centre(ON_BEACH)) < 1.0
	assert_true(await wait_until(landed, TIMEOUT_S), "the client's player stands on the beach")
	mine.intent = MoveIntent.create(Vector2.ZERO, false, true)
	var crouching := func() -> bool: return _both_draw(bodies, [P.CROUCH] as Array[PlayerPose.Pose])
	assert_true(await wait_until(crouching, TIMEOUT_S), "crouching on the beach, on both")

	mine.intent = MoveIntent.new()
	host.body(me).set_downed(true)
	var downed := func() -> bool: return _both_draw(bodies, [P.DOWNED] as Array[PlayerPose.Pose])
	assert_true(await wait_until(downed, TIMEOUT_S), "downed, on both")
	for body: PlayerBody in bodies:
		assert_eq(String((body.get_node(^"Look/Sprite") as AnimatedSprite2D).animation), "downed")
