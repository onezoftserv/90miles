extends GutTest
## crafting-inventory "Placing a build site" and "Placed sites on every peer", and inventory-hud
## "Choosing a recipe" (A client places a site) and "Build site prompt" (A fire site on a client, A
## joiner mid-build), over ENet on localhost (NetHarness): the host places a client's chosen site by
## that client's own player, at the same place on both peers; deposits of items and tags and the
## progress reach the client; a joiner gets the live state of a site and the fire built before it
## came; and requests the host would refuse change nothing. Each peer has a bench at the same path
## on a featureless beach. Only the client gets a HUD, and nothing presses a key.

const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const BENCH_NAME: StringName = &"HutWorkbench"
const BENCH_CELL: Vector2i = Vector2i(6, 6)
## Inside the cell south of the bench, within its reach.
const AT_BENCH: Vector2 = Vector2(0.0, 10.0)
const TIMEOUT_S: float = 5.0
const STEP_S: float = 0.1
const M := DataEnums.Meter

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


# Every peer: the spawn points and the bench at the same path.
func _setup(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()
	var bench := Workbench.new()
	bench.name = BENCH_NAME
	bench.position = IslandLayout.cell_center(BENCH_CELL)
	session.add_child(bench)


func _hud(session: CoopSession) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	huds.append(hud)
	hud.bind(session, net.peer_id(session), false)
	return hud


func _bench(session: CoopSession) -> Workbench:
	return session.get_node(NodePath(BENCH_NAME)) as Workbench


func _bench_path(session: CoopSession) -> NodePath:
	return session.get_path_to(_bench(session))


# `peer`'s player at `at` on the host and on `session`'s copy, so the copy agrees with the host.
func _place(host: CoopSession, session: CoopSession, peer: int, at: Vector2) -> void:
	host.body(peer).global_position = at
	if session != host:
		session.body(peer).global_position = at


func _sites(session: CoopSession, recipe_id: StringName) -> Array[BuildSite]:
	var found: Array[BuildSite] = []
	for node: Node in session.entities.get_children():
		var site := node as BuildSite
		if site != null and not site.is_queued_for_deletion() and site.recipe.id == recipe_id:
			found.append(site)
	return found


func _structures(session: CoopSession, kind: Script) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in session.entities.get_children():
		if node.get_script() == kind and not node.is_queued_for_deletion():
			found.append(node)
	return found


func _wait_for_site(session: CoopSession, recipe_id: StringName) -> BuildSite:
	var appeared := func() -> bool: return not _sites(session, recipe_id).is_empty()
	if not await wait_until(appeared, TIMEOUT_S):
		return null
	return _sites(session, recipe_id)[0]


# The host's player places a fire site at the bench and, with `fill`, deposits all it needs.
func _host_fire(host: CoopSession, fill: bool) -> BuildSite:
	var builder := host.body(CoopSession.HOST_ID)
	builder.global_position = _bench(host).global_position + AT_BENCH
	assert_true(host.craft_for(CoopSession.HOST_ID, &"fire", _bench_path(host)), "the host places a fire site")
	var site := _sites(host, &"fire")[0]
	if fill:
		builder.inventory.add(&"driftwood", 3)
		builder.inventory.add(&"dry_grass", 1)
		site.deposit(builder)
	return site


func _prompt_lines(hud: RunHud) -> PackedStringArray:
	hud.prompt.tick(STEP_S)
	return hud.prompt.lines()


# --- a client places and builds a rain catcher ----------------------------------------------------------

func test_a_clients_rain_catcher_is_placed_by_its_own_player_and_built_on_both_peers() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var me: int = net.peer_id(client)
	_place(host, client, me, _bench(client).global_position + AT_BENCH)
	var hud := _hud(client)
	watch_signals(hud.craft_list)
	hud.craft_list.open(_bench(client))
	assert_eq(hud.craft_list.row_texts(), PackedStringArray(["Fogata", "Recogedor de lluvia"]))
	assert_true(hud.craft_list.choose(1), "the client chooses Recogedor de lluvia")
	assert_signal_emitted_with_parameters(hud.craft_list, "craft_sent", [&"rain_catcher", _bench_path(client)])
	var theirs := await _wait_for_site(client, &"rain_catcher")
	var hosts := _sites(host, &"rain_catcher")
	assert_not_null(theirs, "the site reaches the client")
	assert_eq(hosts.size(), 1, "the host placed one")
	if theirs == null or hosts.is_empty():
		return
	var cell_by_client := IslandLayout.cell_center(SitePlacer.cell_at(host.body(me).position))
	assert_eq(hosts[0].position, cell_by_client, "by the client's own player, not the host's")
	assert_eq(theirs.position, hosts[0].position, "at the same place on both peers")
	assert_eq(String(theirs.name), String(hosts[0].name))
	# The client deposits and works it with its own press.
	host.body(me).inventory.add(&"driftwood", 4)
	host.body(me).inventory.add(&"tarp", 1)
	var mine := net.own_body(client)
	mine.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	var worked := func() -> bool: return hosts[0].inputs_complete() and hosts[0].progress() > 0.0
	assert_true(await wait_until(worked, TIMEOUT_S), "the client's press deposits and starts the work")
	mine.intent = MoveIntent.new()
	assert_true(await wait_until(func() -> bool: return theirs.inputs_complete(), TIMEOUT_S), "the client's copy has every input in")
	hosts[0].work(1.0)
	var built_on_both := func() -> bool:
		return _structures(host, RainCatcher).size() == 1 and _structures(client, RainCatcher).size() == 1 \
			and _sites(host, &"rain_catcher").is_empty() and _sites(client, &"rain_catcher").is_empty()
	assert_true(await wait_until(built_on_both, TIMEOUT_S), "built on both peers, one rain catcher on each")


# --- a fire site as a client sees it --------------------------------------------------------------------

func test_a_fire_site_on_a_client_lists_its_inputs_then_shows_the_bar_rising() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var hud := _hud(client)
	var host_site := _host_fire(host, false)
	var site := await _wait_for_site(client, &"fire")
	assert_not_null(site)
	if site == null:
		return
	_place(host, client, net.peer_id(client), site.global_position)
	assert_eq(_prompt_lines(hud), PackedStringArray(["[E] Construir Fogata", "Falta: Madera de la costa x3", "Yesca x1"]), "before deposits")
	var builder := host.body(CoopSession.HOST_ID)
	builder.global_position = host_site.global_position
	builder.inventory.add(&"driftwood", 3)
	assert_true(host.deposit_for(CoopSession.HOST_ID, host.get_path_to(host_site)))
	var wood_in := func() -> bool: return _prompt_lines(hud) == PackedStringArray(["[E] Construir Fogata", "Falta: Yesca x1"])
	assert_true(await wait_until(wood_in, TIMEOUT_S), "after 3 driftwood only the tinder is missing")
	builder.inventory.add(&"dry_grass", 1)
	assert_true(host.deposit_for(CoopSession.HOST_ID, host.get_path_to(host_site)), "the dry grass, and the host works it")
	var bar_shows := func() -> bool:
		_prompt_lines(hud)
		return hud.prompt.bar_progress() > 0.0
	assert_true(await wait_until(bar_shows, TIMEOUT_S), "the tag deposit reaches the client: the bar shows")
	assert_true(site.inputs_complete(), "the client's copy has every input in")
	var first: float = hud.prompt.bar_progress()
	var rising := func() -> bool:
		_prompt_lines(hud)
		return hud.prompt.bar_progress() > first
	assert_true(await wait_until(rising, TIMEOUT_S), "rising while the host works")


# --- joiners ---------------------------------------------------------------------------------------------

func test_a_client_joining_mid_build_sees_the_bar_at_50_percent() -> void:
	var host := net.add_host(_setup)
	var host_site := _host_fire(host, true)
	host_site.work(0.5)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var hud := _hud(client)
	var site := await _wait_for_site(client, &"fire")
	assert_not_null(site, "the joiner gets the site")
	if site == null:
		return
	_place(host, client, net.peer_id(client), site.global_position)
	var live := func() -> bool:
		_prompt_lines(hud)
		return is_equal_approx(hud.prompt.bar_progress(), 0.5)
	assert_true(await wait_until(live, TIMEOUT_S), "the bar at 50 %")
	assert_eq(_prompt_lines(hud), PackedStringArray(["[E] Construir Fogata", "50 %"]), "and no Falta: line")
	assert_true(site.inputs_complete())


func test_a_client_joining_after_a_fire_was_built_sees_one_lit_fire() -> void:
	var host := net.add_host(_setup)
	var host_site := _host_fire(host, true)
	host_site.work(1.0)
	assert_eq(_structures(host, Fire).size(), 1)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var one_fire := func() -> bool: return _structures(client, Fire).size() == 1
	assert_true(await wait_until(one_fire, TIMEOUT_S), "the joiner sees the fire")
	var fire := _structures(client, Fire)[0] as Fire if one_fire.call() else null
	if fire == null:
		return
	assert_true(fire.lit, "lit")
	assert_eq(fire.position, (_structures(host, Fire)[0] as Fire).position, "where the host built it")
	assert_true(_sites(client, &"fire").is_empty(), "and no site")


# --- refused requests ------------------------------------------------------------------------------------

func test_requests_the_host_refuses_change_nothing() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var me: int = net.peer_id(client)
	var theirs := host.body(me)
	_place(host, client, me, _bench(client).global_position + AT_BENCH)
	theirs.meters.solo = false
	theirs.meters.add(M.HEALTH, -theirs.meters.health)
	assert_true(theirs.meters.downed, "the client is down")
	client.craft(&"fire", _bench_path(client))
	await wait_physics_frames(20)
	assert_eq(_sites(host, &"fire").size(), 0, "a downed client places nothing")
	theirs.meters.revive()
	assert_false(theirs.meters.downed)
	_place(host, client, me, _bench(client).global_position + Vector2(0.0, 3.0 * 16.0))
	client.craft(&"fire", _bench_path(client))
	await wait_physics_frames(20)
	assert_eq(_sites(host, &"fire").size(), 0, "out of the bench's reach")
	_place(host, client, me, _bench(client).global_position + AT_BENCH)
	client.craft(&"fire", client.get_path_to(client.body(CoopSession.HOST_ID)))
	await wait_physics_frames(20)
	assert_eq(_sites(host, &"fire").size(), 0, "a station that is not a workbench")
	client.craft(&"fire", _bench_path(client))
	assert_not_null(await _wait_for_site(host, &"fire"), "the same request at the bench is placed: the waits were long enough")
