extends GutTest
## inventory-hud "Strip follows the host" over ENet on localhost (NetHarness): a client's strip
## shows what the host holds for its player once the host's state arrives and never before, the
## host's strip shows only the host's player, and a client that rejoins within 90 s gets its
## reclaimed body's strip.

const TILE: float = 16.0
const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const TIMEOUT_S: float = 5.0
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")

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


func _island(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()


func _as(identity: PlayerIdentity, player_name: String = "Papo") -> Callable:
	return func(session: CoopSession) -> void:
		session.local_identity = identity
		session.local_name = player_name


func _hud(session: CoopSession) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	huds.append(hud)
	hud.bind(session, net.peer_id(session), false)
	return hud


func _slot_text(hud: RunHud, index: int) -> String:
	var view := hud.strip.slot_view(index)
	return view.name_label.text if view != null else ""


func test_a_clients_strip_waits_for_the_hosts_state() -> void:
	var host := net.add_host(_island)
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var hud := _hud(client)
	assert_same(hud.strip.body, net.own_body(client), "the client's own player")
	host.body(net.peer_id(client)).inventory.add(&"driftwood", 1)
	assert_eq(_slot_text(hud, 0), "", "unchanged before the host's state arrives")
	var arrived := func() -> bool: return _slot_text(hud, 0) == "Mad"
	assert_true(await wait_until(arrived, TIMEOUT_S), "1 driftwood in screen slot 1")
	assert_eq(hud.strip.slot_view(0).count_label.text, "")
	assert_eq(hud.strip.weight_label.text, "Peso 2/30")


func test_a_clients_pick_up_reaches_its_strip() -> void:
	var host := net.add_host(_island)
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var hud := _hud(client)
	var mine := net.own_body(client)
	host.spawn_pickup(&"driftwood", 1, host.body(net.peer_id(client)).position + Vector2(0.5 * TILE, 0.0))
	mine.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	await wait_physics_frames(10)
	mine.intent = MoveIntent.new()
	var arrived := func() -> bool: return _slot_text(hud, 0) == "Mad"
	assert_true(await wait_until(arrived, TIMEOUT_S), "the driftwood the host gave shows in screen slot 1")
	assert_eq(mine.inventory.count_id(&"driftwood"), 1)


func test_the_hosts_strip_shows_only_the_hosts_player() -> void:
	var host := net.add_host(_island)
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var hud := _hud(host)
	assert_same(hud.strip.body, host.body(CoopSession.HOST_ID))
	host.body(net.peer_id(client)).inventory.add(&"driftwood", 1)
	await wait_physics_frames(5)
	assert_eq(_slot_text(hud, 0), "", "the client's driftwood is not the host's")
	host.body(CoopSession.HOST_ID).inventory.add(&"coco", 2)
	assert_eq(_slot_text(hud, 0), "Coc")
	assert_eq(hud.strip.slot_view(0).count_label.text, "2")


func test_a_rejoined_client_gets_its_reclaimed_bodys_strip() -> void:
	var papo := PlayerIdentity.create()
	var host := net.add_host(_island)
	var client := await net.join(_as(papo))
	assert_not_null(client)
	if client == null:
		return
	var old_id: int = net.peer_id(client)
	var papo_body := host.body(old_id)
	papo_body.inventory.add(&"driftwood", 2)
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(old_id), TIMEOUT_S), "Papo's body waits")
	var back := net.add_client(_as(papo))
	var hud := _hud(back)
	var reclaimed := func() -> bool:
		var mine := net.own_body(back)
		return mine != null and hud.strip.body == mine and _slot_text(hud, 0) == "Mad"
	assert_true(await wait_until(reclaimed, TIMEOUT_S), "the strip follows the reclaimed body")
	assert_same(host.body(net.peer_id(back)), papo_body, "the same body on the host")
	assert_eq(hud.strip.slot_view(0).count_label.text, "2")
	assert_eq(back.peer_of(hud.strip.body), net.peer_id(back), "the HUD acts for the body this peer owns now")
	assert_null(hud.strip.body.get_node_or_null(^"NameTag"), "no tag over your own player")
