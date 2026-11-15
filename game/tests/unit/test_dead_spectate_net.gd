extends GutTest
## ui-shell "Spectating on every peer" over ENet on localhost (NetHarness), with a run HUD bound on
## each branch: a client who dies watches the host and the host who dies watches a client; a player
## who takes back a body that died while they were away watches at once; a late joiner who dies
## watches with the roster's names; a disconnected teammate watched because nobody connected is
## left is marked until he is back; and the dead still speak through quick chat. Nothing of this
## is sent: each HUD works it out from the bodies its own session holds. Every branch shares one
## viewport here, so the tests read the watched body and the cameras' `enabled`, never which camera
## is current.

const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const TIMEOUT_S: float = 5.0
const KEYS: String = "  [A] [D] Cambiar"

var net: NetHarness
var papo: PlayerIdentity
# Freed before the sessions they read.
var huds: Array[Node] = []


func before_each() -> void:
	net = NetHarness.new(self)
	papo = PlayerIdentity.create()


func after_each() -> void:
	for hud: Node in huds:
		if is_instance_valid(hud):
			hud.free()
	huds.clear()
	net.teardown()


func _as(identity: PlayerIdentity, player_name: String) -> Callable:
	return func(session: CoopSession) -> void:
		session.spawn_points = SPAWNS.duplicate()
		session.local_identity = identity
		session.local_name = player_name


func _host() -> CoopSession:
	return net.add_host(_as(PlayerIdentity.create(), "Yuni"))


func _hud(session: CoopSession) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	huds.append(hud)
	hud.bind(session, net.peer_id(session), false)
	return hud


func _line(hud: RunHud) -> String:
	hud.refresh()
	return hud.watching_label.text if hud.watching_panel.visible else ""


# Waits until `hud`'s line reads `expected`; the failure message shows what it read.
func _assert_line(hud: RunHud, expected: String, what: String) -> void:
	var reads := func() -> bool: return _line(hud) == expected
	assert_true(await wait_until(reads, TIMEOUT_S), "%s: '%s'" % [what, _line(hud)])


# The host and Papo, every body on both peers. Returns [host, papo] (papo null on a failed join).
func _pair() -> Array[CoopSession]:
	var host := _host()
	var client := await net.join(_as(papo, "Papo"))
	assert_not_null(client)
	assert_true(await net.settle())
	net.silence_input()
	return [host, client] as Array[CoopSession]


func test_a_client_watches_the_host() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	if client == null:
		return
	var papo_id: int = net.peer_id(client)
	var host_hud := _hud(host)
	var papo_hud := _hud(client)
	host.body(papo_id).meters.dead = true
	await _assert_line(papo_hud, "Mirando a: Yuni" + KEYS, "Papo's line")
	assert_same(papo_hud.spectate.watched(), client.body(CoopSession.HOST_ID), "Papo's view follows Yuni's body")
	assert_true(client.body(CoopSession.HOST_ID).camera.enabled, "Yuni's camera on Papo's peer is on")
	assert_false(client.body(papo_id).camera.enabled, "Papo's own camera is off")
	assert_same(papo_hud.meters.shown(), client.body(CoopSession.HOST_ID).meters, "Papo's panel shows Yuni's meters")
	host_hud.refresh()
	assert_false(host_hud.spectate.active(), "the living host watches nobody")
	assert_true(host.body(CoopSession.HOST_ID).camera.enabled, "Yuni's view stays on Yuni")
	assert_false(host.body(papo_id).camera.enabled)


func test_the_host_watches_a_client() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	if client == null:
		return
	var papo_id: int = net.peer_id(client)
	var host_hud := _hud(host)
	host.body(CoopSession.HOST_ID).meters.dead = true
	await _assert_line(host_hud, "Mirando a: Papo" + KEYS, "Yuni's line")
	assert_same(host_hud.spectate.watched(), host.body(papo_id))
	assert_true(host.body(papo_id).camera.enabled)
	assert_false(host.body(CoopSession.HOST_ID).camera.enabled)


