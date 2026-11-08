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


func _as(identity: PlayerIdentity, player_name: String = "Papo") -> Callable:
	return func(session: CoopSession) -> void:
		_setup(session)
		session.local_identity = identity
		session.local_name = player_name


func test_a_clients_prompt_needs_no_host_message() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return
	var host_hud := _hud(host)
	var hud := _hud(client)
	var site := client.get_node("RaftSite") as BuildSite
	var mine := net.own_body(client)
	# Only this peer's copy moves: no host message can have told it about the site since.
	mine.global_position = site.global_position + Vector2(-8.0, 0.0)
	hud.prompt.tick(STEP_S)
	assert_same(hud.prompt.target, site.interactable, "the client's own copy of the site")
	assert_eq(hud.prompt.lines()[0], "[E] Construir Balsa")
	var host_body := host.body(CoopSession.HOST_ID)
	host_hud.prompt.tick(STEP_S)
	var own: Array[Interactable] = []
	for node: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
		if node is Interactable and host.is_ancestor_of(node):
			own.append(node as Interactable)
	assert_same(host_hud.prompt.target, InteractionPicker.pick(host_body.global_position, own, host_body), "the host's prompt reads the host's own player")
	assert_ne(host_hud.prompt.target, site.interactable)
	assert_ne(host_hud.prompt.target, (host.get_node("RaftSite") as BuildSite).interactable, "the host's player is nowhere near it")


func test_a_rejoined_client_shows_the_prompt_over_what_its_reclaimed_body_reaches() -> void:
	var papo := PlayerIdentity.create()
	var host := net.add_host(_setup)
	var client := await net.join(_as(papo))
	assert_not_null(client)
	if client == null:
		return
	var old_id: int = net.peer_id(client)
	var papo_body := host.body(old_id)
	papo_body.global_position = (host.get_node("RaftSite") as Node2D).global_position + Vector2(4.0, 0.0)
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(old_id), TIMEOUT_S), "Papo's body waits")
	var back := net.add_client(_as(papo))
	var hud := _hud(back)
	var reclaimed := func() -> bool:
		var mine := net.own_body(back)
		hud.prompt.tick(STEP_S)
		return mine != null and hud.prompt.body == mine and hud.prompt.lines().size() > 0 \
			and hud.prompt.lines()[0] == "[E] Construir Balsa"
	assert_true(await wait_until(reclaimed, TIMEOUT_S), "the prompt follows the reclaimed body to the raft site")
	assert_same(host.body(net.peer_id(back)), papo_body, "the same body on the host")
	assert_same(hud.prompt.target, (back.get_node("RaftSite") as BuildSite).interactable)
