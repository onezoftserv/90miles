extends GutTest
## guardacostas-stealth, group 5 with a host and a client (NetHarness): a client's player using the
## noise item raises the noise once, on the host, at that player's position; the client's own bus
## emits nothing (the host decides what the world heard).

const FIXTURES: String = "res://tests/fixtures/content"
const TIMEOUT_S: float = 5.0

var net: NetHarness
var host_heard: Array = []
var client_heard: Array = []


func before_each() -> void:
	net = NetHarness.new(self)
	host_heard = []
	client_heard = []


func after_each() -> void:
	net.teardown()


func test_a_clients_noise_is_raised_once_on_the_host_at_their_position() -> void:
	var host := net.add_host()
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	assert_true(await net.settle())
	var id: int = net.peer_id(client)
	var theirs := host.body(id)
	theirs.global_position = Vector2(320.0, 144.0)
	theirs.inventory.catalog = ContentCatalog.new(FIXTURES)
	theirs.inventory.add(&"noise_test", 1)
	(host.get_node(^"WorldEvents") as WorldEvents).noise_made.connect(
		func(at: Vector2, radius: float, source: StringName) -> void: host_heard.append([at, radius, source]))
	(client.get_node(^"WorldEvents") as WorldEvents).noise_made.connect(
		func(at: Vector2, radius: float, source: StringName) -> void: client_heard.append([at, radius, source]))
	client.use_item(0, 0)
	assert_true(await wait_until(func() -> bool: return host_heard.size() >= 1, TIMEOUT_S))
	await wait_seconds(0.5)
	assert_eq(host_heard.size(), 1, "raised once")
	assert_eq(host_heard[0][0], theirs.global_position)
	assert_almost_eq(host_heard[0][1] as float, 15.0, 0.000001)
	assert_eq(client_heard.size(), 0, "the client's bus emits nothing")


func test_a_client_bus_emits_nothing_even_when_asked() -> void:
	net.add_host()
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var bus := client.get_node(^"WorldEvents") as WorldEvents
	bus.noise_made.connect(func(at: Vector2, radius: float, source: StringName) -> void: client_heard.append([at, radius, source]))
	bus.smoke_rose.connect(func(_at: Vector2, _fire: Node2D) -> void: client_heard.append("smoke"))
	bus.make_noise(Vector2.ZERO, 15.0, &"forged")
	bus.raise_smoke(Vector2.ZERO, null)
	assert_eq(client_heard.size(), 0)
