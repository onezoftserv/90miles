extends GutTest
## survival-meters "Change floats over the body" (damage-feedback design D9), with exactly 1 player,
## offline: a solo session and its RunHud, the floats stepped by hand. A meter that jumps at once
## floats its signed change in the meter's colour from just above the head, rising 12 px over 1 s;
## a cure floats "Sin" and the status; a new float pushes the older ones up 9 px; a hit (owner, Q3)
## and a drain float nothing.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const M := DataEnums.Meter
const FRAME: float = 1.0 / 60.0

var session: CoopSession
var hud: RunHud
var me: PlayerBody
var floats: ChangeFloats
var tuning: HurtCueTuning


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	session = SESSION_SCENE.instantiate() as CoopSession
	session.spawn_points = [Vector2(120.0, 120.0)] as Array[Vector2]
	add_child_autofree(session)
	session.start()
	me = session.body(CoopSession.HOST_ID)
	me.player_input.enabled = false
	for slot: InventorySlot in me.inventory.slots:
		slot.clear()
	hud = HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, CoopSession.HOST_ID, true)
	floats = hud.floats
	floats.set_process(false)
	tuning = HurtCues.tuning()
	floats.step(FRAME)


func after_each() -> void:
	WeatherManager.stop()
	NetManager.leave()


func _slot_of(item_id: StringName) -> int:
	for i: int in me.inventory.slots.size():
		if me.inventory.slots[i].item_id == item_id:
			return i
	return -1


func _drink_coconut() -> void:
	me.inventory.add(&"knife", 1)
	me.inventory.add(&"coco", 1)
	assert_true(session.use_for(CoopSession.HOST_ID, _slot_of(&"coco"), 0, 0), "the coconut is drunk")


func _steps(seconds: float) -> void:
	for i: int in roundi(seconds / FRAME):
		floats.step(FRAME)


func test_a_solo_coconut_floats_two_lines_in_their_colours() -> void:
	me.meters.thirst = 50.0
	me.meters.hunger = 50.0
	floats.step(FRAME)
	_steps(1.1)
	_drink_coconut()
	floats.step(FRAME)
	assert_eq(floats.texts_over(me), PackedStringArray(["+15 Sed", "+5 Hambre"]), "energy was full, so the meal's energy floats nothing")
	assert_eq(floats.color_of(me, "+15 Sed"), tuning.meter_colors[M.THIRST], "Sed's blue")
	assert_eq(floats.color_of(me, "+5 Hambre"), tuning.meter_colors[M.HUNGER])


func test_floats_sit_above_the_head_stack_rise_and_go() -> void:
	me.meters.thirst = 50.0
	me.meters.hunger = 50.0
	floats.step(FRAME)
	_steps(1.1)
	_drink_coconut()
	floats.step(FRAME)
	var thirst: Rect2 = floats.rect_of(me, "+15 Sed")
	var hunger: Rect2 = floats.rect_of(me, "+5 Hambre")
	var canvas: Transform2D = me.get_global_transform_with_canvas()
	var head_y: float = (hud.world_to_hud(canvas * Vector2(0.0, (me.get_node(^"BodyLook") as BodyLook).head_y()))).y
	assert_lt(hunger.end.y, head_y, "just above the head")
	assert_almost_eq(hunger.position.y - thirst.position.y, tuning.float_stack_px, 0.01, "the newer float pushed the older one up")
	_steps(0.5)
	assert_almost_eq(thirst.position.y - floats.rect_of(me, "+15 Sed").position.y, tuning.float_rise_px / 2.0, 1.0, "risen 6 px after 0.5 s")
	_steps(0.5)
	assert_eq(floats.texts_over(me), PackedStringArray(), "gone 1 s later")


func test_a_full_meter_floats_what_fit() -> void:
	me.meters.thirst = 94.0
	floats.step(FRAME)
	_steps(1.1)
	_drink_coconut()
	floats.step(FRAME)
	assert_true(floats.texts_over(me).has("+6 Sed"), "only 6 fit: %s" % floats.texts_over(me))


func test_a_hit_floats_no_number() -> void:
	me.meters.harm(25.0, &"reef_shark")
	floats.step(FRAME)
	assert_eq(floats.texts_over(me), PackedStringArray(), "owner Q3: the blink, the edges and the chunk show it")


func test_a_cure_floats_its_status() -> void:
	me.meters.set_status(DataEnums.Status.BLEEDING, true)
	floats.step(FRAME)
	_steps(0.2)
	me.meters.set_status(DataEnums.Status.BLEEDING, false)
	floats.step(FRAME)
	assert_eq(floats.texts_over(me), PackedStringArray(["Sin sangrado"]))
	assert_eq(floats.color_of(me, "Sin sangrado"), tuning.cure_color)


func test_a_drain_floats_nothing() -> void:
	me.meters.thirst = 0.0
	floats.step(FRAME)
	_steps(1.1)
	assert_eq(floats.texts_over(me), PackedStringArray(), "the -100 Sed of emptying thirst at once has gone")
	var rest := MeterContext.new()
	for i: int in 180:
		me.meters.tick(FRAME, rest)
		floats.step(FRAME)
		assert_eq(floats.texts_over(me), PackedStringArray(), "frame %d" % i)


func test_nothing_floats_while_a_screen_is_over_the_run() -> void:
	hud.set_screen_shown(true)
	me.meters.thirst = 50.0
	floats.step(FRAME)
	_steps(1.1)
	_drink_coconut()
	floats.step(FRAME)
	assert_eq(floats.shown_count(), 0)
	hud.set_screen_shown(false)
