extends GutTest
## inventory-hud "Crouch cue" (A teammate crouches) and "Hidden mark" (The client sees the host
## hide) over ENet on localhost (NetHarness), each peer with its own sandbar: every peer draws a
## crouching player lowered and a hidden player marked from the movement and stealth states the
## host already replicates. Keyboard input is off; intents are set on the bodies.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const TIMEOUT_S: float = 5.0
const CROUCH_HEIGHT_PX: float = 10.0

var net: NetHarness
var islands: Array[SandbarIsland] = []
# Freed before the sessions they read.
var huds: Array[Node] = []


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	for hud: Node in huds:
		if is_instance_valid(hud):
			hud.free()
	huds.clear()
	net.teardown()
	for island: SandbarIsland in islands:
		island.free()
	islands.clear()
	WeatherManager.stop()


# The shell's order, as in test_sandbar_net.gd: the island, the session's terrain and spawn points,
# furnish.
func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	add_child(island)
	islands.append(island)
	session.terrain = island.terrain
	session.spawn_points = island.spawn_points(false)
	island.with_creatures = false
	island.furnish(session)


func _hud(session: CoopSession) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	huds.append(hud)
	hud.bind(session, net.peer_id(session), false)
	return hud


func _look(body: PlayerBody) -> BodyLook:
	return body.get_node(^"BodyLook") as BodyLook


func _brush_spot() -> Vector2:
	var island := islands[0]
	for y: int in island.built.size.y:
		for x: int in island.built.size.x:
			var cell := Vector2i(x, y)
			if TerrainQuery.is_brush(island.terrain.terrain_at(cell)):
				return IslandLayout.cell_center(cell)
	return Vector2(-1.0, -1.0)


func test_the_host_draws_a_crouching_client_lowered() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	net.silence_input()
	var me: int = net.peer_id(client)
	var on_host := host.body(me)
	var full: float = _look(on_host).drawn_rect().size.y
	assert_eq(full, 16.0, "standing, full height on the host")
	var feet: float = _look(on_host).drawn_rect().end.y
	net.own_body(client).intent = MoveIntent.create(Vector2.ZERO, false, true)
	var lowered := func() -> bool:
		return on_host.movement_state == MovementStep.Move.CROUCH and _look(on_host).drawn_rect().size.y == CROUCH_HEIGHT_PX
	assert_true(await wait_until(lowered, TIMEOUT_S), "the host draws the client's player 10 px tall")
	assert_eq(_look(on_host).drawn_rect().end.y, feet, "on its feet")
	assert_eq(_look(net.own_body(client)).drawn_rect().size.y, CROUCH_HEIGHT_PX, "and the client draws its own player lowered")
	net.own_body(client).intent = MoveIntent.new()
	var standing := func() -> bool: return _look(on_host).drawn_rect().size.y == full
	assert_true(await wait_until(standing, TIMEOUT_S), "full height again once the client stands")


func test_the_client_marks_the_host_hidden_in_brush() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	net.silence_input()
	var hud := _hud(client)
	var spot := _brush_spot()
	assert_ne(spot, Vector2(-1.0, -1.0), "the sandbar has brush")
	var host_body := host.body(CoopSession.HOST_ID)
	host_body.global_position = spot
	var seen := client.body(CoopSession.HOST_ID)
	var placed := func() -> bool: return seen.global_position.distance_to(spot) < 1.0
	assert_true(await wait_until(placed, TIMEOUT_S), "the client draws the host's player in the brush")
	assert_false(hud.marks.has_mark(seen), "no mark while the host stands")
	host_body.intent = MoveIntent.create(Vector2.ZERO, false, true)
	var marked := func() -> bool: return hud.marks.has_mark(seen)
	assert_true(await wait_until(marked, TIMEOUT_S), "the client shows the mark over the hidden host")
	assert_eq(seen.stealth_state, MovementStep.Stealth.HIDDEN, "from the state the host replicates")
	assert_eq(hud.marks.mark_rect(seen).size, Vector2(7.0, 5.0))
	assert_false(hud.marks.has_mark(net.own_body(client)), "the client itself is not hidden")
	host_body.intent = MoveIntent.new()
	var unmarked := func() -> bool: return not hud.marks.has_mark(seen)
	assert_true(await wait_until(unmarked, TIMEOUT_S), "the mark goes when the host stands")
