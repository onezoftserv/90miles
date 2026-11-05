extends GutTest
## coop-networking "Disconnect handling" over ENet on localhost (NetHarness): a client that
## drops leaves its player downed for 90 s, then removed everywhere; a host that drops ends
## the session with the "host lost" screen.

const TILE: float = 16.0
const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0)]
const TIMEOUT_S: float = 5.0
const HOST_LOST_SCENE: PackedScene = preload("res://scenes/ui/host_lost_screen.tscn")

var net: NetHarness
var left_at_disconnect: float = -1.0


func before_each() -> void:
	net = NetHarness.new(self)
	left_at_disconnect = -1.0


func after_each() -> void:
	net.teardown()


func _island(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()


func test_downed_time_is_90_s() -> void:
	assert_eq(CoopSession.DISCONNECT_DOWNED_S, 90.0)


func test_client_drops() -> void:
	var host := net.add_host(_island)
	var a := await net.join()
	var b := await net.join()
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	assert_true(await net.settle())
	var a_id: int = net.peer_id(a)
	host.player_disconnected.connect(func(id: int) -> void: left_at_disconnect = host.disconnect_time_left(id))
	watch_signals(host)
	net.drop(a)
	var downed_on_host := func() -> bool: return host.body(a_id) != null and host.body(a_id).downed
	assert_true(await wait_until(downed_on_host, TIMEOUT_S), "the dropped player is downed on the host")
	assert_eq(left_at_disconnect, 90.0, "the countdown starts at 90 s")
	var downed_on_b := func() -> bool: return b.body(a_id) != null and b.body(a_id).downed
	assert_true(await wait_until(downed_on_b, TIMEOUT_S), "and teammates see it downed")
	var last: Vector2 = host.body(a_id).position
	host._physics_process(host.disconnect_time_left(a_id) - 0.1)
	assert_not_null(host.body(a_id), "still in the world 0.1 s before the end")
	assert_signal_not_emitted(host, "player_removed")
	host._physics_process(0.2)
	assert_null(host.body(a_id), "removed after 90 s")
	assert_signal_emitted_with_parameters(host, "player_removed", [a_id, last])
	assert_true(await wait_until(func() -> bool: return b.body(a_id) == null, TIMEOUT_S), "removed on every peer")
	var remaining: Array[int] = [1, net.peer_id(b)]
	remaining.sort()
	assert_eq(host.peer_ids(), remaining)


func test_a_dropped_players_countdown_does_not_touch_the_others() -> void:
	var host := net.add_host(_island)
	var a := await net.join()
	var b := await net.join()
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	var b_id: int = net.peer_id(b)
	net.drop(a)
	assert_true(await wait_until(func() -> bool: return host.peer_ids().size() == 3 and host.disconnect_time_left(net.peer_id(a)) > 0.0, TIMEOUT_S))
	host._physics_process(91.0)
	assert_not_null(host.body(b_id))
	assert_false(host.body(b_id).downed)
	assert_not_null(host.body(1))
	assert_eq(host.disconnect_time_left(b_id), 0.0)


func test_host_drops() -> void:
	var host := net.add_host(_island)
	var a := await net.join()
	assert_not_null(a)
	if a == null:
		return
	watch_signals(a)
	net.drop(host)
	assert_true(await wait_until(func() -> bool: return a.peer_ids().is_empty(), TIMEOUT_S), "the client's session ends")
	assert_signal_emitted(a, "host_lost")
	await wait_frames(2)
	assert_eq(a.players.get_child_count(), 0, "its players are gone")


func test_net_manager_reports_a_lost_host_and_goes_offline() -> void:
	watch_signals(NetManager)
	NetManager.host(0)
	NetManager._on_server_disconnected()
	assert_signal_emitted(NetManager, "host_lost")
	assert_false(NetManager.is_online())


# --- the host-lost screen ----------------------------------------------------------------

func test_host_lost_screen_says_so_in_spanish() -> void:
	var screen := HOST_LOST_SCENE.instantiate() as HostLostScreen
	add_child_autofree(screen)
	assert_eq(screen.message.text, "Se perdió la conexión con el anfitrión.")
	assert_eq(screen.back_button.text, "Volver")


func test_host_lost_screen_back_button_asks_to_go_back() -> void:
	var screen := HOST_LOST_SCENE.instantiate() as HostLostScreen
	add_child_autofree(screen)
	watch_signals(screen)
	screen.back_button.pressed.emit()
	assert_signal_emitted(screen, "back_requested")
