extends GutTest
## art-mood-pass "Squall on screen" and the MODIFIED "Scrolling sea" (design D3, D4), with exactly 1
## player, offline: the sea and the foam run on clocks that the weather's pace speeds up, easing so
## nothing jumps, and keep running under a solo pause; a squall's rain overlay lives inside the
## tinted world and goes when calm returns; its splashes are hashed, never rolled. Drawing only.

const ISLAND_SCENE: PackedScene = preload("res://scenes/levels/sandbar_island.tscn")
const TINT_SCENE: PackedScene = preload("res://scenes/world/day_night_tint.tscn")
const RAIN_SCRIPT: String = "res://scenes/art/weather/rain_overlay.gd"
const SHORE_SHADER: String = "res://scenes/art/sea/shore.gdshader"
const STEP_S: float = 1.0 / 60.0


func before_each() -> void:
	WeatherManager.stop()
	WeatherManager.sky.start_at(200.0)


func after_each() -> void:
	get_tree().paused = false
	WeatherManager.stop()
	WeatherManager.sky.start_at(200.0)


func _squall() -> WeatherData:
	return GameState.content.get_entry(&"weather", &"squall") as WeatherData


func _island() -> SandbarIsland:
	var island := ISLAND_SCENE.instantiate() as SandbarIsland
	island.layout = preload("res://resources/islands/sandbar.tres")
	island.with_creatures = false
	add_child_autofree(island)
	return island


func test_the_pace_eases_to_the_squall_and_back_and_the_clocks_never_jump() -> void:
	var ease_s: float = ArtTuning.standard().pace_ease_s
	assert_gt(ease_s, 0.0, "the pace eases")
	var pace := SeaPace.new(ease_s)
	var squall := _squall()
	var top: float = maxf(squall.sea_pace, squall.foam_pace)
	assert_gt(squall.sea_pace, 1.0, "a squall speeds the sea")
	assert_gt(squall.foam_pace, 1.0, "and the foam")
	var steps: int = roundi(ease_s / STEP_S)
	for i: int in steps:
		var sea_before: float = pace.sea_time
		var foam_before: float = pace.foam_time
		pace.step(STEP_S, squall.sea_pace, squall.foam_pace)
		assert_true(pace.sea_time - sea_before <= top * STEP_S + 0.000001, "the sea clock never jumps (step %d)" % i)
		assert_true(pace.foam_time - foam_before <= top * STEP_S + 0.000001, "nor the foam's (step %d)" % i)
		if i == 0:
			assert_lt(pace.sea_pace, 1.1, "the first step is still near calm's pace")
	assert_almost_eq(pace.sea_pace, squall.sea_pace, 0.0001, "the sea reaches the squall's pace within the ease")
	assert_almost_eq(pace.foam_pace, squall.foam_pace, 0.0001)
	for i: int in steps:
		pace.step(STEP_S, 1.0, 1.0)
	assert_almost_eq(pace.sea_pace, 1.0, 0.0001, "back in calm, pace 1")
	assert_almost_eq(pace.foam_pace, 1.0, 0.0001)


func test_the_shaders_drift_and_step_on_the_new_clocks() -> void:
	var sea: String = SeaShaderChecks.source()
	var fragment: String = sea.substr(sea.find("void fragment"))
	assert_true(fragment.contains("drift * sea_time") and fragment.contains("second_drift * sea_time"), "both drift terms run on sea_time")
	assert_false(fragment.contains("drift * TIME"), "no drift term runs on the shader clock")
	assert_true(fragment.contains("TIME * wobble_speed"), "the sway keeps the shader clock, so the line's excursion is unchanged")
	var shore: String = (load(SHORE_SHADER) as Shader).code
	assert_true(shore.contains("foam_time * frames_per_second"), "the foam steps on foam_time")
	assert_false(RegEx.create_from_string("\\bTIME\\b").search(shore.substr(shore.find("void fragment"))) != null, "and not on TIME")


## One player, offline: the island's driver writes both clocks to the sea and to the Shore layer.
func test_a_solo_sandbar_sea_and_foam_run_on_the_drivers_clocks() -> void:
	var view := _island().get_node(^"Terrain") as TerrainView
	var driver := view.get_node_or_null(^"SeaPace") as SeaPaceDriver
	assert_not_null(driver, "a SeaPace driver under the terrain view")
	if driver == null:
		return
	assert_eq(driver.process_mode, Node.PROCESS_MODE_ALWAYS, "it keeps running under a solo pause")
	WeatherManager.sky.weather.start_weather(&"squall")
	for i: int in 30:
		driver.step(STEP_S)
	var sea := (view.get_node(^"Sea") as Polygon2D).material as ShaderMaterial
	var shore := (view.get_node(^"Shore") as TileMapLayer).material as ShaderMaterial
	assert_almost_eq(SeaShaderChecks.clock_of(sea, &"sea_time"), driver.pace.sea_time, 0.0001, "the sea's material holds sea_time")
	assert_almost_eq(SeaShaderChecks.clock_of(shore, &"foam_time"), driver.pace.foam_time, 0.0001, "the Shore layer's holds foam_time")
	assert_gt(driver.pace.sea_pace, 1.0, "the squall has begun to speed the sea")
	assert_gt(SeaShaderChecks.drift_per_s(sea, driver.pace.sea_pace).x, SeaShaderChecks.DRIFT_PX_PER_S, "so the water drifts faster than 5 px/s")


