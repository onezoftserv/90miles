extends GutTest
## intent-delivery "Intent delivery", scenario "A lost message costs no movement", over ENet on
## localhost with a host and a client (NetHarness). The test drops 2 of every 3 of the client's
## intent messages before they leave, as a lossy link or ENet's throttle would. Because each
## message repeats the intents the host has not acknowledged, the host still steps every one
## and no host state corrects the client's own player.

const TILE: float = 16.0
const EAST := Vector2.RIGHT
const TIMEOUT_S: float = 5.0
const WALK_FRAMES: int = 60
## How far a host state may move the client's own player: float crumbs only. One lost frame of
## walking is about 1.1 px.
const MAX_CORRECTION_PX: float = 0.01

var net: NetHarness


## Keeps the client's predicted position at the end of each physics frame, after PlayerNet has
## stepped it, so a host state can be compared with what the client drew.
class FrameEnd:
	extends Node
	var body: PlayerBody
	var position: Vector2 = Vector2.ZERO

	func _init() -> void:
		process_physics_priority = 100

	func _physics_process(_delta: float) -> void:
		position = body.position


func before_each() -> void:
	net = NetHarness.new(self)


func after_each() -> void:
	net.teardown()


func test_a_client_that_loses_two_of_every_three_messages_loses_no_movement() -> void:
	net.add_host()
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var mine := net.own_body(client)
	var copy := net.sessions[0].body(net.peer_id(client))
	var start := mine.position
	var handed: Array[int] = [0]
	mine.net._send = func(intents: Array[PendingIntent]) -> void:
		handed[0] += 1
		if handed[0] % 3 == 0:
			client.send_intents(intents)
	var frame_end := FrameEnd.new()
	frame_end.body = mine
	frame_end.position = mine.position
	add_child_autofree(frame_end)
	var worst: Array[float] = [0.0]
	var states: Array[int] = [0]
	(mine.get_node(^"StateSync") as MultiplayerSynchronizer).synchronized.connect(func() -> void:
		states[0] += 1
		worst[0] = maxf(worst[0], frame_end.position.distance_to(mine.position))
		frame_end.position = mine.position)
	mine.intent = MoveIntent.create(EAST)
	await wait_physics_frames(WALK_FRAMES)
	mine.intent = MoveIntent.new()
	var predicted := mine.position
	assert_gt(predicted.x - start.x, 3.0 * TILE, "the client's player walked east at once")
	var caught_up: bool = await wait_until(func() -> bool: return copy.position == predicted, TIMEOUT_S)
	assert_true(caught_up, "the host stepped every intent: host x %.2f, client x %.2f" % [copy.position.x, predicted.x])
	await wait_seconds(0.2)
	assert_gt(states[0], 3, "host states kept arriving")
	assert_lt(worst[0], MAX_CORRECTION_PX, "no host state moved the client's own player (worst %.3f px)" % worst[0])
	assert_eq(mine.position, predicted, "and it stands where it walked to")
