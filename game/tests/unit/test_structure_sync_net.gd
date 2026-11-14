extends GutTest
## coop-networking "Structure state on every peer", "Structure state for joiners" and "Structure
## messages come only from the host" (structure-state-sync), over ENet on localhost (NetHarness):
## a client holds the host's fire (lit or out) and rain-catcher cups, while it plays and when it
## joins late, and a client's own change to its copy reaches no one: the fire and catcher tests give
## each peer a bench at the same path on a featureless beach, built at by the host's player. Palms are
## tested on the real sandbar, one per peer as the shell has it (here beside the branches, as in
## test_crossing_join.gd): a client, a late joiner and a rejoined player hold the host's counts, a
## client's forged count reaches no one, and a joiner after the party travelled gets the coast cay's
## counts once it has built that island. The raft site and raft (design D2, no code change) are
## checked with a real route start: a joiner before the launch has the raft, one during the crossing
## a fresh site, as the host has them.

const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const BENCH_NAME: StringName = &"HutWorkbench"
const BENCH_CELL: Vector2i = Vector2i(6, 6)
## Inside the cell south of the bench, within its reach.
const AT_BENCH: Vector2 = Vector2(0.0, 10.0)
const SQUALL: StringName = &"squall"
const CALM: StringName = &"calm"
const RAIN_CUP: StringName = &"rain_cup"
const TIMEOUT_S: float = 5.0
const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
## The sandbar's first palm holds 2 of its 10 coconuts; each coast cay palm holds 2.
const PALM: int = 0
const TRAVEL_NAME: StringName = &"Travel"
const RAFT_SITE_NAME: StringName = &"RaftSite"
const RAFT_NAME: StringName = &"Raft"

var net: NetHarness
var rng := RandomNumberGenerator.new()
var islands: Array[SandbarIsland] = []
## Session instance id -> the island built for it.
var island_of: Dictionary[int, SandbarIsland] = {}


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	net.teardown()
	for island: SandbarIsland in islands:
		if is_instance_valid(island):
			island.free()
	islands.clear()
	island_of.clear()


