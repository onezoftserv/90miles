extends GutTest
## island-pressure task 4.1, 1 player, offline (survival-meters "Heat"): a rider at sea never gains heat
## past the sea cap, 59, and above it falls at the shade rate down to it, so nobody is sunstruck at sea;
## back on land the sun works as before. Then a real 1-player crossing from the shell at 11:00: the
## rider's own context says at sea (the session's departures) and the heat stops at the cap.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const HOUR_S: float = 30.0
const STEP_S: float = 0.1
var settings_path: String = UserTmp.path("test_sea_heat_settings.cfg")

var meters: SurvivalMeters
var shell: GameShell


func before_each() -> void:
	meters = autofree(SurvivalMeters.new()) as SurvivalMeters


func after_each() -> void:
	WeatherManager.sky.weather.rolls_enabled = true
	WeatherManager.sky.start_at(0.0)
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


# Midday, in direct sun, at sea or on land.
func _sun(at_sea: bool) -> MeterContext:
	var context := MeterContext.new()
	context.phase = DataEnums.DayPhase.DAY
	context.midday = true
	context.at_sea = at_sea
	return context


func _tick(context: MeterContext, seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		meters.tick(STEP_S, context)


func test_the_cap_is_data() -> void:
	assert_eq(meters.tuning.sea_heat_cap, 59.0)
	assert_lt(meters.tuning.sea_heat_cap, meters.tuning.sunstroke_ends_below, "below where sunstroke ends")


func test_solo_midday_at_sea() -> void:
	meters.heat = 40.0
	_tick(_sun(true), 60.0)
	assert_almost_eq(meters.heat, 59.0, 0.001)
	assert_false(meters.sunstroke)


func test_scorching_calm_at_sea_stops_at_the_cap_too() -> void:
	var context := _sun(true)
	context.heat_factor = 2.0
	_tick(context, 60.0)
	assert_almost_eq(meters.heat, 59.0, 0.001)


func test_boarding_sunstruck() -> void:
	meters.heat = 100.0
	meters.tick(0.0, _sun(false))
	assert_true(meters.sunstroke, "sunstruck on the beach")
	_tick(_sun(true), 55.0)
	assert_almost_eq(meters.heat, 59.0, 0.001)
	assert_false(meters.sunstroke, "over at sea")


func test_back_on_land() -> void:
	meters.heat = 59.0
	_tick(_sun(false), 60.0)
	assert_almost_eq(meters.heat, 100.0, 0.001)
	assert_true(meters.sunstroke)


func test_the_cap_has_one_switch() -> void:
	var context := _sun(true)
	assert_true(SurvivalRules.sea_heat_capped(context, meters.tuning))
	assert_false(SurvivalRules.sea_heat_capped(_sun(false), meters.tuning), "on land, no cap")
	var off := meters.tuning.duplicate() as SurvivalTuning
	off.sea_heat_cap = -1.0
	assert_false(SurvivalRules.sea_heat_capped(context, off), "a negative cap is off")
	assert_almost_eq(SurvivalRules.next_heat(59.0, context, off, 1.0), 59.75, 0.0001, "and the sun works as on land")


func test_shade_at_sea_falls_past_the_cap() -> void:
	var shade := _sun(true)
	shade.shaded = true
	meters.heat = 70.0
	_tick(shade, 20.0)
	assert_almost_eq(meters.heat, 55.0, 0.001, "the shade rate all the way, as the toldo's shade will be")


func test_the_cap_holds_nothing_below_it() -> void:
	var shade := MeterContext.new()
	shade.phase = DataEnums.DayPhase.DAY
	shade.midday = true
	shade.shaded = true
	shade.at_sea = true
	meters.heat = 30.0
	_tick(shade, 10.0)
	assert_almost_eq(meters.heat, 22.5, 0.001, "shade at sea falls as on land")
	var night := MeterContext.new()
	night.phase = DataEnums.DayPhase.NIGHT
	night.at_sea = true
	_tick(night, 0.1)
	assert_eq(meters.heat, 0.0, "night resets heat at sea too")


# A real 1-player crossing launched at 11:00 (the island's boat taken away, so a day launch starts):
# the rider in the midday sun on the deck never passes the cap and never gets sunstroke.
func test_a_solo_crossing_at_11_never_sunstrikes() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	shell = SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	var session := shell.session
	var body := session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	WeatherManager.sky.weather.rolls_enabled = false
	await wait_physics_frames(3)
	WeatherManager.stop()
	WeatherManager.sky.start_at(5.0 * HOUR_S)
	for boat: Creature in LaunchSight.boats_of(session):
		boat.get_parent().remove_child(boat)
		boat.queue_free()
	var site := session.get_node("RaftSite") as BuildSite
	for id: StringName in site.recipe.inputs:
		site.deposited[id] = site.recipe.inputs[id]
	site.work(1.0)
	var raft := session.get_node("Raft") as Raft
	body.global_position = raft.global_position
	body.meters.heat = 40.0
	raft.interactable.interacted.emit(body)
	assert_true(session.has_left(CoopSession.HOST_ID), "the raft launched")
	await wait_physics_frames(2)
	assert_true(body._meter_context().at_sea, "the rider's context says at sea")
	assert_true(body._meter_context().midday and body._meter_context().in_direct_sun(), "in the midday sun on the deck")
	var peak: float = 0.0
	var struck: bool = false
	for i: int in roundi(70.0 / STEP_S):
		body._tick_meters(STEP_S)
		peak = maxf(peak, body.meters.heat)
		struck = struck or body.meters.sunstroke
	assert_almost_eq(peak, 59.0, 0.001, "the heat stops at the cap")
	assert_false(struck, "never sunstruck")
