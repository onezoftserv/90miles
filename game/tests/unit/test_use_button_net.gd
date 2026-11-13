extends GutTest
## inventory-hud "Using the selected item", "Which use the button picks" and "Refused uses" over
## ENet on localhost (NetHarness): a client's F asks the host, the host applies the use and the
## client's strip changes only when the host's inventory arrives; a client revives the downed
## host's player with a rain cup; a forged use changes nothing; a rejoined client's F acts for its
## reclaimed body. Only the client gets a HUD: the use button is read from the one global Input.

const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const TIMEOUT_S: float = 5.0
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const M := DataEnums.Meter
const HALF_TILE: Vector2 = Vector2(8.0, 0.0)

var net: NetHarness
# Freed before the sessions they read.
var huds: Array[Node] = []


func before_each() -> void:
	net = NetHarness.new(self)
	huds.clear()


func after_each() -> void:
	Input.action_release(InventoryStrip.USE_ACTION)
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
	watch_signals(hud.strip)
	return hud


## The id of the item slot `index` shows by its icon, "" when it shows none (design.md K5).
func _slot_item(hud: RunHud, index: int) -> String:
	return StripIcon.item_shown(hud.strip.slot_view(index))


func _shows_cup(hud: RunHud) -> Callable:
	return func() -> bool: return _slot_item(hud, 0) == "rain_cup"


func test_a_client_drinks_through_the_host() -> void:
	var host := net.add_host(_island)
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var hud := _hud(client)
	var on_host := host.body(net.peer_id(client))
	on_host.meters.thirst = 50.0
	on_host.inventory.add(&"rain_cup", 1)
	assert_true(await wait_until(_shows_cup(hud), TIMEOUT_S), "the cup reached the client's strip")
	var seen_at_send: Array[String] = []
	hud.strip.use_sent.connect(func(_slot: int, _use: int, _peer: int) -> void: seen_at_send.append(_slot_item(hud, 0)))
	Input.action_press(InventoryStrip.USE_ACTION)
	var drunk := func() -> bool: return on_host.inventory.count_id(&"rain_cup") == 0
	assert_true(await wait_until(drunk, TIMEOUT_S), "the host removes the cup")
	Input.action_release(InventoryStrip.USE_ACTION)
	assert_almost_eq(on_host.meters.thirst, 75.0, 1.0, "the host sets thirst 75")
	assert_eq(seen_at_send, ["rain_cup"] as Array[String], "the client changed nothing itself when it sent")
	var emptied := func() -> bool: return _slot_item(hud, 0) == ""
	assert_true(await wait_until(emptied, TIMEOUT_S), "the client's strip shows the slot empty once the state arrives")
	assert_signal_emit_count(hud.strip, "use_sent", 1)


func test_a_client_revives_the_downed_hosts_player() -> void:
	var host := net.add_host(_island)
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var hud := _hud(client)
	var helper := host.body(net.peer_id(client))
	helper.inventory.add(&"rain_cup", 1)
	var fallen := host.body(CoopSession.HOST_ID)
	fallen.global_position = helper.global_position + HALF_TILE
	fallen.meters.solo = false
	fallen.meters.add(M.HEALTH, -fallen.meters.health)
	assert_true(fallen.meters.downed, "the host's player is down, not in a last stand")
	var seen := func() -> bool:
		var mirror := client.body(CoopSession.HOST_ID)
		return mirror != null and mirror.meters.downed and _slot_item(hud, 0) == "rain_cup" \
			and mirror.global_position.distance_to(net.own_body(client).global_position) <= InteractionPicker.REACH_PX \
			and hud.strip.item_line.text.contains(": ")
	assert_true(await wait_until(seen, TIMEOUT_S), "the client sees the host down, half a tile away, and names them")
	Input.action_press(InventoryStrip.USE_ACTION)
	var stood := func() -> bool: return not fallen.meters.downed
	assert_true(await wait_until(stood, TIMEOUT_S), "the host's player stands")
	Input.action_release(InventoryStrip.USE_ACTION)
	assert_almost_eq(fallen.meters.health, 30.0, 0.5, "at 30 health")
	assert_eq(helper.inventory.count_id(&"rain_cup"), 0, "the cup is gone")
	assert_signal_emitted_with_parameters(hud.strip, "use_sent", [0, 1, CoopSession.HOST_ID])


func test_a_forged_use_for_an_empty_slot_changes_nothing() -> void:
	var host := net.add_host(_island)
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var cid: int = net.peer_id(client)
	var on_host := host.body(cid)
	on_host.inventory.add(&"rain_cup", 1)
	on_host.meters.thirst = 50.0
	var fallen := host.body(CoopSession.HOST_ID)
	fallen.global_position = on_host.global_position + HALF_TILE
	fallen.meters.solo = false
	fallen.meters.add(M.HEALTH, -fallen.meters.health)
	var before: Array = on_host.inventory.to_net()
	client.request_use.rpc_id(CoopSession.HOST_ID, 3, 0, 0)
	client.request_use.rpc_id(CoopSession.HOST_ID, 5, 1, CoopSession.HOST_ID)
	client.request_use.rpc_id(CoopSession.HOST_ID, 99, 0, 0)
	await wait_physics_frames(20)
	assert_eq(on_host.inventory.to_net(), before, "nothing was spent")
	assert_almost_eq(on_host.meters.thirst, 50.0, 0.5, "nothing was drunk")
	assert_true(fallen.meters.downed, "nobody was stood up")


func test_a_rejoined_client_uses_its_reclaimed_bodys_cup() -> void:
	var papo := PlayerIdentity.create()
	var host := net.add_host(_island)
	var client := await net.join(_as(papo))
	assert_not_null(client)
	if client == null:
		return
	var old_id: int = net.peer_id(client)
	var papo_body := host.body(old_id)
	papo_body.inventory.add(&"rain_cup", 1)
	papo_body.meters.thirst = 50.0
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(old_id), TIMEOUT_S), "Papo's body waits")
	var back := net.add_client(_as(papo))
	var hud := _hud(back)
	var reclaimed := func() -> bool:
		var mine := net.own_body(back)
		return mine != null and hud.strip.body == mine and _slot_item(hud, 0) == "rain_cup"
	assert_true(await wait_until(reclaimed, TIMEOUT_S), "the strip follows the reclaimed body")
	Input.action_press(InventoryStrip.USE_ACTION)
	var drunk := func() -> bool: return papo_body.inventory.count_id(&"rain_cup") == 0
	assert_true(await wait_until(drunk, TIMEOUT_S), "F drank the reclaimed body's cup on the host")
	Input.action_release(InventoryStrip.USE_ACTION)
	assert_same(host.body(net.peer_id(back)), papo_body, "the same body")
	assert_gt(papo_body.meters.thirst, 70.0, "thirst went up by the cup's 25")
