extends GutTest
## inventory-hud "Sign note" ("Only the reader sees it") over ENet on localhost (NetHarness), each
## peer with its own coast cay and its own HUD: the peer that presses interact at a sign gets the
## note; the other peer's HUD gets none, and no sign message or speech bubble goes out.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const COAST_LAYOUT: IslandLayoutData = preload("res://resources/islands/coast_cay.tres")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const TIMEOUT_S: float = 5.0
const STEP_S: float = 0.1

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


# The shell's order, with the coast cay as the layout (it holds the signs).
func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = COAST_LAYOUT
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


func _sign(session: CoopSession, prefix: String) -> IslandSign:
	for node: Node in session.get_children():
		var found := node as IslandSign
		if found != null and found.line_es.begins_with(prefix):
			return found
	return null


# `body` stands beside `sign_node` on this peer and presses interact: the prompt finds the sign,
# then sees the fresh press.
func _read(hud: RunHud, body: PlayerBody, sign_node: IslandSign) -> void:
	body.global_position = sign_node.global_position + Vector2(0.0, 8.0)
	body.intent = MoveIntent.new()
	hud.prompt.tick(STEP_S)
	assert_same(hud.prompt.target, sign_node, "the sign is the candidate")
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	hud.prompt.tick(STEP_S)


func _no_bubbles(session: CoopSession, where: String) -> void:
	for node: Node in session.get_children():
		if node is IslandSign:
			assert_null(node.get_node_or_null(NodePath(CoopSession.BUBBLE_NAME)), "no bubble over %s %s" % [node.name, where])


func test_the_host_reads_a_slogan_and_the_client_sees_no_note() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var host_hud := _hud(host)
	var client_hud := _hud(client)
	var slogan := _sign(host, "«AQUÍ NO SE RINDE")
	assert_not_null(slogan, "the wall is on the host's cay")
	assert_false(host.has_method("show_sign"), "no sign message exists")
	_read(host_hud, host.body(CoopSession.HOST_ID), slogan)
	assert_true(host_hud.sign_note.is_open(), "the host's note opens")
	assert_eq(host_hud.sign_note.text_shown(), slogan.line_es)
	for i: int in 10:
		client_hud.sign_note._process(STEP_S)
		await wait_physics_frames(1)
	assert_false(client_hud.sign_note.is_open(), "the client's HUD has none")
	_no_bubbles(host, "on the host")
	_no_bubbles(client, "on the client")


func test_the_client_reads_the_radio_and_the_host_sees_no_note() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var host_hud := _hud(host)
	var client_hud := _hud(client)
	var radio := _sign(client, "Un radio ruso")
	assert_not_null(radio, "the radio is on the client's own cay")
	_read(client_hud, net.own_body(client), radio)
	assert_true(client_hud.sign_note.is_open(), "the client's note opens")
	assert_eq(client_hud.sign_note.text_shown(), radio.line_es)
	for i: int in 10:
		host_hud.sign_note._process(STEP_S)
		await wait_physics_frames(1)
	assert_false(host_hud.sign_note.is_open(), "the host's HUD has none")
	_no_bubbles(host, "on the host")
	_no_bubbles(client, "on the client")
