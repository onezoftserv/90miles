extends GutTest
## damage-feedback end to end with exactly 1 player, offline (survival-meters "Hurt cue on the
## body", "Change floats over the body"; ui-shell "Hit flash at the screen edges", "Changes show on
## the bars", "Drain glow on the health bar"; inventory-hud "Uses that would do nothing"): a solo
## session and its RunHud, the look, the meters panel and the floats stepped by hand.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const M := DataEnums.Meter
const FRAME: float = 1.0 / 60.0

var session: CoopSession
var hud: RunHud
var me: PlayerBody
var look: PlayerLook


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	HurtCues.reduce_flashes = false
	session = SESSION_SCENE.instantiate() as CoopSession
	add_child_autofree(session)
	session.start()
	me = session.body(CoopSession.HOST_ID)
	me.player_input.enabled = false
	for slot: InventorySlot in me.inventory.slots:
		slot.clear()
	hud = HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, CoopSession.HOST_ID, true)
	hud.meters.set_process(false)
	hud.floats.set_process(false)
	look = me.get_node(^"Look") as PlayerLook
	look.set_process(false)
	_frame()


func after_each() -> void:
	Input.action_release(InventoryStrip.USE_ACTION)
	WeatherManager.stop()
	NetManager.leave()


# One drawn frame of every cue.
func _frame() -> void:
	look.step(FRAME)
	hud.meters.step(FRAME)
	hud.floats.step(FRAME)


func _frames(seconds: float) -> void:
	for i: int in roundi(seconds / FRAME):
		_frame()


func _slot_of(item_id: StringName) -> int:
	for i: int in me.inventory.slots.size():
		if me.inventory.slots[i].item_id == item_id:
			return i
	return -1


func test_a_solo_crab_pinch_blinks_flashes_and_leaves_a_chunk() -> void:
	assert_eq(session.peer_ids().size(), 1, "one offline player")
	var crab := GameState.content.get_entry(&"creatures", &"land_crab") as CreatureData
	CreatureWorld.new().pinch(me, crab)
	_frame()
	assert_true(look.hurt_blink().active(), "the body blinks")
	assert_gt(hud.meters.flash_strength(), 0.0, "the screen edges flash")
	assert_eq(hud.meters.bar_for(M.HEALTH).lost_range(), Vector2(95.0, 100.0), "a 5-point chunk on Salud")
	assert_eq(hud.floats.texts_over(me), PackedStringArray(), "no number floats (owner, Q3)")


func test_solo_thirst_at_0_glows_with_no_blink_flash_or_float() -> void:
	me.meters.thirst = 0.0
	_frames(1.1)
	var flashes: int = hud.meters.flashes_started()
	var rest := MeterContext.new()
	for i: int in 180:
		me.meters.tick(FRAME, rest)
		_frame()
		assert_false(look.hurt_blink().active(), "no blink, frame %d" % i)
	assert_true(hud.meters.bar_for(M.HEALTH).glowing(), "the Salud frame glows")
	assert_eq(hud.meters.flashes_started(), flashes, "no edge flash")
	assert_eq(hud.floats.texts_over(me), PackedStringArray(), "nothing floats")


func test_solo_coconut_through_the_strip_floats_and_lights_the_bar() -> void:
	me.meters.thirst = 50.0
	me.meters.hunger = 50.0
	_frames(1.1)
	me.inventory.add(&"knife", 1)
	me.inventory.add(&"coco", 1)
	hud.strip.select(_slot_of(&"coco"))
	Input.action_press(InventoryStrip.USE_ACTION)
	for i: int in 21:
		hud.strip._process(0.1)
	Input.action_release(InventoryStrip.USE_ACTION)
	assert_eq(_slot_of(&"coco"), -1, "drunk after the 2 s hold")
	_frame()
	assert_true(hud.floats.texts_over(me).has("+15 Sed"), "floats: %s" % hud.floats.texts_over(me))
	assert_eq(hud.meters.bar_for(M.THIRST).gained_range(), Vector2(50.0, 65.0), "the Sed bar lights its gained part")


func test_solo_sabila_with_nothing_to_cure_is_refused_and_stays() -> void:
	me.inventory.add(&"aloe", 1)
	hud.strip.select(_slot_of(&"aloe"))
	Input.action_press(InventoryStrip.USE_ACTION)
	hud.strip._process(0.1)
	Input.action_release(InventoryStrip.USE_ACTION)
	assert_eq(hud.notice.shown_text(), "No hay na' que curar.")
	assert_true(_slot_of(&"aloe") >= 0, "the sábila stays")
