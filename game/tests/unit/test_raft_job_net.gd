extends GutTest
## island-stop, escape-routes "Raft jobs are shared" (Two players pool a mend), "A launch ends an
## unfinished job" and "The raft's state on every peer" (A joiner sees a fitted raft, here without
## fittings: they come with the fittings PR), and inventory-hud "Raft work list" (A client starts a
## mend) and "Raft jobs in the prompt" (A joiner reads a half-done job), over ENet on localhost
## (NetHarness). Every peer has a beached raft at the same path on a featureless beach; the host's
## is worn, and a client learns its state as it joins. Requests the host would refuse change nothing.

const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const RAFT_SCENE: PackedScene = preload("res://scenes/structures/raft.tscn")
const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const RAFT_NAME: StringName = &"Raft"
const RAFT_CELL: Vector2i = Vector2i(10, 6)
const MEND: StringName = &"raft_mend"
const TIMEOUT_S: float = 5.0
const STEP_S: float = 0.1

var net: NetHarness
# Freed before the sessions they read.
var huds: Array[Node] = []


func before_each() -> void:
	net = NetHarness.new(self)
	huds.clear()


func after_each() -> void:
	for hud: Node in huds:
		if is_instance_valid(hud):
			hud.free()
	huds.clear()
	net.teardown()


# Every peer: the spawn points and a raft lying at the same path, as an island beaches one.
func _setup(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()
	var raft := RAFT_SCENE.instantiate() as Raft
	raft.name = RAFT_NAME
	raft.position = IslandLayout.cell_center(RAFT_CELL)
	session.add_child(raft)
	raft.on_built(GameState.content.get_entry(&"recipes", &"raft") as RecipeData)


func _raft(session: CoopSession) -> Raft:
	return session.get_node_or_null(NodePath(RAFT_NAME)) as Raft


func _hud(session: CoopSession) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	huds.append(hud)
	hud.bind(session, net.peer_id(session), false)
	return hud


# `peer`'s player at `at` on the host and on `session`'s copy, so the copy agrees with the host.
func _place(host: CoopSession, session: CoopSession, peer: int, at: Vector2) -> void:
	host.body(peer).global_position = at
	if session != host:
		session.body(peer).global_position = at


func _integrity_is(session: CoopSession, value: float) -> bool:
	var raft := _raft(session)
	return raft != null and is_equal_approx(raft.integrity, value)


func _has_job(session: CoopSession) -> bool:
	var raft := _raft(session)
	return raft != null and raft.job != null and not raft.job.is_queued_for_deletion()


func _prompt_lines(hud: RunHud) -> PackedStringArray:
	hud.prompt.tick(STEP_S)
	return hud.prompt.lines()


func test_two_players_pool_a_mend() -> void:
	var host := net.add_host(_setup)
	_raft(host).integrity = 50.0
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await wait_until(_integrity_is.bind(client, 50.0), TIMEOUT_S), "the joiner learns the raft is at 50")
	var me: int = net.peer_id(client)
	var at: Vector2 = _raft(host).work_point.global_position
	_place(host, client, CoopSession.HOST_ID, at)
	_place(host, client, me, at)
	var builder := host.body(CoopSession.HOST_ID)
	builder.inventory.add(&"driftwood", 1)
	host.body(me).inventory.add(&"rope", 1)
	assert_true(host.craft_for(CoopSession.HOST_ID, MEND, host.get_path_to(_raft(host))), "the host's player opens the mend")
	assert_true(await wait_until(_has_job.bind(client), TIMEOUT_S), "the client has the job too")
	var host_job := _raft(host).job
	host_job.deposit(builder)
	client.deposit(client.get_path_to(_raft(client).job))
	var both_in := func() -> bool: return host_job.inputs_complete()
	assert_true(await wait_until(both_in, TIMEOUT_S), "the client's rope goes in through the host")
	assert_true(await wait_until(func() -> bool: return _raft(client).job.inputs_complete(), TIMEOUT_S), "and the client's copy shows it")
	# The host started the client's player working on its deposit; its 10 s, stepped at once.
	host.body(me).crafter.advance(10.0)
	assert_true(_integrity_is(host, 70.0), "70 on the host")
	assert_true(await wait_until(_integrity_is.bind(client, 70.0), TIMEOUT_S), "70 on the client")
	assert_true(await wait_until(func() -> bool: return not _has_job(client), TIMEOUT_S), "the job is gone everywhere")
	assert_eq(host.body(me).inventory.count_id(&"rope"), 0)
	assert_eq(builder.inventory.count_id(&"driftwood"), 0)


