extends GutTest
## hud-clarity over ENet on localhost (NetHarness), a host and a client in one process, each with its
## own sky: ui-shell "The clock follows the host" (a client's clock row matches the host's after a
## resync), "Objective while building the raft" (a client's objective row follows the host's
## deposits in the level's raft site) and survival-meters "Bleeding time on every peer" (a client's
## Sangrando bar follows the host's time left).

const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const SITE_SCENE: PackedScene = preload("res://scenes/structures/build_site.tscn")
const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const RAFT_CELL: Vector2i = Vector2i(10, 6)
const TIMEOUT_S: float = 5.0
## 14:00 on the one clock.
const AFTERNOON_S: float = 240.0

var net: NetHarness
var host_sky: WorldSky
# Freed before the sessions they read.
var huds: Array[Node] = []


func before_each() -> void:
	net = NetHarness.new(self)
	huds.clear()
	WeatherManager.stop()
	host_sky = WorldSky.from_catalog(GameState.content)
	host_sky.weather.rolls_enabled = false


func after_each() -> void:
	for hud: Node in huds:
		if is_instance_valid(hud):
			hud.free()
	huds.clear()
	net.teardown()


# Every peer: the spawn points and the level's raft site at the same path, as SandbarIsland has it.
func _furnish(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()
	var site := SITE_SCENE.instantiate() as BuildSite
	site.name = &"RaftSite"
	site.recipe = GameState.content.get_entry(&"recipes", &"raft") as RecipeData
	site.synced = true
	site.structure_name = &"Raft"
	site.position = IslandLayout.cell_center(RAFT_CELL)
	session.add_child(site)


func _host(session: CoopSession) -> void:
	_furnish(session)
	session.sky = host_sky
	session.climate = host_sky.climate


func _client(session: CoopSession) -> void:
	_furnish(session)
	var sky := WorldSky.from_catalog(GameState.content)
	sky.weather.rolls_enabled = false
	session.sky = sky
	session.climate = sky.climate


func _hud(session: CoopSession) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	huds.append(hud)
	hud.bind(session, net.peer_id(session), false)
	return hud


func _pair() -> Array[CoopSession]:
	var host := net.add_host(_host)
	var client := await net.join(_client)
	assert_not_null(client, "the client joined")
	if client == null:
		return [] as Array[CoopSession]
	assert_true(await net.settle())
	net.silence_input()
	return [host, client] as Array[CoopSession]


func test_a_clients_clock_matches_the_hosts() -> void:
	host_sky.clock.set_time(AFTERNOON_S, 2)
	host_sky.advance(0.001)
	var pair := await _pair()
	if pair.is_empty():
		return
	var host: CoopSession = pair[0]
	var client: CoopSession = pair[1]
	host.send_sky()
	var synced := func() -> bool: return client.sky.clock.day == 2 and absf(client.sky.clock.time_of_day_s - host_sky.clock.time_of_day_s) < 1.0
	assert_true(await wait_until(synced, TIMEOUT_S), "the client took the host's clock")
	var host_hud := _hud(host)
	var client_hud := _hud(client)
	await wait_process_frames(2)
	for hud: RunHud in [host_hud, client_hud]:
		assert_eq(hud.clock.day_label.text, "Día 2")
		assert_eq(hud.clock.left_label.text, "6h")
		assert_eq(hud.phase_label.text, "Mediodía")
	assert_eq(client_hud.clock.strip.marker_px, host_hud.clock.strip.marker_px, "the marker at the same place")


func test_a_clients_objective_follows_the_hosts_deposits() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host: CoopSession = pair[0]
	var client: CoopSession = pair[1]
	var client_hud := _hud(client)
	await wait_process_frames(2)
	assert_eq(client_hud.objective_row.label.text, "Arma la balsa: 0/6 madera", "an empty site, nothing carried")
	var builder := host.body(CoopSession.HOST_ID)
	builder.inventory.add(&"driftwood", 6)
	(host.get_node(^"RaftSite") as BuildSite).deposit(builder)
	var site := client.get_node(^"RaftSite") as BuildSite
	assert_true(await wait_until(func() -> bool: return site.deposited.get(&"driftwood", 0) == 6, TIMEOUT_S), "the deposit reached the client")
	await wait_process_frames(2)
	assert_eq(client_hud.objective_row.label.text, "Arma la balsa: 0/2 cámaras", "the client's row follows the host's site")


func test_a_clients_sangrando_bar_follows_the_hosts_time() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host: CoopSession = pair[0]
	var client: CoopSession = pair[1]
	var client_id: int = net.peer_id(client)
	var client_hud := _hud(client)
	var on_host := host.body(client_id).meters
	on_host.set_status(DataEnums.Status.BLEEDING, true)
	on_host.tick(60.0, MeterContext.new())
	var own := net.own_body(client).meters
	var halfway := func() -> bool: return own.has_status(DataEnums.Status.BLEEDING) and absf(own.bleeding_left_s - on_host.bleeding_left_s) < 0.5
	assert_true(await wait_until(halfway, TIMEOUT_S), "the client holds the host's time left")
	await wait_process_frames(2)
	var row := client_hud.meters.status_row(&"bleeding")
	assert_true(row.visible, "Sangrando shows on the client")
	assert_almost_eq(row.fill_ratio(), on_host.bleeding_left_s / on_host.tuning.bleeding_s, 0.02, "its bar at the host's time left")
