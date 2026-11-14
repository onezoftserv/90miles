extends GutTest
## secret-cay "Concealment", "Shimmer", "Concealed pick-up hold" and crafting-inventory "Pick-up"
## with exactly 1 offline player: a concealed item draws nothing distinct but its shimmer until the
## player is within its reveal radius; it shimmers for 0.75 s every 6 s from its own phase (every
## 4 s once the tuning says so); taking it needs a 1.5 s hold, while driftwood stays instant; the
## host emits `taken` with the picker and the item id. Time is stepped by hand.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const TILE: float = 16.0
const MAP: StringName = &"mapa_sin_norte"
const STEP_S: float = 0.05
const FRAME_S: float = 1.0 / 60.0
const HERE: Vector2 = Vector2(400.0, 400.0)

var session: CoopSession
var body: PlayerBody


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	session = SESSION_SCENE.instantiate() as CoopSession
	session.spawn_points = [HERE] as Array[Vector2]
	add_child_autofree(session)
	session.start()
	body = session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	body.auto_advance = false


func after_each() -> void:
	NetManager.leave()


# A pick-up of `id` lying `tiles` tiles due east of the player, stepped by hand.
func _lying(id: StringName, tiles: float) -> WorldItem:
	var item: WorldItem = session.spawn_pickup(id, 1, HERE + Vector2(tiles * TILE, 0.0))
	item.set_process(false)
	return item


func _tuning(period_s: float, length_s: float) -> SecretTuning:
	var copy := SecretTuning.standard().duplicate() as SecretTuning
	copy.shimmer_period_s = period_s
	copy.shimmer_length_s = length_s
	return copy


func _look(item: WorldItem) -> WorldItemLook:
	return item.get_node(^"Look") as WorldItemLook


# Steps `item` for `seconds` and returns when each shimmer started and how long it lasted.
func _shimmers(item: WorldItem, seconds: float) -> Array[Vector2]:
	var found: Array[Vector2] = []
	var start_s: float = -1.0
	item.step(0.0)
	var t: float = 0.0
	while t < seconds - STEP_S / 2.0:
		var now: bool = item.shimmering()
		if now and start_s < 0.0:
			start_s = t
		elif not now and start_s >= 0.0:
			found.append(Vector2(start_s, t - start_s))
			start_s = -1.0
		item.step(STEP_S)
		t += STEP_S
	if start_s >= 0.0:
		found.append(Vector2(start_s, t - start_s))
	return found


func _hold(seconds: float) -> void:
	var frames: int = roundi(seconds / FRAME_S)
	for i: int in frames:
		body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
		body.advance(FRAME_S)
	body.intent = MoveIntent.create(Vector2.ZERO, false, false, false)
	body.advance(FRAME_S)


func test_revealed_by_walking_close() -> void:
	var map := _lying(MAP, 5.0)
	map.tuning = _tuning(6.0, 0.0)
	map.step(0.1)
	assert_true(map.concealed, "the map is a concealed item")
	assert_eq(map.drawn_state(), WorldItem.DRAWN_NOTHING, "nothing distinct at 5 tiles")
	assert_false(_look(map).icon.visible, "no icon")
	assert_false(_look(map).shadow.visible, "no shadow")
	assert_false(_look(map).shimmer, "no shimmer with a shimmer length of 0")
	body.position = HERE + Vector2(2.0 * TILE, 0.0)
	map.step(0.1)
	assert_eq(map.drawn_state(), WorldItem.DRAWN_NORMAL, "drawn normally at 3 tiles")
	assert_true(_look(map).icon.visible, "its icon shows")


func test_a_solo_player_spots_the_glint_from_afar() -> void:
	var map := _lying(MAP, 15.0)
	map.shimmer_phase_s = 0.0
	var shimmers: Array[Vector2] = _shimmers(map, 12.0)
	assert_eq(shimmers.size(), 2, "two shimmers in 12 s: %s" % [shimmers])
	if shimmers.size() == 2:
		assert_almost_eq(shimmers[0].x, 0.0, STEP_S * 1.5, "the first at 0 s")
		assert_almost_eq(shimmers[1].x, 6.0, STEP_S * 1.5, "the second at 6 s")
		for shimmer: Vector2 in shimmers:
			assert_almost_eq(shimmer.y, 0.75, STEP_S * 1.5, "each lasts 0.75 s")
	map.step(1.0)
	assert_eq(map.drawn_state(), WorldItem.DRAWN_NOTHING, "nothing between shimmers (13 s)")


func test_the_shimmer_draws_while_it_lasts() -> void:
	var map := _lying(MAP, 15.0)
	map.shimmer_phase_s = 0.0
	map.step(0.1)
	assert_eq(map.drawn_state(), WorldItem.DRAWN_SHIMMER)
	assert_true(_look(map).shimmer, "the look draws the glint")
	assert_false(_look(map).icon.visible, "but not the item")


func test_retuning_the_period_is_a_data_edit() -> void:
	var map := _lying(MAP, 15.0)
	map.tuning = _tuning(4.0, 0.75)
	map.shimmer_phase_s = 0.0
	var shimmers: Array[Vector2] = _shimmers(map, 12.0)
	assert_eq(shimmers.size(), 3, "every 4 s: %s" % [shimmers])
	if shimmers.size() == 3:
		assert_almost_eq(shimmers[1].x, 4.0, STEP_S * 1.5)
		assert_almost_eq(shimmers[2].x, 8.0, STEP_S * 1.5)


func test_phases_differ_by_name() -> void:
	var first := _lying(MAP, 15.0)
	var second := _lying(MAP, 16.0)
	assert_between(first.shimmer_phase_s, 0.0, first.tuning.shimmer_period_s)
	assert_ne(first.shimmer_phase_s, second.shimmer_phase_s, "pieces do not blink together")


func test_a_solo_player_digs_out_the_compass() -> void:
	var compass := _lying(&"brujula_rota", 0.5)
	assert_eq(compass.interactable.hold_time_s, 1.5, "the tuning's hold")
	_hold(FRAME_S)
	assert_eq(body.inventory.count_id(&"brujula_rota"), 0, "a press takes nothing")
	_hold(1.0)
	assert_eq(body.inventory.count_id(&"brujula_rota"), 0, "a 1 s hold takes nothing")
	assert_false(compass.is_queued_for_deletion(), "still on the ground")
	_hold(1.5)
	assert_eq(body.inventory.count_id(&"brujula_rota"), 1, "a 1.5 s hold takes it")


func test_driftwood_is_still_instant() -> void:
	var wood := _lying(&"driftwood", 0.5)
	assert_false(wood.concealed)
	assert_eq(wood.interactable.hold_time_s, 0.0)
	assert_eq(wood.drawn_state(), WorldItem.DRAWN_NORMAL)
	_hold(FRAME_S)
	assert_eq(body.inventory.count_id(&"driftwood"), 1, "a press takes it")


func test_the_host_tells_who_took_it() -> void:
	var map := _lying(MAP, 0.5)
	watch_signals(map)
	map.interactable.use(body)
	assert_signal_emitted_with_parameters(map, "taken", [body, MAP])
