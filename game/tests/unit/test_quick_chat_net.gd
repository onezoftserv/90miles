extends GutTest
## coop-networking "Quick chat" over ENet on localhost (NetHarness): a phrase goes through the
## host to every player; only the host may show one.

const SHARK: int = 3
const TIMEOUT_S: float = 5.0

var net: NetHarness


func before_each() -> void:
	net = NetHarness.new(self)


func after_each() -> void:
	net.teardown()


func _bubble_text(session: CoopSession, peer_id: int) -> String:
	var speaker := session.body(peer_id)
	if speaker == null:
		return ""
	var bubble := speaker.get_node_or_null(^"SpeechBubble") as SpeechBubble
	return bubble.label.text if bubble != null else ""


func test_shark_warning() -> void:
	var host := net.add_host()
	var a := await net.join()
	var b := await net.join()
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	assert_true(await net.settle())
	var a_id: int = net.peer_id(a)
	a.say(SHARK)
	var everyone_sees_it := func() -> bool:
		return _bubble_text(host, a_id) == "¡Tiburón!" and _bubble_text(a, a_id) == "¡Tiburón!" \
			and _bubble_text(b, a_id) == "¡Tiburón!"
	assert_true(await wait_until(everyone_sees_it, TIMEOUT_S), "a ¡Tiburón! bubble over A on every peer")
	assert_eq(_bubble_text(b, net.peer_id(b)), "", "not over anyone else")


func test_client_forges_a_quick_chat_bubble() -> void:
	var host := net.add_host()
	var a := await net.join()
	var b := await net.join()
	assert_not_null(a)
	assert_not_null(b)
	if a == null or b == null:
		return
	assert_true(await net.settle())
	var b_id: int = net.peer_id(b)
	a.show_quick_chat.rpc(b_id, SHARK)
	await wait_seconds(0.3)
	for session: CoopSession in [host, a, b]:
		assert_eq(_bubble_text(session, b_id), "", "no bubble on any peer")
	assert_engine_error("not allowed", "the host's engine refuses a non-authority call")