func test_a_client_starts_a_mend_from_its_list() -> void:
	var host := net.add_host(_setup)
	_raft(host).integrity = 50.0
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await wait_until(_integrity_is.bind(client, 50.0), TIMEOUT_S))
	var me: int = net.peer_id(client)
	_place(host, client, me, _raft(host).work_point.global_position)
	var hud := _hud(client)
	hud.craft_list.open_raft(_raft(client))
	assert_true(hud.craft_list.is_open())
	assert_eq(hud.craft_list.head_texts(), PackedStringArray(["Balsa 50/100"]))
	assert_eq(hud.craft_list.row_texts(), PackedStringArray(["Clavazón", "Defensas", "Remiendo", "Toldo"]))
	assert_true(hud.craft_list.choose(2), "the mend goes to the host")
	assert_true(await wait_until(_has_job.bind(host), TIMEOUT_S), "the host opens the mend on the raft")
	assert_true(await wait_until(_has_job.bind(client), TIMEOUT_S), "and the client shows it")


func test_a_joiner_reads_a_half_done_mend() -> void:
	var host := net.add_host(_setup)
	var raft := _raft(host)
	raft.integrity = 90.0
	host.body(CoopSession.HOST_ID).global_position = raft.work_point.global_position
	assert_true(host.craft_for(CoopSession.HOST_ID, MEND, host.get_path_to(raft)))
	for id: StringName in raft.job.recipe.inputs:
		raft.job.deposited[id] = raft.job.recipe.inputs[id]
	assert_true(raft.job.work(0.5))
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await wait_until(_integrity_is.bind(client, 90.0), TIMEOUT_S), "90 of 100 on the joiner")
	assert_true(await wait_until(_has_job.bind(client), TIMEOUT_S), "with the mend open")
	var half := func() -> bool: return _has_job(client) and is_equal_approx(_raft(client).job.progress(), 0.5)
	assert_true(await wait_until(half, TIMEOUT_S), "at half")
	var hud := _hud(client)
	_place(host, client, net.peer_id(client), _raft(client).job.global_position)
	var shown := func() -> bool: return _prompt_lines(hud) == PackedStringArray(["[E] Trabajar en Remiendo", "50 %"])
	assert_true(await wait_until(shown, TIMEOUT_S), "the prompt shows the bar at 50 % and no Falta: line")
	await wait_physics_frames(10)
	assert_eq(get_errors().size(), 0, "the host logs no error for the joiner's raft and job")


func test_a_launch_gives_a_clients_deposit_back() -> void:
	var host := net.add_host(_setup)
	_raft(host).integrity = 60.0
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var me: int = net.peer_id(client)
	var raft := _raft(host)
	_place(host, client, me, raft.work_point.global_position)
	host.body(me).inventory.add(&"rope", 1)
	_place(host, client, CoopSession.HOST_ID, raft.work_point.global_position)
	assert_true(host.craft_for(CoopSession.HOST_ID, MEND, host.get_path_to(raft)))
	assert_true(await wait_until(_has_job.bind(client), TIMEOUT_S))
	client.deposit(client.get_path_to(_raft(client).job))
	var rope_in := func() -> bool: return host.body(me).inventory.count_id(&"rope") == 0
	assert_true(await wait_until(rope_in, TIMEOUT_S), "the client's rope went in")
	_place(host, client, CoopSession.HOST_ID, raft.global_position)
	raft.end_job()
	assert_eq(host.body(me).inventory.count_id(&"rope"), 1, "the rope is back with the client's player")
	assert_true(await wait_until(func() -> bool: return client.body(me).inventory.count_id(&"rope") == 1, TIMEOUT_S), "and the client sees it")


func test_requests_the_host_refuses_change_nothing() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var me: int = net.peer_id(client)
	var raft := _raft(host)
	_place(host, client, me, raft.work_point.global_position)
	client.craft(MEND, client.get_path_to(_raft(client)))
	await wait_physics_frames(20)
	assert_false(_has_job(host), "a whole raft takes no mend")
	raft.integrity = 50.0
	_place(host, client, me, raft.work_point.global_position + Vector2(0.0, 3.0 * IslandLayout.TILE))
	client.craft(MEND, client.get_path_to(_raft(client)))
	await wait_physics_frames(20)
	assert_false(_has_job(host), "out of the work point's reach")
	_place(host, client, me, raft.work_point.global_position)
	client.craft(MEND, client.get_path_to(_raft(client)))
	assert_true(await wait_until(_has_job.bind(host), TIMEOUT_S), "the same request in reach opens it: the waits were long enough")
