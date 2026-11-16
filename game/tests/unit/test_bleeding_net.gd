extends GutTest
## bleeding-and-sabila over ENet on localhost (NetHarness): the host keeps bleeding's time and only
## the synced bit reaches the peers, so a client sees its bleeding start and end, and a late joiner
## sees an ongoing bleed. Sábila treats a teammate within reach either way, the host's player
## treating the client's or the client's intent treating the host's, and a client's use aimed at a
## teammate out of reach changes nothing. The host body's bleeding is shortened to 1 s here so the
## end is seen in real time; the 120 s itself is tested on plain meters (test_bleeding).

const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const TIMEOUT_S: float = 5.0
const BLEEDING := DataEnums.Status.BLEEDING

var net: NetHarness


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	net.teardown()


func _setup(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()


func _pair() -> Array[CoopSession]:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return []
	assert_true(await net.settle())
	net.silence_input()
	return [host, client]


func _shark() -> CreatureData:
	return GameState.content.get_entry(&"creatures", &"reef_shark") as CreatureData


# `meters`' bleeding lasts `seconds` instead of the shipped 120 s.
func _short_bleed(meters: SurvivalMeters, seconds: float) -> void:
	var tuning := meters.tuning.duplicate() as SurvivalTuning
	tuning.bleeding_s = seconds
	meters.tuning = tuning


func _slot_of(body: PlayerBody, item_id: StringName) -> int:
	for i: int in body.inventory.slots.size():
		if body.inventory.slots[i].item_id == item_id:
			return i
	return -1


func test_a_client_sees_its_bleeding_start_and_end() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var on_host := host.body(net.peer_id(client))
	var own := net.own_body(client)
	_short_bleed(on_host.meters, 1.0)
	CreatureWorld.new().strike(on_host, _shark())
	var bleeds := func() -> bool: return own.meters.has_status(BLEEDING)
	assert_true(await wait_until(bleeds, TIMEOUT_S), "the client knows it bleeds")
	assert_eq(own.meters.status_time_left(BLEEDING), 0.0, "the time stays on the host")
	var stopped := func() -> bool: return not own.meters.has_status(BLEEDING)
	assert_true(await wait_until(stopped, TIMEOUT_S), "and that it stopped, when the host's time ran out")
	assert_false(on_host.meters.has_status(BLEEDING))
	assert_lt(on_host.meters.health, 75.0, "the drain ran on the host")
	var drained := func() -> bool: return own.meters.health < 75.0
	assert_true(await wait_until(drained, TIMEOUT_S), "and the client's health shows it")


func test_nothing_new_is_synced_for_the_time() -> void:
	var host := net.add_host(_setup)
	var body := host.body(CoopSession.HOST_ID)
	var sync := body.get_node(^"StateSync") as MultiplayerSynchronizer
	if sync == null:
		for child: Node in body.get_children():
			if child is MultiplayerSynchronizer:
				sync = child as MultiplayerSynchronizer
	assert_not_null(sync)
	if sync == null:
		return
	var paths := PackedStringArray()
	for path: NodePath in sync.replication_config.get_properties():
		paths.append(String(path))
	assert_true(paths.has("SurvivalMeters:status_flags"), "the bit is synced")
	for path: String in paths:
		assert_false(path.contains("status_left") or path.contains("status_time"), "%s is not the time" % path)


func test_a_late_joiner_sees_an_ongoing_bleed() -> void:
	var host := net.add_host(_setup)
	host.body(CoopSession.HOST_ID).meters.set_status(BLEEDING, true)
	await wait_physics_frames(10)
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	assert_true(await net.settle())
	var yuni := late.body(CoopSession.HOST_ID)
	var bleeds := func() -> bool: return yuni.meters.has_status(BLEEDING)
	assert_true(await wait_until(bleeds, TIMEOUT_S), "the late joiner sees the host bleed")


func test_the_hosts_player_treats_the_clients_bleeding_player() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var client_id: int = net.peer_id(client)
	var me := host.body(CoopSession.HOST_ID)
	var patient := host.body(client_id)
	patient.global_position = me.global_position + Vector2(8.0, 0.0)
	patient.meters.health = 60.0
	patient.meters.set_status(BLEEDING, true)
	me.inventory.add(&"aloe", 1)
	var slot: int = _slot_of(me, &"aloe")
	var plan := UsePlan.choose(me, slot, host)
	assert_same(plan.target, patient, "the plan aims at the bleeding client")
	assert_true(host.use_for(CoopSession.HOST_ID, slot, plan.use_index, plan.target_peer))
	var own := net.own_body(client)
	var treated := func() -> bool: return not own.meters.has_status(BLEEDING) and own.meters.health >= 64.9
	assert_true(await wait_until(treated, TIMEOUT_S), "the client sees its bleeding stop and +5")
	assert_eq(me.meters.health, 100.0, "the host's own health is unchanged")
	assert_eq(_slot_of(me, &"aloe"), -1, "the leaf is gone")


func test_the_clients_intent_treats_the_hosts_bleeding_player() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var client_id: int = net.peer_id(client)
	var yuni := host.body(CoopSession.HOST_ID)
	var helper := host.body(client_id)
	yuni.global_position = helper.global_position + Vector2(8.0, 0.0)
	yuni.meters.health = 50.0
	yuni.meters.set_status(BLEEDING, true)
	helper.inventory.add(&"aloe", 1)
	var own := net.own_body(client)
	var seen := func() -> bool:
		return _slot_of(own, &"aloe") >= 0 and client.body(CoopSession.HOST_ID).meters.has_status(BLEEDING) \
			and own.global_position.distance_to(client.body(CoopSession.HOST_ID).global_position) <= 16.0
	assert_true(await wait_until(seen, TIMEOUT_S), "the client has the leaf and sees Yuni bleed beside it")
	var plan := UsePlan.choose(own, _slot_of(own, &"aloe"), client)
	assert_eq(plan.target_peer, CoopSession.HOST_ID, "the client's plan aims at the host's player")
	client.use_item(_slot_of(own, &"aloe"), plan.use_index, plan.target_peer)
	var treated := func() -> bool: return not yuni.meters.has_status(BLEEDING)
	assert_true(await wait_until(treated, TIMEOUT_S), "the host applies it")
	assert_almost_eq(yuni.meters.health, 55.0, 0.5, "+5, less the little bled before the leaf landed")
	assert_eq(_slot_of(helper, &"aloe"), -1, "the client's leaf is gone on the host")


func test_a_clients_use_on_a_far_teammate_changes_nothing() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var client_id: int = net.peer_id(client)
	var yuni := host.body(CoopSession.HOST_ID)
	var helper := host.body(client_id)
	yuni.global_position = helper.global_position + Vector2(48.0, 0.0)
	yuni.meters.set_status(BLEEDING, true)
	helper.inventory.add(&"aloe", 1)
	var own := net.own_body(client)
	var has_leaf := func() -> bool: return _slot_of(own, &"aloe") >= 0
	assert_true(await wait_until(has_leaf, TIMEOUT_S))
	client.use_item(_slot_of(own, &"aloe"), 0, CoopSession.HOST_ID)
	await wait_physics_frames(20)
	assert_true(yuni.meters.has_status(BLEEDING), "3 tiles away: refused on the host")
	assert_eq(_slot_of(helper, &"aloe") >= 0, true, "the leaf stays")