func test_the_dead_still_speak() -> void:
	var pair := await _pair()
	var host := pair[0]
	var client := pair[1]
	if client == null:
		return
	var papo_id: int = net.peer_id(client)
	var papo_hud := _hud(client)
	host.body(papo_id).meters.dead = true
	await _assert_line(papo_hud, "Mirando a: Yuni" + KEYS, "Papo watches")
	var heard: Array[int] = []
	host.quick_chat_shown.connect(func(peer_id: int, _slot: int) -> void: heard.append(peer_id))
	client.say(0)
	assert_true(await wait_until(func() -> bool: return heard.has(papo_id), TIMEOUT_S), "the host shows the dead Papo's phrase")


func test_back_to_a_body_that_died_while_away() -> void:
	var host := _host()
	var dayana := await net.join(_as(PlayerIdentity.create(), "Dayana"))
	var client := await net.join(_as(papo, "Papo"))
	assert_not_null(dayana)
	assert_not_null(client)
	if dayana == null or client == null:
		return
	assert_true(await net.settle())
	var papo_id: int = net.peer_id(client)
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(papo_id), TIMEOUT_S))
	var dead_body := host.body(papo_id)
	dead_body.meters.dead = true
	var back := await net.join(_as(papo, "Papo"))
	assert_not_null(back, "Papo joins again within his 90 s")
	if back == null:
		return
	var new_id: int = net.peer_id(back)
	assert_same(host.body(new_id), dead_body, "the same dead body is his again")
	assert_true(await wait_until(func() -> bool: return back.body(new_id) != null and back.body(new_id).meters.dead, TIMEOUT_S), "his body is dead on his peer")
	var hud := _hud(back)
	var watching := func() -> bool:
		hud.refresh()
		return hud.spectate.active()
	assert_true(await wait_until(watching, TIMEOUT_S), "he watches as soon as he is back")
	var watched := hud.spectate.watched()
	assert_not_null(watched)
	if watched == null:
		return
	assert_false(watched.meters.dead, "he watches a living teammate")
	assert_ne(watched, back.body(new_id))
	assert_true(watched.camera.enabled)
	assert_false(back.body(new_id).camera.enabled, "not his own dead body")


func test_a_late_joiner_who_dies_watches_the_nearer_teammate() -> void:
	# Yuni spawns at (32, 48), Papo at (48, 48), the late Dayana at (64, 48): Papo is nearer.
	var pair := await _pair()
	var host := pair[0]
	if pair[1] == null:
		return
	var dayana := await net.join(_as(PlayerIdentity.create(), "Dayana"))
	assert_not_null(dayana)
	if dayana == null:
		return
	assert_true(await net.settle())
	net.silence_input()
	var dayana_id: int = net.peer_id(dayana)
	var dayana_hud := _hud(dayana)
	host.body(dayana_id).meters.dead = true
	await _assert_line(dayana_hud, "Mirando a: Papo" + KEYS, "Dayana's line")
	dayana_hud._input(_key(KEY_D))
	await _assert_line(dayana_hud, "Mirando a: Yuni" + KEYS, "D steps to Yuni, wrapping round")


func test_a_disconnected_teammate_left_alone_is_marked_until_back() -> void:
	var host := _host()
	var dayana := await net.join(_as(PlayerIdentity.create(), "Dayana"))
	var client := await net.join(_as(papo, "Papo"))
	if dayana == null or client == null:
		assert_not_null(dayana)
		assert_not_null(client)
		return
	assert_true(await net.settle())
	net.silence_input()
	var papo_id: int = net.peer_id(client)
	var dayana_hud := _hud(dayana)
	net.drop(client)
	assert_true(await wait_until(func() -> bool: return host.is_dropped(papo_id), TIMEOUT_S))
	host.body(CoopSession.HOST_ID).meters.dead = true
	host.body(net.peer_id(dayana)).meters.dead = true
	await _assert_line(dayana_hud, "Mirando a: Papo (desconectado)" + KEYS, "only the disconnected Papo is left")
	var back := await net.join(_as(papo, "Papo"))
	assert_not_null(back)
	if back == null:
		return
	await _assert_line(dayana_hud, "Mirando a: Papo" + KEYS, "the mark goes when Papo is back")


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = true
	return event
