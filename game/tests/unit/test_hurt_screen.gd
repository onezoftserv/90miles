extends GutTest
## ui-shell "Hit flash at the screen edges", "Changes show on the bars" and "Drain glow on the
## health bar" (damage-feedback design D5, D7, D10), with exactly 1 player, offline: a MetersHud
## bound to one body's meters, stepped by hand so no frame runs on its own.

const HUD_SCENE: PackedScene = preload("res://scenes/ui/meters_hud.tscn")
const RUN_HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const M := DataEnums.Meter
const FRAME: float = 1.0 / 60.0

var hud: MetersHud
var meters: SurvivalMeters
var cued: Array[StringName] = []


func before_each() -> void:
	HurtCues.reduce_flashes = false
	cued.clear()
	hud = HUD_SCENE.instantiate() as MetersHud
	add_child_autofree(hud)
	hud.set_process(false)
	meters = _meters()
	hud.bind(meters)
	hud.hurt_cued.connect(func(id: StringName) -> void: cued.append(id))
	hud.step(FRAME)


func after_each() -> void:
	HurtCues.reduce_flashes = false


func _meters() -> SurvivalMeters:
	var made := SurvivalMeters.new()
	add_child_autofree(made)
	return made


func _steps(seconds: float) -> void:
	for i: int in roundi(seconds / FRAME):
		hud.step(FRAME)


func _health_bar() -> MeterBar:
	return hud.bar_for(M.HEALTH)


# --- the edge flash ------------------------------------------------------------------------------

func test_a_pinch_flashes_the_edges_and_clears_in_0_4_s() -> void:
	assert_eq(hud.flash_strength(), 0.0, "nothing before a hit")
	meters.harm(5.0, &"land_crab")
	hud.step(FRAME)
	assert_gt(hud.flash_strength(), 0.0, "the edges flash")
	assert_true(hud.hurt_overlay().visible)
	_steps(0.4)
	assert_eq(hud.flash_strength(), 0.0, "clear 0.4 s later")
	assert_false(hud.hurt_overlay().visible)


func test_a_bigger_hit_flashes_stronger() -> void:
	meters.harm(5.0, &"land_crab")
	hud.step(FRAME)
	var crab: float = hud.flash_strength()
	var other := _meters()
	hud.bind(other)
	hud.step(FRAME)
	other.harm(25.0, &"reef_shark")
	hud.step(FRAME)
	assert_gt(hud.flash_strength(), crab, "a shark's 25 against a crab's 5")
	assert_gt(crab, 0.15, "the smallest hit is still plain to see")


func test_two_hits_close_together_flash_once() -> void:
	meters.harm(5.0, &"land_crab")
	hud.step(FRAME)
	assert_eq(hud.flashes_started(), 1)
	_steps(0.1)
	meters.harm(5.0, &"land_crab")
	hud.step(FRAME)
	assert_eq(hud.flashes_started(), 1, "a hit 0.1 s later does not start a second flash")
	_steps(0.5)
	meters.harm(5.0, &"land_crab")
	hud.step(FRAME)
	assert_eq(hud.flashes_started(), 2, "one after the gap does")


func test_reduce_flashes_never_flashes_or_shakes() -> void:
	HurtCues.reduce_flashes = true
	meters.harm(25.0, &"reef_shark")
	hud.step(FRAME)
	assert_eq(hud.flash_strength(), 0.0)
	assert_false(hud.hurt_overlay().visible)
	assert_false(_health_bar().shaking(), "no shake")
	assert_ne(_health_bar().lost_range(), Vector2.ZERO, "the lost part still shows")
	meters.thirst = 50.0
	hud.step(FRAME)
	meters.thirst = 65.0
	hud.step(FRAME)
	assert_false(hud.bar_for(M.THIRST).flashing(), "no bar flash")
	assert_ne(hud.bar_for(M.THIRST).gained_range(), Vector2.ZERO, "the gained part still shows")


# --- the bars ------------------------------------------------------------------------------------

func test_a_bite_leaves_a_lost_part_that_holds_then_shrinks() -> void:
	meters.harm(25.0, &"reef_shark")
	hud.step(FRAME)
	var bar := _health_bar()
	assert_eq(bar.bar.value, 75.0, "the fill is the new value")
	assert_eq(bar.lost_range(), Vector2(75.0, 100.0), "75 to 100 in pale red")
	_steps(0.35)
	assert_eq(bar.lost_range(), Vector2(75.0, 100.0), "held for 0.4 s")
	_steps(0.25)
	var mid: Vector2 = bar.lost_range()
	assert_true(mid.y < 100.0 and mid.y > 75.0, "shrinking: %s" % mid)
	_steps(0.3)
	assert_eq(bar.lost_range(), Vector2.ZERO, "gone 0.9 s after the bite")