func test_under_a_pause_the_sea_and_foam_move_and_the_day_does_not() -> void:
	var view := _island().get_node(^"Terrain") as TerrainView
	var driver := view.get_node(^"SeaPace") as SeaPaceDriver
	WeatherManager.start(200.0)
	await wait_process_frames(2)
	var sea_before: float = driver.pace.sea_time
	var foam_before: float = driver.pace.foam_time
	var day_before: float = WeatherManager.sky.clock.time_of_day_s
	get_tree().paused = true
	await wait_process_frames(5)
	var sea_after: float = driver.pace.sea_time
	var foam_after: float = driver.pace.foam_time
	var day_after: float = WeatherManager.sky.clock.time_of_day_s
	get_tree().paused = false
	assert_gt(sea_after, sea_before, "the sea's clock went on")
	assert_gt(foam_after, foam_before, "and the foam's")
	assert_eq(day_after, day_before, "the day's did not")


func test_the_crossing_sea_has_its_own_driver() -> void:
	var sea := CrossingSea.new()
	add_child_autofree(sea)
	var driver := sea.get_node_or_null(^"SeaPace") as SeaPaceDriver
	assert_not_null(driver, "a SeaPace driver under the crossing's sea")
	if driver == null:
		return
	assert_eq(driver.process_mode, Node.PROCESS_MODE_ALWAYS)
	sea.material = ShaderMaterial.new()
	(sea.material as ShaderMaterial).shader = load(SeaShaderChecks.SHADER_PATH) as Shader
	driver.step(STEP_S)
	assert_almost_eq(SeaShaderChecks.clock_of(sea.material as ShaderMaterial, &"sea_time"), driver.pace.sea_time, 0.0001, "it writes the crossing sea's own material")


## One player, offline: a squall starts and the rain is drawn inside the tint, at z 10; calm takes it away.
func test_a_solo_squall_rains_inside_the_tint_and_calm_takes_it_away() -> void:
	var tint := TINT_SCENE.instantiate() as DayNightTint
	add_child_autofree(tint)
	var vfx := tint.get_node_or_null(^"WeatherVfx") as WeatherVfx
	assert_not_null(vfx, "the tint has a WeatherVfx child")
	if vfx == null:
		return
	vfx.follow()
	assert_null(vfx.shown, "calm shows nothing")
	WeatherManager.sky.weather.start_weather(&"squall")
	vfx.follow()
	var rain := vfx.shown as Node2D
	assert_not_null(rain, "the squall's vfx scene is shown")
	if rain == null:
		return
	assert_eq(rain.scene_file_path, _squall().vfx_scene.resource_path, "it is squall.tres's vfx_scene")
	assert_eq(rain.z_index, 10, "over the actors, under the name tags")
	assert_eq(rain.process_mode, Node.PROCESS_MODE_ALWAYS, "the rain falls under a solo pause")
	assert_eq((rain as RainOverlay).rain.resource_path, "res://assets/art/fx/rain.png", "it draws the recipe's rain")
	assert_eq((rain as RainOverlay).splash.resource_path, "res://assets/art/fx/splash.png", "and its splash")
	var up: Node = rain.get_parent()
	while up != null:
		assert_false(up is CanvasLayer, "no CanvasLayer between the rain and the tint: it is tinted")
		if up == tint:
			break
		up = up.get_parent()
	assert_eq(up, tint, "the rain is under the tint")
	vfx.follow()
	assert_eq(vfx.shown, rain, "the same squall keeps the same overlay")
	WeatherManager.sky.weather.start_weather(&"calm")
	vfx.follow()
	assert_null(vfx.shown, "calm takes the rain away")
	await wait_process_frames(1)
	assert_false(is_instance_valid(rain), "and frees it")


func test_the_rain_starts_light_and_turns_heavy() -> void:
	var tint := TINT_SCENE.instantiate() as DayNightTint
	add_child_autofree(tint)
	var vfx := tint.get_node(^"WeatherVfx") as WeatherVfx
	WeatherManager.sky.weather.start_weather(&"squall")
	vfx.follow()
	var rain := vfx.shown as RainOverlay
	assert_not_null(rain)
	if rain == null:
		return
	var tuning := ArtTuning.standard()
	assert_eq(rain.stage(), 0, "the light stage first")
	assert_eq(rain.splash_count(), floori(tuning.rain_splashes / 2.0), "half the splashes")
	WeatherManager.sky.weather.current_left_s -= tuning.rain_light_s
	assert_eq(rain.stage(), 1, "then the heavy one, by the squall's own synced time")
	assert_eq(rain.splash_count(), tuning.rain_splashes, "with every splash")


func test_splashes_are_hashed_from_slot_and_view_and_never_rolled() -> void:
	var view := Rect2i(Vector2i(-3, 5), Vector2i(41, 23))
	var cells: Array[Vector2i] = []
	for slot: int in 40:
		for index: int in 6:
			var cell: Vector2i = RainOverlay.splash_cell(slot, index, view)
			assert_eq(cell, RainOverlay.splash_cell(slot, index, view), "equal inputs, equal cells")
			assert_true(view.has_point(cell), "%s is inside the view" % cell)
			assert_eq(RainOverlay.splash_offset(slot, index), RainOverlay.splash_offset(slot, index))
			if not cells.has(cell):
				cells.append(cell)
	assert_gt(cells.size(), 150, "they spread over the view (%d cells of 240 picks)" % cells.size())
	var source: String = (load(RAIN_SCRIPT) as GDScript).source_code
	for roll: String in ["randi", "randf", "RandomNumberGenerator", "randomize", "rand_range"]:
		assert_false(source.contains(roll), "the rain uses no %s" % roll)
