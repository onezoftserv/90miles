extends GutTest
## coop-networking "Rematch is the host's call" (design D2): the host's call travels on a small
## node outside the session, the shell's child named "Rematch". Only the host sends it, only a
## client acts on it, and offline nothing is sent. Over ENet on localhost: each NetHarness branch
## gets a RunRematch named "Rematch", so the paths match.

const TIMEOUT_S: float = 5.0

var net: NetHarness


func before_each() -> void:
	NetManager.start_solo()
	net = NetHarness.new(self)


func after_each() -> void:
	net.teardown()
	NetManager.leave()


# A RunRematch named "Rematch" in `session`'s branch, and the count of its `called` signals.
func _rematch_beside(session: CoopSession) -> Array:
	var rematch := RunRematch.new()
	rematch.name = "Rematch"
	session.get_parent().add_child(rematch)
	var calls: Array[int] = [0]
	rematch.called.connect(func() -> void: calls[0] += 1)
	return [rematch, calls]


func test_offline_sends_nothing() -> void:
	var rematch := RunRematch.new()
	add_child_autofree(rematch)
	var calls: Array[int] = [0]
	rematch.called.connect(func() -> void: calls[0] += 1)
	assert_false(rematch.call_party(), "solo has no rematch")
	rematch.begin()
	assert_eq(calls[0], 0, "and acts on no call")


func test_the_host_calls_the_client() -> void:
	var host := net.add_host()
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var host_side := _rematch_beside(host)
	var client_side := _rematch_beside(client)
	await wait_physics_frames(2)
	assert_true((host_side[0] as RunRematch).call_party())
	var calls: Array[int] = client_side[1]
	assert_true(await wait_until(func() -> bool: return calls[0] > 0, TIMEOUT_S), "the client hears the call")
	await wait_physics_frames(5)
	assert_eq(calls[0], 1, "once")
	assert_eq((host_side[1] as Array[int])[0], 0, "the host does not call itself")


func test_a_call_not_from_the_host_is_ignored() -> void:
	var host := net.add_host()
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var host_side := _rematch_beside(host)
	var client_side := _rematch_beside(client)
	# A local call has no sender: not the host's.
	(client_side[0] as RunRematch).begin()
	(host_side[0] as RunRematch).begin()
	assert_eq((client_side[1] as Array[int])[0], 0, "a client acts only on the host's call")
	assert_eq((host_side[1] as Array[int])[0], 0, "the host never acts on a call")


func test_a_client_cannot_call() -> void:
	var host := net.add_host()
	var client := await net.join()
	assert_not_null(client)
	if client == null:
		return
	var host_side := _rematch_beside(host)
	var client_side := _rematch_beside(client)
	assert_false((client_side[0] as RunRematch).call_party(), "only the host calls")
	await wait_physics_frames(5)
	assert_eq((host_side[1] as Array[int])[0], 0)
	assert_eq((client_side[1] as Array[int])[0], 0)