# Every peer: the spawn points and the bench at the same path.
func _setup(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()
	var bench := Workbench.new()
	bench.name = BENCH_NAME
	bench.position = IslandLayout.cell_center(BENCH_CELL)
	session.add_child(bench)


func _bench(session: CoopSession) -> Workbench:
	return session.get_node(NodePath(BENCH_NAME)) as Workbench


func _structures(session: CoopSession, kind: Script) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in session.entities.get_children():
		if node.get_script() == kind and not node.is_queued_for_deletion():
			found.append(node)
	return found


# `session`'s copy of the host's structure `made` (the same name), or null.
func _copy(session: CoopSession, made: Node) -> Node:
	var found := session.entities.get_node_or_null(NodePath(made.name))
	return found if found != null and not found.is_queued_for_deletion() else null


# Host: the host's player builds `recipe_id` at the bench (every input in, all the work done) and
# the structure it became.
func _host_builds(host: CoopSession, recipe_id: StringName, inputs: Dictionary) -> Node2D:
	var builder := host.body(CoopSession.HOST_ID)
	var bench := _bench(host)
	builder.global_position = bench.global_position + AT_BENCH
	assert_true(host.craft_for(CoopSession.HOST_ID, recipe_id, host.get_path_to(bench)), "the host places a %s site" % recipe_id)
	var site: BuildSite = null
	for node: Node in host.entities.get_children():
		if node is BuildSite and (node as BuildSite).recipe.id == recipe_id and not node.is_queued_for_deletion():
			site = node
	for id: StringName in inputs:
		builder.inventory.add(id, inputs[id])
	site.deposit(builder)
	var before: Array[Node] = _structures(host, RainCatcher if recipe_id == &"rain_catcher" else Fire)
	site.work(1.0)
	for node: Node in _structures(host, RainCatcher if recipe_id == &"rain_catcher" else Fire):
		if not before.has(node):
			return node as Node2D
	return null


func _host_fire(host: CoopSession) -> Fire:
	return _host_builds(host, &"fire", {&"driftwood": 3, &"dry_grass": 1}) as Fire


func _host_catcher(host: CoopSession) -> RainCatcher:
	return _host_builds(host, &"rain_catcher", {&"driftwood": 4, &"tarp": 1}) as RainCatcher


# Host: a squall has fallen on `catcher` for the whole fill time, so it holds its cup.
func _fill(host: CoopSession, catcher: RainCatcher) -> void:
	host.climate.weather_id = SQUALL
	catcher.advance(catcher.tuning.rain_fill_s)
	host.climate.weather_id = CALM
	assert_eq(catcher.cups, 1, "the host's catcher filled")


# The look drawn now, after one step.
func _frame(structure: Node) -> StringName:
	var look := structure.get_node(NodePath(StructureLook.NODE_NAME)) as StructureLook
	look.step()
	return look.frame()


# A fire that is out on this peer: not lit, not one of the lit fires, nothing to use, drawn as embers.
func _is_out(fire: Fire) -> bool:
	return not fire.lit and not fire.is_in_group(PlayerBody.FIRE_GROUP) and not fire.interactable.enabled \
		and _frame(fire) == StructureArt.FIRE_OUT


func _is_burning(fire: Fire) -> bool:
	return fire.lit and fire.is_in_group(PlayerBody.FIRE_GROUP) and fire.interactable.enabled \
		and _frame(fire) == StructureArt.FIRE_LIT


# --- a connected client -----------------------------------------------------------------------------------

func test_a_clients_copy_of_a_new_fire_is_lit_from_its_first_frame() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var lit_at_ready: Array[bool] = []
	client.entities.child_entered_tree.connect(func(node: Node) -> void:
		if node is Fire:
			node.ready.connect(func() -> void: lit_at_ready.append((node as Fire).lit), CONNECT_ONE_SHOT))
	var fire := _host_fire(host)
	assert_not_null(fire, "the host built a fire")
	if fire == null:
		return
	assert_true(await wait_until(func() -> bool: return _copy(client, fire) != null, TIMEOUT_S), "the fire reaches the client")
	assert_eq(lit_at_ready, [true], "lit when the client's copy became ready")
	var copy := _copy(client, fire) as Fire
	for i: int in 10:
		await wait_physics_frames(1)
		assert_true(_is_burning(copy), "still lit on frame %d" % i)


func test_a_client_sees_a_fire_put_out_and_another_burn_out_on_the_host() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var fire := _host_fire(host)
	assert_true(await wait_until(func() -> bool: return _copy(client, fire) != null, TIMEOUT_S), "the fire reaches the client")
	var copy := _copy(client, fire) as Fire
	assert_true(_is_burning(copy), "lit on the client")
	fire.put_out()
	assert_true(await wait_until(_is_out.bind(copy), TIMEOUT_S), "put out on the host: out on the client")
	var second := _host_fire(host)
	assert_true(await wait_until(func() -> bool: return _copy(client, second) != null, TIMEOUT_S), "the second fire reaches the client")
	var second_copy := _copy(client, second) as Fire
	assert_true(_is_burning(second_copy), "the second is lit on the client")
	second.advance(second.tuning.fire_burn_s + 1.0)
	assert_false(second.lit, "burnt out on the host")
	assert_true(await wait_until(_is_out.bind(second_copy), TIMEOUT_S), "burnt out on the host: out on the client")


func test_a_client_sees_the_catcher_fill_and_empty_on_the_host() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var catcher := _host_catcher(host)
	assert_not_null(catcher, "the host built a rain catcher")
	if catcher == null:
		return
	assert_true(await wait_until(func() -> bool: return _copy(client, catcher) != null, TIMEOUT_S), "the catcher reaches the client")
	var copy := _copy(client, catcher) as RainCatcher
	assert_eq(_frame(copy), StructureArt.CATCHER_EMPTY)
	_fill(host, catcher)
	var full := func() -> bool: return copy.cups == 1 and _frame(copy) == StructureArt.CATCHER_WATER
	assert_true(await wait_until(full, TIMEOUT_S), "filled on the host: 1 cup and water on the client")
	var taker := host.body(CoopSession.HOST_ID)
	taker.global_position = catcher.global_position
	catcher.interactable.use(taker)
	assert_eq(taker.inventory.count_id(RAIN_CUP), 1, "the host's player took the cup")
	var empty := func() -> bool: return copy.cups == 0 and _frame(copy) == StructureArt.CATCHER_EMPTY
	assert_true(await wait_until(empty, TIMEOUT_S), "taken on the host: none and empty on the client")


# --- a late joiner ----------------------------------------------------------------------------------------

func test_a_late_joiner_gets_a_fire_put_out_and_a_filled_catcher() -> void:
	var host := net.add_host(_setup)
	var fire := _host_fire(host)
	fire.put_out()
	var catcher := _host_catcher(host)
	_fill(host, catcher)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var both := func() -> bool: return _copy(client, fire) != null and _copy(client, catcher) != null
	assert_true(await wait_until(both, TIMEOUT_S), "the joiner gets both structures")
	if not both.call():
		return
	var fire_copy := _copy(client, fire) as Fire
	var catcher_copy := _copy(client, catcher) as RainCatcher
	assert_true(_is_out(fire_copy), "the fire put out before the joiner came is out")
	await wait_physics_frames(10)
	assert_true(_is_out(fire_copy), "and stays out")
	assert_eq(catcher_copy.cups, 1, "the catcher holds the host's cup")
	assert_eq(_frame(catcher_copy), StructureArt.CATCHER_WATER)


# --- only the host --------------------------------------------------------------------------------------

func test_a_clients_own_fire_put_out_reaches_no_one() -> void:
	var host := net.add_host(_setup)
	var a := await net.join(_setup)
	var b := await net.join(_setup)
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	var fire := _host_fire(host)
	var copies := func() -> bool: return _copy(a, fire) != null and _copy(b, fire) != null
	assert_true(await wait_until(copies, TIMEOUT_S), "the fire reaches both clients")
	if not copies.call():
		return
	(_copy(a, fire) as Fire).put_out()
	await wait_physics_frames(30)
	assert_true(_is_burning(fire), "the host's fire burns")
	assert_true(_is_burning(_copy(b, fire) as Fire), "the other client's fire burns")
	assert_eq(get_errors().size(), 0, "no error lines")


# --- palms on the real sandbar ---------------------------------------------------------------------------

# Every peer: its own sandbar, without creatures, furnished into the session.
func _island_setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.with_creatures = false
	add_child(island)
	islands.append(island)
	island_of[session.get_instance_id()] = island
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)


