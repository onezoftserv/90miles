extends GutTest
## secret-cay "Needle on the carrier's HUD", "Needle target" and "Needle bands" with exactly 1
## offline player: no needle without the broken compass; with it, a 24x24 needle top-centre under
## the day phase, inside 640x360 and clear of the meters, the teammate list and the bottom band.
## It points at the nearest concealed item (never one someone carries), else the unopened chest,
## else spins at 0.5 turn/s; it spins beyond 40 tiles, wobbles within ±90°, ±45° and ±20° inside
## 40, 20 and 11, holds still inside 6, and rattles once on entering 40 tiles. Time is stepped by
## hand; positions are set straight, as straight-line distance is all the needle reads.

const SESSION_SCENE: PackedScene = preload("res://scenes/net/coop_session.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const TILE: float = 16.0
const HERE: Vector2 = Vector2(800.0, 800.0)
const COMPASS: StringName = &"brujula_rota"
const MAP: StringName = &"mapa_sin_norte"
const STEP_S: float = 0.05
const VIEW: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

var session: CoopSession
var body: PlayerBody
var hud: RunHud


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
	hud = HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	hud.bind(session, CoopSession.HOST_ID, true)
	hud.needle.set_process(false)


func after_each() -> void:
	NetManager.leave()


func _carry_compass() -> void:
	body.inventory.add(COMPASS, 1)


func _map_at(tiles: Vector2) -> WorldItem:
	var map: WorldItem = session.spawn_pickup(MAP, 1, HERE + tiles * TILE)
	map.set_process(false)
	return map


# The needle's largest swing off its bearing, in degrees, over `seconds` of steps.
func _swing_deg(seconds: float) -> float:
	var widest: float = 0.0
	var t: float = 0.0
	while t < seconds:
		hud.needle.step(STEP_S)
		widest = maxf(widest, absf(rad_to_deg(angle_difference(hud.needle.bearing_rad, hud.needle.angle_rad))))
		t += STEP_S
	return widest


func test_no_needle_without_the_compass() -> void:
	_map_at(Vector2(5.0, 0.0))
	hud.needle.step(STEP_S)
	assert_false(hud.needle.visible, "no compass, no needle")


func test_a_solo_player_picks_up_the_compass() -> void:
	hud.needle.step(STEP_S)
	assert_false(hud.needle.visible)
	_carry_compass()
	hud.needle.step(STEP_S)
	assert_true(hud.needle.visible, "the needle shows once the compass is carried")
	var rect: Rect2 = hud.needle.get_global_rect()
	assert_eq(rect.size, Vector2(24.0, 24.0), "24x24 px")
	var phase: Rect2 = (hud.get_node(^"PhasePanel") as Control).get_global_rect()
	assert_almost_eq(rect.get_center().x, 320.0, 0.5, "top-centre")
	assert_gte(rect.position.y, phase.end.y, "under the day phase")
	assert_lt(rect.position.y, 60.0, "near the top")
	assert_true(VIEW.encloses(rect), "inside 640x360")
	assert_false(rect.intersects(hud.meters.panel_rect()), "clear of the meters")
	assert_false(rect.intersects(hud.teammates_panel.get_global_rect()), "clear of the teammate list")
	assert_false(rect.intersects(hud.strip.strip_rect()), "clear of the bottom band")
	assert_true(hud.needle.is_in_group(RunHud.AVOID_GROUP), "the interact prompt keeps clear of it")


func test_pointing_at_the_map_then_spinning() -> void:
	_carry_compass()
	var map := _map_at(Vector2(5.0, 0.0))
	hud.needle.step(STEP_S)
	assert_eq(hud.needle.target, map as Node2D, "the concealed map")
	assert_almost_eq(hud.needle.angle_rad, 0.0, 0.001, "due east")
	assert_eq(_swing_deg(2.0), 0.0, "holds still within 6 tiles")
	map.interactable.use(body)
	await get_tree().process_frame
	assert_eq(body.inventory.count_id(MAP), 1, "the map is carried now")
	hud.needle.step(STEP_S)
	assert_null(hud.needle.target, "nothing left to point at")
	assert_true(hud.needle.spinning)
	var before: float = hud.needle.angle_rad
	hud.needle.step(1.0)
	assert_almost_eq(absf(angle_difference(before, hud.needle.angle_rad)), PI, 0.001, "half a turn in 1 s")


func test_a_solo_player_walks_in() -> void:
	_carry_compass()
	var map := _map_at(Vector2.ZERO)
	body.position = HERE + Vector2(-44.0 * TILE, 0.0)
	watch_signals(hud.needle)
	hud.needle.step(STEP_S)
	assert_true(hud.needle.spinning, "spins at 44 tiles")
	var bands: Dictionary[float, Vector2] = {30.0: Vector2(45.0, 90.0), 15.0: Vector2(20.0, 45.0), 8.0: Vector2(0.0, 20.0)}
	for tiles: float in bands:
		body.position = HERE + Vector2(-tiles * TILE, 0.0)
		hud.needle.step(STEP_S)
		assert_false(hud.needle.spinning, "no spin at %d tiles" % tiles)
		var swing: float = _swing_deg(3.0)
		assert_lte(swing, bands[tiles].y + 0.01, "within ±%d° at %d tiles" % [bands[tiles].y, tiles])
		assert_gt(swing, bands[tiles].x, "wider than the next band at %d tiles" % tiles)
	body.position = HERE + Vector2(-4.0 * TILE, 0.0)
	hud.needle.step(STEP_S)
	assert_eq(_swing_deg(2.0), 0.0, "holds still at 4 tiles")
	assert_eq(hud.needle.target, map as Node2D)
	assert_signal_emit_count(hud.needle, "rattled", 1, "it rattled exactly once")


func test_leaving_re_arms_the_rattle() -> void:
	_carry_compass()
	_map_at(Vector2.ZERO)
	watch_signals(hud.needle)
	for tiles: float in [44.0, 38.0, 44.0, 38.0]:
		body.position = HERE + Vector2(-tiles * TILE, 0.0)
		hud.needle.step(STEP_S)
	assert_signal_emit_count(hud.needle, "rattled", 2, "a second rattle after leaving to 44 and coming back")


func test_it_never_targets_a_carried_item_and_takes_the_nearest() -> void:
	_carry_compass()
	body.inventory.add(MAP, 1)
	var far := _map_at(Vector2(0.0, 12.0))
	var near := _map_at(Vector2(-6.0, 0.0))
	hud.needle.step(STEP_S)
	assert_eq(hud.needle.target, near as Node2D, "the nearest concealed item")
	assert_ne(hud.needle.target, far as Node2D)
	assert_almost_eq(absf(hud.needle.bearing_rad), PI, 0.001, "due west")


func test_ordinary_items_are_never_targets() -> void:
	_carry_compass()
	session.spawn_pickup(&"driftwood", 1, HERE + Vector2(3.0 * TILE, 0.0))
	hud.needle.step(STEP_S)
	assert_null(hud.needle.target, "driftwood is not concealed")
	assert_true(hud.needle.spinning)
