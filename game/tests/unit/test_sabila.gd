extends GutTest
## crafting-inventory "Coast cay items as data" and "Sábila on a teammate" (bleeding-and-sabila
## design D4): sábila stops bleeding (and the dormant sunburn) and heals 5 at once, on the user or a
## teammate within reach. It is refused, spending nothing, only when its subject neither bleeds nor
## is hurt (damage-feedback's rule). The solo cases are 1 player, offline.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const R := ItemUser.Reason
const ST := DataEnums.Status
const HERE: Vector2 = Vector2(100.0, 100.0)
const PAPO: int = 7

var session: CoopSession
var me: PlayerBody
var words: HudText


func before_each() -> void:
	NetManager.start_solo()
	words = HudText.load_default()


func after_each() -> void:
	NetManager.leave()


func _start(extra: Array[int] = []) -> void:
	session = SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	for peer_id: int in extra:
		session._add_player(peer_id)
		session.roster[peer_id] = "Papo"
	for peer_id: int in session.peer_ids():
		session.body(peer_id).player_input.enabled = false
	me = session.body(CoopSession.HOST_ID)
	me.global_position = HERE
	for slot: InventorySlot in me.inventory.slots:
		slot.clear()
	me.inventory.add(&"aloe", 1)


func _aloe_slot() -> int:
	for i: int in me.inventory.slots.size():
		if me.inventory.slots[i].item_id == &"aloe":
			return i
	return -1


func _sabila() -> ItemUseData:
	return (GameState.content.get_entry(&"items", &"aloe") as ItemData).uses[0]


func test_solo_sabila_stops_bleeding_and_sunburn_and_heals_5() -> void:
	_start()
	me.meters.health = 70.0
	me.meters.set_status(ST.SUNBURN, true)
	me.meters.set_status(ST.BLEEDING, true)
	assert_true(session.use_for(CoopSession.HOST_ID, _aloe_slot(), 0, 0))
	assert_false(me.meters.has_status(ST.BLEEDING))
	assert_false(me.meters.has_status(ST.SUNBURN))
	assert_eq(me.meters.health, 75.0)
	assert_eq(_aloe_slot(), -1, "the leaf is used up")
	assert_eq(me.meters.status_time_left(ST.BLEEDING), 0.0, "and the bleeding's time with it")


func test_solo_sabila_heals_without_a_wound() -> void:
	_start()
	me.meters.health = 90.0
	assert_true(session.use_for(CoopSession.HOST_ID, _aloe_slot(), 0, 0))
	assert_eq(me.meters.health, 95.0)
	assert_eq(_aloe_slot(), -1)


func test_solo_sabila_at_full_health_with_nothing_to_treat_is_refused() -> void:
	_start()
	assert_eq(ItemUser.check(me, _aloe_slot(), 0), R.NOTHING_TO_DO)
	assert_false(session.use_for(CoopSession.HOST_ID, _aloe_slot(), 0, 0))
	assert_eq(_aloe_slot() >= 0, true, "the sábila stays")
	assert_eq(InventoryStrip.wasted_line(_sabila(), me, null, "", words), "'Tás entero.", "the heal names the reason")


func test_solo_bleeding_at_full_health_still_takes_it() -> void:
	_start()
	me.meters.set_status(ST.BLEEDING, true)
	assert_eq(ItemUser.check(me, _aloe_slot(), 0), R.OK)
	assert_true(session.use_for(CoopSession.HOST_ID, _aloe_slot(), 0, 0))
	assert_false(me.meters.has_status(ST.BLEEDING))
	assert_eq(me.meters.health, 100.0)


func test_sabila_on_a_teammate_within_reach_treats_them_only() -> void:
	_start([PAPO] as Array[int])
	var papo := session.body(PAPO)
	papo.global_position = HERE + Vector2(8.0, 0.0)
	papo.meters.health = 60.0
	papo.meters.set_status(ST.BLEEDING, true)
	me.meters.health = 80.0
	assert_true(session.use_for(CoopSession.HOST_ID, _aloe_slot(), 0, PAPO))
	assert_false(papo.meters.has_status(ST.BLEEDING))
	assert_eq(papo.meters.health, 65.0)
	assert_eq(me.meters.health, 80.0, "the user's own meters do not change")
	assert_eq(_aloe_slot(), -1, "the leaf is gone")


func test_sabila_on_a_teammate_out_of_reach_is_refused() -> void:
	_start([PAPO] as Array[int])
	var papo := session.body(PAPO)
	papo.global_position = HERE + Vector2(48.0, 0.0)
	papo.meters.set_status(ST.BLEEDING, true)
	assert_false(session.use_for(CoopSession.HOST_ID, _aloe_slot(), 0, PAPO))
	assert_true(papo.meters.has_status(ST.BLEEDING))
	assert_eq(_aloe_slot() >= 0, true, "the leaf stays")


func test_sabila_on_a_teammate_with_nothing_to_treat_is_refused() -> void:
	_start([PAPO] as Array[int])
	var papo := session.body(PAPO)
	papo.global_position = HERE + Vector2(8.0, 0.0)
	me.meters.health = 50.0
	assert_false(session.use_for(CoopSession.HOST_ID, _aloe_slot(), 0, PAPO))
	assert_eq(me.meters.health, 50.0)
	assert_eq(_aloe_slot() >= 0, true)
	assert_eq(InventoryStrip.wasted_line(_sabila(), me, papo, "Papo", words), "A Papo no le hace falta.")


func test_the_effect_line_reads_the_cures_then_the_heal() -> void:
	_start()
	me.meters.health = 90.0
	assert_eq(EffectLine.text(_sabila(), me, null, words), "Cura quemadura y sangrado · Salud +5")
	me.meters.health = 98.0
	assert_eq(EffectLine.text(_sabila(), me, null, words), "Cura quemadura y sangrado · Salud +5 (+2 útil)")