func _as(identity: PlayerIdentity) -> Callable:
	return func(session: CoopSession) -> void:
		_island_setup(session)
		session.local_identity = identity


# The island `session` stands on now: its keeper's, once the party can travel.
func _island(session: CoopSession) -> SandbarIsland:
	var travel := session.get_node_or_null(NodePath(TRAVEL_NAME)) as IslandTravel
	if travel != null:
		return travel.island
	return island_of[session.get_instance_id()]


func _palm(session: CoopSession, index: int = PALM) -> Palm:
	return _island(session).palms[index]


func _coconuts_drawn(palm: Palm) -> int:
	var look := palm.get_node(NodePath(StructureLook.NODE_NAME)) as StructureLook
	look.step()
	return look.coconuts_drawn()


# Host: its own player climbs `palm` (the interaction the host runs for any player's hold).
func _climb(host: CoopSession, palm: Palm) -> void:
	var climber := host.body(CoopSession.HOST_ID)
	climber.global_position = palm.global_position
	var had: int = palm.coconuts
	palm.interactable.use(climber)
	assert_eq(palm.coconuts, had - 1, "the host's palm lost a coconut")


func test_a_client_sees_a_palm_climbed_on_the_host() -> void:
	var host := net.add_host(_island_setup)
	var client := await net.join(_island_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_eq(_palm(client).coconuts, 2, "2 on the client first")
	_climb(host, _palm(host))
	var one := func() -> bool: return _palm(client).coconuts == 1 and _coconuts_drawn(_palm(client)) == 1
	assert_true(await wait_until(one, TIMEOUT_S), "the client's palm has 1 and draws 1")
	assert_eq(_palm(client, 1).coconuts, 2, "the next palm keeps its 2")


func test_a_late_joiner_gets_a_palm_climbed_before_it_came() -> void:
	var host := net.add_host(_island_setup)
	_climb(host, _palm(host))
	var client := await net.join(_island_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await wait_until(func() -> bool: return _palm(client).coconuts == 1, TIMEOUT_S), "the joiner's palm has the host's 1")
	assert_eq(_coconuts_drawn(_palm(client)), 1)
	assert_eq(get_errors().size(), 0, "no error lines")


func test_a_rejoined_player_gets_a_palm_climbed_while_away() -> void:
	var papo := PlayerIdentity.create()
	var host := net.add_host(_island_setup)
	var first := await net.join(_as(papo))
	assert_not_null(first)
	if first == null:
		return
	var old_id: int = net.peer_id(first)
	net.drop(first)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(old_id), TIMEOUT_S), "the host saw Papo drop")
	_climb(host, _palm(host))
	var back := await net.join(_as(papo))
	assert_not_null(back, "Papo joins again")
	if back == null:
		return
	assert_not_null(host.body(net.peer_id(back)), "the host has Papo's body under his new peer")
	assert_false(host.is_dropped(old_id), "Papo took back his player")
	assert_true(await wait_until(func() -> bool: return _palm(back).coconuts == 1, TIMEOUT_S), "his palm has the host's 1")


