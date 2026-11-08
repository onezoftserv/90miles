extends GutTest
## inventory-hud "Interact prompt" and "Build site prompt" over ENet on localhost (NetHarness), each
## peer with its own sandbar: a client's prompt over its own copy of the raft site, and the shared
## build progress it shows once the host's state arrives. Only the prompts are read here; nothing
## presses a key, so each peer's HUD reads its own body.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
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


# The shell's order, as in test_sandbar_net.gd: the island, the session's terrain and spawn points,
# furnish (the raft site goes in the session on every peer).
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


# Puts `peer`'s player at `at` on the host and on `session`'s copy, so the client's prediction
# agrees with the host's state.
func _place(host: CoopSession, session: CoopSession, peer: int, at: Vector2) -> void:
	host.body(peer).global_position = at
	session.body(peer).global_position = at


func test_a_client_sees_the_shared_progress_at_50_percent() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var hud := _hud(client)
	var me: int = net.peer_id(client)
	var host_site := host.get_node("RaftSite") as BuildSite
	var builder := host.body(CoopSession.HOST_ID)
	builder.global_position = host_site.global_position
	builder.inventory.add(&"driftwood", 6)
	builder.inventory.add(&"inner_tube", 2)
	builder.inventory.add(&"rope", 3)
	host_site.deposit(builder)
	host_site.work(0.5)
	var site := client.get_node("RaftSite") as BuildSite
	_place(host, client, me, site.global_position + Vector2(4.0, 0.0))
	var half := func() -> bool:
		hud.prompt.tick(STEP_S)
		return is_equal_approx(hud.prompt.bar_progress(), 0.5)
	assert_true(await wait_until(half, TIMEOUT_S), "the client's prompt shows the host's progress")
	assert_same(hud.prompt.target, site.interactable, "over the client's own copy")
	assert_eq(hud.prompt.lines(), PackedStringArray(["[E] Construir Balsa", "50 %"]))