func test_a_hit_shakes_the_health_bar_for_0_2_s_and_a_drain_never_does() -> void:
	var bar := _health_bar()
	meters.harm(5.0, &"land_crab")
	hud.step(FRAME)
	assert_true(bar.shaking())
	_steps(0.21)
	assert_false(bar.shaking(), "still after 0.2 s")
	meters.thirst = 0.0
	var rest := MeterContext.new()
	for i: int in 180:
		meters.tick(FRAME, rest)
		hud.step(FRAME)
		assert_false(bar.shaking(), "a drain does not shake, frame %d" % i)


func test_a_jump_lights_its_gained_part_flashes_and_blends_in_within_1_s() -> void:
	meters.thirst = 50.0
	hud.step(FRAME)
	_steps(0.5)
	meters.thirst = 65.0
	hud.step(FRAME)
	var bar := hud.bar_for(M.THIRST)
	assert_eq(bar.gained_range(), Vector2(50.0, 65.0), "50 to 65 in a light blue")
	assert_true(bar.flashing(), "the bar flashes once")
	_steps(0.2)
	assert_false(bar.flashing())
	_steps(0.8)
	assert_eq(bar.gained_range(), Vector2.ZERO, "plain fill 1 s later")


func test_a_slow_regain_lights_nothing() -> void:
	meters.morale = 50.0
	hud.step(FRAME)
	_steps(0.5)
	for i: int in 120:
		meters.morale += 1.0 * FRAME
		hud.step(FRAME)
	assert_eq(hud.bar_for(M.MORALE).gained_range(), Vector2.ZERO)


func test_a_rebind_shows_no_part_and_no_flash() -> void:
	var other := _meters()
	other.health = 90.0
	meters.health = 40.0
	hud.step(FRAME)
	_steps(1.0)
	hud.bind(other)
	hud.step(FRAME)
	assert_eq(_health_bar().bar.value, 90.0)
	assert_eq(_health_bar().lost_range(), Vector2.ZERO)
	assert_eq(_health_bar().gained_range(), Vector2.ZERO)
	assert_eq(hud.flash_strength(), 0.0)


# --- the drain glow ------------------------------------------------------------------------------

func test_the_glow_shows_while_thirst_drains_and_stops_1_s_after() -> void:
	var bar := _health_bar()
	meters.thirst = 0.0
	var rest := MeterContext.new()
	for i: int in 60:
		meters.tick(FRAME, rest)
		hud.step(FRAME)
	assert_true(bar.glowing(), "the Salud frame glows dim red")
	assert_ne(bar.lost_range(), Vector2.ZERO, "and the chunk ticks down")
	meters.thirst = 50.0
	_steps(0.9)
	assert_true(bar.glowing(), "still 0.9 s after the last loss")
	_steps(0.2)
	assert_false(bar.glowing(), "stopped 1 s after")


func test_a_lone_hit_does_not_glow() -> void:
	meters.harm(5.0, &"land_crab")
	hud.step(FRAME)
	_steps(0.3)
	assert_false(_health_bar().glowing())


# --- the sound hook ------------------------------------------------------------------------------

func test_the_sound_hook_hears_hits_drains_and_jumps() -> void:
	meters.harm(5.0, &"land_crab")
	hud.step(FRAME)
	assert_eq(cued, [&"hurt_hit"] as Array[StringName])
	_steps(1.5)
	meters.harm(25.0, &"reef_shark")
	hud.step(FRAME)
	assert_eq(cued.back(), &"hurt_big")
	_steps(1.5)
	cued.clear()
	meters.thirst = 0.0
	var rest := MeterContext.new()
	for i: int in 120:
		meters.tick(FRAME, rest)
		hud.step(FRAME)
	assert_eq(cued, [&"hurt_drain"] as Array[StringName], "once per drain")
	cued.clear()
	meters.thirst = 50.0
	hud.step(FRAME)
	assert_eq(cued, [&"use_done"] as Array[StringName], "a drink's jump")


# --- the overlay's place -------------------------------------------------------------------------

func test_the_overlay_ignores_the_mouse_and_is_no_panel() -> void:
	var overlay := hud.hurt_overlay()
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var as_control: Control = overlay
	assert_false(as_control is PanelContainer, "no HUD panel")
	var run_hud := RUN_HUD_SCENE.instantiate() as RunHud
	add_child_autofree(run_hud)
	var before: Array[Rect2] = run_hud.panel_rects()
	run_hud.meters.hurt_overlay().visible = true
	assert_eq(run_hud.panel_rects(), before, "the full-screen overlay is not counted as a panel")