func test_a_clients_forged_palm_count_reaches_no_one() -> void:
	var host := net.add_host(_island_setup)
	var a := await net.join(_island_setup)
	var b := await net.join(_island_setup)
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	assert_true(await net.settle())
	var forger := a.get_node(NodePath(SandbarIsland.PALM_SYNC_NAME)) as PalmSync
	forger.receive_count.rpc(PALM, 0)
	forger.receive_counts.rpc(PackedInt32Array([0, 0, 0, 0, 0, 0]))
	await wait_seconds(0.3)
	assert_eq(_palm(host).coconuts, 2, "the host's palm keeps its 2")
	assert_eq(_palm(b).coconuts, 2, "the other client's palm keeps its 2")
	assert_engine_error("not allowed", "the host's engine refuses the forged count")
	assert_engine_error("not allowed", "and the forged list")


# --- a joiner on the second island ------------------------------------------------------------------------

# Every peer: the sandbar and the island keeper the shell adds, so the party can travel and a joiner
# follows the host to its island.
func _travel_setup(session: CoopSession) -> void:
	_island_setup(session)
	var travel := IslandTravel.new()
	travel.name = TRAVEL_NAME
	session.add_child(travel)
	travel.setup(session, island_of[session.get_instance_id()])


func test_a_joiner_on_the_coast_cay_gets_that_islands_palm_counts() -> void:
	var host := net.add_host(_travel_setup)
	var next: StringName = _island(host).layout.next_island
	(host.get_node(NodePath(TRAVEL_NAME)) as IslandTravel).travel(next)
	var arrived := func() -> bool: return _island(host).layout.id == next and _island(host).is_inside_tree()
	assert_true(await wait_until(arrived, TIMEOUT_S), "the host's party is on the %s" % next)
	assert_eq(_palm(host).coconuts, 2, "a coast cay palm holds 2")
	_climb(host, _palm(host))
	var client := await net.join(_travel_setup)
	assert_not_null(client)
	if client == null:
		return
	var followed := func() -> bool: return _island(client).layout.id == next and _palm(client).coconuts == 1
	assert_true(await wait_until(followed, TIMEOUT_S), "the joiner builds the %s and its palm has the host's 1, not the layout's 2" % next)
	assert_eq(_coconuts_drawn(_palm(client)), 1)
	assert_eq(_palm(client, 1).coconuts, 2, "the next palm keeps its 2")
	assert_eq(get_errors().size(), 0, "no error lines")


