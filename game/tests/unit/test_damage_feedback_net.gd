extends GutTest
## damage-feedback over ENet on localhost (NetHarness): every peer reads hits, drains, jumps and cures
## from the state the host already replicates, and nothing is sent for them. A client sees its own
## hit on its screen and its body, and a teammate's hit on the teammate's body only; a host's
## coconut floats over the host on the client; a late joiner cues nothing old; a client's own
## predicted energy floats nothing; a forged wasted use changes nothing on the host. The looks, the
## HUDs and the floats run on their own frames; tests wait only for the sync.

const SPAWNS: Array[Vector2] = [Vector2(32.0, 48.0), Vector2(48.0, 48.0), Vector2(64.0, 48.0), Vector2(80.0, 48.0)]
const TIMEOUT_S: float = 5.0
const METERS_HUD: PackedScene = preload("res://scenes/ui/meters_hud.tscn")

var net: NetHarness


func before_each() -> void:
	net = NetHarness.new(self)
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	HurtCues.reduce_flashes = false


func after_each() -> void:
	net.teardown()


func _setup(session: CoopSession) -> void:
	session.spawn_points = SPAWNS.duplicate()


func _hud_on(meters: SurvivalMeters) -> MetersHud:
	var hud := METERS_HUD.instantiate() as MetersHud
	add_child_autofree(hud)
	hud.bind(meters)
	return hud


func _floats_on(session: CoopSession) -> ChangeFloats:
	var floats := ChangeFloats.new()
	add_child_autofree(floats)
	floats.bind(session)
	return floats


func _look(body: PlayerBody) -> PlayerLook:
	return body.get_node(^"Look") as PlayerLook


func _pair() -> Array[CoopSession]:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	assert_not_null(client)
	if client == null:
		return []
	assert_true(await net.settle())
	net.silence_input()
	return [host, client]


func test_a_late_joiner_cues_nothing_old() -> void:
	var host := net.add_host(_setup)
	host.body(CoopSession.HOST_ID).meters.harm(40.0, &"reef_shark")
	await wait_physics_frames(30)
	var late := await net.join(_setup)
	assert_not_null(late)
	if late == null:
		return
	assert_true(await net.settle())
	var yuni := late.body(CoopSession.HOST_ID)
	var seen := func() -> bool: return yuni.meters.health < 61.0
	assert_true(await wait_until(seen, TIMEOUT_S), "the late joiner has the host at 60")
	var hud := _hud_on(yuni.meters)
	var floats := _floats_on(late)
	await wait_process_frames(10)
	assert_eq(_look(yuni).hurt_blink().starts, 0, "no old hit ever blinked on the late joiner")
	assert_eq(hud.flashes_started(), 0, "nor flashes")
	assert_eq(floats.texts_over(yuni), PackedStringArray(), "nor floats")


func test_a_client_sees_its_own_hit_and_the_host_does_not_flash() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var client_id: int = net.peer_id(client)
	var own := net.own_body(client)
	var client_hud := _hud_on(own.meters)
	var host_hud := _hud_on(host.body(CoopSession.HOST_ID).meters)
	await wait_process_frames(5)
	host.body(client_id).meters.harm(5.0, &"land_crab")
	var hit := func() -> bool: return own.meters.health < 100.0
	assert_true(await wait_until(hit, TIMEOUT_S), "the pinch reaches the client")
	await wait_process_frames(2)
	assert_eq(client_hud.flashes_started(), 1, "the client's screen edges flash")
	assert_true(_look(own).hurt_blink().active(), "the client's own body blinks there")
	assert_true(_look(host.body(client_id)).hurt_blink().active(), "and on the host's screen")
	assert_eq(host_hud.flashes_started(), 0, "the host's own screen does not flash")


func test_a_teammates_hit_shows_on_their_body_only() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var own := net.own_body(client)
	var yuni := client.body(CoopSession.HOST_ID)
	var client_hud := _hud_on(own.meters)
	var floats := _floats_on(client)
	await wait_process_frames(5)
	host.body(CoopSession.HOST_ID).meters.harm(5.0, &"land_crab")
	var hit := func() -> bool: return yuni.meters.health < 100.0
	assert_true(await wait_until(hit, TIMEOUT_S))
	await wait_process_frames(2)
	assert_true(_look(yuni).hurt_blink().active(), "Yuni's body blinks on the client")
	assert_eq(client_hud.flashes_started(), 0, "the client's screen does not flash for a teammate")
	assert_eq(floats.texts_over(yuni), PackedStringArray(), "and no number floats")


func test_the_hosts_coconut_floats_over_the_host_on_the_client() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var yuni_on_host := host.body(CoopSession.HOST_ID)
	yuni_on_host.meters.thirst = 50.0
	yuni_on_host.meters.hunger = 50.0
	var yuni := client.body(CoopSession.HOST_ID)
	var floats := _floats_on(client)
	await wait_seconds(1.2)
	for slot: InventorySlot in yuni_on_host.inventory.slots:
		slot.clear()
	yuni_on_host.inventory.add(&"knife", 1)
	yuni_on_host.inventory.add(&"coco", 1)
	var coco: int = -1
	for i: int in yuni_on_host.inventory.slots.size():
		if yuni_on_host.inventory.slots[i].item_id == &"coco":
			coco = i
	assert_true(host.use_for(CoopSession.HOST_ID, coco, 0, 0))
	var floated := func() -> bool: return floats.texts_over(yuni).has("+15 Sed")
	assert_true(await wait_until(floated, TIMEOUT_S), "'+15 Sed' floats over Yuni on the client: %s" % floats.texts_over(yuni))


func test_a_walking_clients_own_energy_floats_nothing() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var client := pair[1]
	var own := net.own_body(client)
	var floats := _floats_on(client)
	await wait_process_frames(5)
	var words: PackedStringArray = []
	own.intent = MoveIntent.create(Vector2.RIGHT, true)
	for i: int in 90:
		await wait_physics_frames(1)
		for text: String in floats.texts_over(own):
			if not words.has(text):
				words.append(text)
	own.intent = MoveIntent.create()
	assert_lt(own.meters.energy, 100.0, "running spent energy")
	assert_eq(words, PackedStringArray(), "prediction and reconciliation float nothing")


func test_a_forged_wasted_use_changes_nothing_on_the_host() -> void:
	var pair := await _pair()
	if pair.is_empty():
		return
	var host := pair[0]
	var client := pair[1]
	var client_id: int = net.peer_id(client)
	var papo := host.body(client_id)
	for slot: InventorySlot in papo.inventory.slots:
		slot.clear()
	papo.inventory.add(&"knife", 1)
	papo.inventory.add(&"coco", 1)
	var before: Array = papo.inventory.to_net()
	var own := net.own_body(client)
	var synced := func() -> bool: return own.inventory.count_id(&"coco") == 1
	assert_true(await wait_until(synced, TIMEOUT_S))
	# Full, as a living player is: the host's ticks have already drained a hair off.
	for meter: DataEnums.Meter in [DataEnums.Meter.THIRST, DataEnums.Meter.HUNGER, DataEnums.Meter.ENERGY]:
		papo.meters.set_value(meter, 100.0)
	client.use_item(1, 0, 0)
	await wait_seconds(0.5)
	assert_eq(papo.inventory.to_net(), before, "the coconut and the knife's uses stay")
	assert_gt(papo.meters.thirst, 99.0, "no drink landed")
