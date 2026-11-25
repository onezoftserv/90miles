extends GutTest
## island-pressure task 2.3, a host and a client over ENet on localhost (NetHarness): the level's
## raft site is built in stages that both peers read the same from the synced deposits and progress
## (crafting-inventory "Build stages", "Held work on staged builds"; escape-routes "Raft build site").
## Two holders work twice as fast; a client's hold works through its intents; a joiner reads the stage
## the host is in. Real time is short here: a scenario's long hold starts from work already done on the
## host, so 3 s of two holders stand for the last 6 s of a 15 s hold.

const SITE_SCENE: PackedScene = preload("res://scenes/structures/build_site.tscn")
const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const RAFT_SITE_NAME: StringName = &"RaftSite"
const RAFT_NAME: StringName = &"Raft"
const RAFT_CELL: Vector2i = Vector2i(10, 6)
const RAFT_TIME_S: float = 120.0
const TIMEOUT_S: float = 5.0

var net: NetHarness


func before_each() -> void:
	net = NetHarness.new(self)


func after_each() -> void:
	net.teardown()


# Every peer: the spawn points and the level's raft site at the same path, as SandbarIsland has them.
func _setup(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()
	var site := SITE_SCENE.instantiate() as BuildSite
	site.name = RAFT_SITE_NAME
	site.recipe = GameState.content.get_entry(&"recipes", &"raft") as RecipeData
	site.synced = true
	site.structure_name = RAFT_NAME
	site.position = IslandLayout.cell_center(RAFT_CELL)
	session.add_child(site)


func _site(session: CoopSession) -> BuildSite:
	return session.get_node_or_null(NodePath(RAFT_SITE_NAME)) as BuildSite


func _pair() -> Array[CoopSession]:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	if client == null:
		return []
	assert_true(await net.settle(), "both peers show both players")
	net.silence_input()
	return [host, client]


# `peer`'s player at the site on the host and on the client's copy.
func _at_site(host: CoopSession, client: CoopSession, peer: int) -> void:
	var at: Vector2 = _site(host).global_position
	host.body(peer).global_position = at
	client.body(peer).global_position = at


# The intent that drives `peer`'s player: the host's own body, or the client's own predicted body
# (its PlayerNet sends it to the host).
func _hold(host: CoopSession, client: CoopSession, peer: int, held: bool) -> void:
	var session: CoopSession = host if peer == CoopSession.HOST_ID else client
	session.body(peer).intent = MoveIntent.create(Vector2.ZERO, false, false, held)


func _work_s(session: CoopSession) -> float:
	return _site(session).progress() * RAFT_TIME_S


func _same_stage(host: CoopSession, client: CoopSession) -> bool:
	var a := _site(host)
	var b := _site(client)
	return a != null and b != null and a.stage_index() == b.stage_index() and absf(a.stage_progress() - b.stage_progress()) < 0.0001 and a.deposited == b.deposited


# escape-routes "Two players feed the raft".
func test_two_players_feed_the_raft() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host: CoopSession = pair[0]
	var client: CoopSession = pair[1]
	var me: int = net.peer_id(client)
	_at_site(host, client, CoopSession.HOST_ID)
	_at_site(host, client, me)
	host.body(CoopSession.HOST_ID).inventory.add(&"driftwood", 6)
	host.body(CoopSession.HOST_ID).inventory.add(&"inner_tube", 1)
	host.body(me).inventory.add(&"inner_tube", 1)
	host.body(me).inventory.add(&"rope", 3)
	_site(host).deposit(host.body(CoopSession.HOST_ID))
	_hold(host, client, me, true)
	var full := func() -> bool: return _site(client).deposited == {&"driftwood": 6, &"inner_tube": 2, &"rope": 3}
	assert_true(await wait_until(full, TIMEOUT_S), "the client's press deposited its share and the client sees 6, 2 and 3")
	assert_eq(_site(host).deposited, {&"driftwood": 6, &"inner_tube": 2, &"rope": 3} as Dictionary[StringName, int])
	_hold(host, client, me, false)
	await wait_physics_frames(10)
	assert_true(await wait_until(_same_stage.bind(host, client), TIMEOUT_S), "both peers show the same stage and progress")


# crafting-inventory "Two hold together": the last 6 s of work of a 15 s hold by two.
func test_two_hold_together() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host: CoopSession = pair[0]
	var client: CoopSession = pair[1]
	var me: int = net.peer_id(client)
	var site := _site(host)
	for id: StringName in site.recipe.inputs:
		site.deposited[id] = site.recipe.inputs[id]
	site.work(24.0 / RAFT_TIME_S)
	_at_site(host, client, CoopSession.HOST_ID)
	_at_site(host, client, me)
	_hold(host, client, CoopSession.HOST_ID, true)
	_hold(host, client, me, true)
	var both := func() -> bool: return host.body(CoopSession.HOST_ID).crafter.is_crafting() and host.body(me).crafter.is_crafting()
	assert_true(await wait_until(both, TIMEOUT_S), "both players work the site")
	# Counted in the host's physics frames, not the wall clock: each frame each holder adds a frame's work.
	var started: float = _work_s(host)
	var from_frame: int = Engine.get_physics_frames()
	await wait_physics_frames(60)
	var gained: float = _work_s(host) - started
	var frame_s: float = 1.0 / Engine.physics_ticks_per_second
	var expected: float = 2.0 * float(Engine.get_physics_frames() - from_frame) * frame_s
	assert_almost_eq(gained, expected, 4.0 * frame_s, "two holders do 2 s of work per second")
	var stage_done := func() -> bool: return _site(host).stage_index() == 1
	assert_true(await wait_until(stage_done, TIMEOUT_S), "the first stage is done")
	_hold(host, client, CoopSession.HOST_ID, false)
	_hold(host, client, me, false)
	assert_true(await wait_until(_same_stage.bind(host, client), TIMEOUT_S), "both peers read the second stage")
	assert_eq(_site(client).stage_index(), 1)


# escape-routes "One builds while the other gathers": the host's player works the first stage alone
# and waits at its end; the client's player comes, deposits the rest and holds with them.
func test_one_builds_while_the_other_gathers() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host: CoopSession = pair[0]
	var client: CoopSession = pair[1]
	var me: int = net.peer_id(client)
	var builder := host.body(CoopSession.HOST_ID)
	builder.inventory.add(&"inner_tube", 2)
	builder.inventory.add(&"rope", 1)
	host.body(me).inventory.add(&"driftwood", 6)
	host.body(me).inventory.add(&"rope", 2)
	_at_site(host, client, CoopSession.HOST_ID)
	var site := _site(host)
	site.deposit(builder)
	site.work(28.0 / RAFT_TIME_S)
	_hold(host, client, CoopSession.HOST_ID, true)
	var at_stage_end := func() -> bool: return _work_s(host) >= 30.0 - 0.001
	assert_true(await wait_until(at_stage_end, TIMEOUT_S), "the builder finishes the first stage")
	await wait_seconds(0.5)
	assert_almost_eq(_work_s(host), 30.0, 0.001, "and waits there for the floor's inputs")
	assert_eq(site.stage_missing_items(), {&"driftwood": 4, &"rope": 1} as Dictionary[StringName, int], "the floor needs its driftwood and rope")
	var waits := func() -> bool: return _site(client).stage_index() == 1 and _site(client).stage_missing_items() == {&"driftwood": 4, &"rope": 1}
	assert_true(await wait_until(waits, TIMEOUT_S), "the client sees the second stage waiting for its inputs")
	_at_site(host, client, me)
	_hold(host, client, me, true)
	var under_way := func() -> bool: return _work_s(host) > 31.0
	assert_true(await wait_until(under_way, TIMEOUT_S), "with the client's deposit the second stage is under way")
	_hold(host, client, CoopSession.HOST_ID, false)
	_hold(host, client, me, false)
	assert_true(await wait_until(_same_stage.bind(host, client), TIMEOUT_S), "both peers show it")
	assert_eq(_site(client).stage_index(), 1)
	assert_gt(_site(client).stage_progress(), 0.0)
	assert_lte(host.body(CoopSession.HOST_ID).meters.energy, 100.0 - 2.0 + 0.5, "the builder paid for their work")
	assert_lt(host.body(me).meters.energy, 100.0, "so did the client's player")


# A joiner mid-stage reads the stage the host is in.
func test_a_joiner_mid_stage_reads_the_hosts_stage() -> void:
	var host := net.add_host(_setup)
	var site := _site(host)
	for id: StringName in site.recipe.inputs:
		site.deposited[id] = site.recipe.inputs[id]
	site.work(45.0 / RAFT_TIME_S)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await wait_until(_same_stage.bind(host, client), TIMEOUT_S), "the joiner reads the same stage")
	assert_eq(_site(client).stage_index(), 1)
	assert_almost_eq(_site(client).stage_progress(), 0.5, 0.001)
	assert_eq(get_errors().size(), 0)