# --- the raft on the real island, launched by a real route start ------------------------------------------

# Every peer: the sandbar, with a crossing launched on every route start (the shell's job).
func _crossing_setup(session: CoopSession) -> void:
	_island_setup(session)
	var routes := session.get_node("Routes") as IslandRoutes
	routes.route_started.connect(func(id: StringName, peers: Array[int]) -> void:
		var route := GameState.content.get_entry(&"routes", id) as RouteData
		var integrity: float = routes.departure_integrity.get(id, float(route.vessel_integrity))
		Crossing.launch(session, route, peers, integrity, DataEnums.DistanceBand.COAST, rng))


# Host: the host's player fills the sandbar's raft site and builds the raft.
func _host_builds_raft(host: CoopSession) -> void:
	var site := host.get_node(NodePath(RAFT_SITE_NAME)) as BuildSite
	var builder := host.body(CoopSession.HOST_ID)
	builder.global_position = site.global_position
	builder.inventory.add(&"driftwood", 6)
	builder.inventory.add(&"inner_tube", 2)
	builder.inventory.add(&"rope", 3)
	site.deposit(builder)
	site.work(1.0)
	assert_true(host.has_node(NodePath(RAFT_NAME)), "the host built the raft")


func _has_raft_and_no_site(session: CoopSession) -> bool:
	var raft := session.get_node_or_null(NodePath(RAFT_NAME)) as Raft
	return raft != null and raft.recipe_id == &"raft" and not session.has_node(NodePath(RAFT_SITE_NAME))


# An unbuilt raft site with nothing deposited and no raft.
func _has_fresh_site_and_no_raft(session: CoopSession) -> bool:
	var site := session.get_node_or_null(NodePath(RAFT_SITE_NAME)) as BuildSite
	if site == null or site.is_queued_for_deletion() or site.built or session.has_node(NodePath(RAFT_NAME)):
		return false
	for id: StringName in site.deposited:
		if site.deposited[id] > 0:
			return false
	for tag: int in site.tags_deposited:
		if site.tags_deposited[tag] > 0:
			return false
	return site.progress() == 0.0


func test_a_joiner_before_the_launch_has_the_raft_and_no_site() -> void:
	var host := net.add_host(_crossing_setup)
	_host_builds_raft(host)
	var client := await net.join(_crossing_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await wait_until(_has_raft_and_no_site.bind(client), TIMEOUT_S), "the joiner has the raft and no site")
	await wait_physics_frames(20)
	assert_eq(get_errors().size(), 0, "no error lines")


func test_a_joiner_during_the_crossing_has_a_fresh_site_and_no_raft_as_the_host() -> void:
	var host := net.add_host(_crossing_setup)
	_host_builds_raft(host)
	assert_true(host.start_route_for(CoopSession.HOST_ID, &"raft"), "the host launches the raft")
	var crossing := host.get_node_or_null("Crossing0") as Crossing
	assert_not_null(crossing, "the crossing is under way")
	if crossing == null:
		return
	crossing.plan = CrossingPlan.create(600.0)
	assert_true(_has_fresh_site_and_no_raft(host), "the host's sandbar: a fresh site and no raft")
	var client := await net.join(_crossing_setup)
	assert_not_null(client)
	if client == null:
		return
	await wait_physics_frames(30)
	assert_true(_has_fresh_site_and_no_raft(client), "the joiner's sandbar: a fresh site and no raft, as the host's")
	var site := client.get_node(NodePath(RAFT_SITE_NAME)) as BuildSite
	var look := site.get_node(NodePath(StructureLook.NODE_NAME)) as StructureLook
	look.step()
	assert_eq(look.frame(), StructureArt.SITE_MARKED, "drawn as marked")
	assert_eq(get_errors().size(), 0, "no error lines")
