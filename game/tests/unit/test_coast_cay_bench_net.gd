extends GutTest
## island-generation "Fire at the coast cay's workbench" (coast-cay-bench) over ENet on localhost
## (NetHarness): a host and a client on the real sandbar travel to the coast cay; the client's bench
## stands where the host's does, on the layout's bench cell; the client's own request places a fire
## site at it, and once the host has built the fire the client's copy is lit where the host's is.
## Each branch builds the island and the IslandTravel the way the shell does, so the bench comes
## from the coast cay's layout and nothing else.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TIMEOUT_S: float = 6.0
const COAST: StringName = &"coast_cay"
const BENCH_NAME: StringName = &"HutWorkbench"

var net: NetHarness


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	net.teardown()


# The shell's order: the island beside the session, the session's ground and spawn points,
# furnish, then the travel keeper.
func _setup(session: CoopSession) -> void:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.with_creatures = false
	session.get_parent().add_child(island)
	session.terrain = island.terrain
	session.climate = island.climate
	session.spawn_points = island.spawn_points(false)
	island.furnish(session)
	var travel := IslandTravel.new()
	travel.name = "Travel"
	session.add_child(travel)
	travel.setup(session, island)


func _travel(session: CoopSession) -> IslandTravel:
	return session.get_node("Travel") as IslandTravel


func _bench(session: CoopSession) -> Workbench:
	var bench := session.get_node_or_null(NodePath(BENCH_NAME)) as Workbench
	return bench if bench != null and not bench.is_queued_for_deletion() else null


func _fire_sites(session: CoopSession) -> Array[BuildSite]:
	var found: Array[BuildSite] = []
	for node: Node in session.entities.get_children():
		var site := node as BuildSite
		if site != null and not site.is_queued_for_deletion() and site.recipe.id == &"fire":
			found.append(site)
	return found


func _fires(session: CoopSession) -> Array[Fire]:
	var found: Array[Fire] = []
	for node: Node in session.entities.get_children():
		if node is Fire and not node.is_queued_for_deletion():
			found.append(node as Fire)
	return found


func test_the_benchs_fire_shows_on_a_client_on_the_coast_cay() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	_travel(host).travel(COAST)
	var on_the_cay := func() -> bool:
		return _travel(host).island.layout.id == COAST and _travel(client).island.layout.id == COAST \
			and _bench(host) != null and _bench(client) != null
	assert_true(await wait_until(on_the_cay, TIMEOUT_S), "both peers are on the coast cay, each with a bench")
	if not on_the_cay.call():
		return
	var cell: Vector2i = _travel(client).island.built.workbench
	assert_ne(cell, Vector2i(-1, -1), "the client's coast cay has a bench cell")
	assert_eq(_bench(client).position, IslandLayout.cell_center(cell), "the client's bench is on the layout's cell")
	assert_eq(_bench(client).position, _bench(host).position, "where the host's bench is")
	# The client's player stands by the bench on both peers and asks for a fire there.
	var me: int = net.peer_id(client)
	var by_bench: Vector2 = _bench(host).global_position + Vector2(0.0, IslandLayout.TILE)
	host.body(me).global_position = by_bench
	client.body(me).global_position = by_bench
	client.craft(&"fire", client.get_path_to(_bench(client)))
	var placed := func() -> bool: return _fire_sites(host).size() == 1 and _fire_sites(client).size() == 1
	assert_true(await wait_until(placed, TIMEOUT_S), "the client's request places one fire site, seen on both peers")
	if not placed.call():
		return
	var host_site := _fire_sites(host)[0]
	assert_eq(_fire_sites(client)[0].position, host_site.position, "at the same place")
	# The host gives the client's player the inputs and works the site to the end.
	var builder := host.body(me)
	builder.global_position = host_site.global_position
	builder.inventory.add(&"driftwood", 3)
	builder.inventory.add(&"dry_grass", 1)
	assert_true(host.deposit_for(me, host.get_path_to(host_site)), "the host takes the client's deposit")
	host_site.work(1.0)
	assert_eq(_fires(host).size(), 1, "the host built one fire")
	if _fires(host).is_empty():
		return
	var host_fire := _fires(host)[0]
	var lit_on_client := func() -> bool:
		var copies := _fires(client)
		return copies.size() == 1 and copies[0].lit and copies[0].is_in_group(PlayerBody.FIRE_GROUP) \
			and _fire_sites(client).is_empty()
	assert_true(await wait_until(lit_on_client, TIMEOUT_S), "the client's copy of the fire is lit, and its site is gone")
	if not lit_on_client.call():
		return
	assert_eq(_fires(client)[0].position, host_fire.position, "where the host's fire is")
	assert_eq(String(_fires(client)[0].name), String(host_fire.name))
