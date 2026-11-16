extends GutTest
## guardacostas-stealth, group 9 (design.md decision 11; spec "Patrol cues"): the three cues and the
## patrol look, with exactly 1 player offline (the game shell on the real sandbar) and with a host plus a
## client over ENet on localhost (NetHarness).
## - The horizon light shows on the HUD band for exactly the 20 s of HORIZON (a light at night, a grey hull
##   by day), clamped to the band, and goes when the lap starts.
## - The open eye shows over a player whose shown spot fraction is above 0, half filled at 1 s, on both
##   peers; the closed eye wins; it goes at 0.
## - The loudhailer shows a Spanish alert line over the boat when an alert starts and a give-up line when
##   it ends, the same line on both peers.
## - The look: a hull and a PointLight2D cone rotated to the beam, only while the light is on; a client's
##   first frame after a mid-lap join already has the boat and its cone in place.
## - The cues have no text of their own: the lines come from PatrolData.
## The boat's clock is set by hand and its brain stepped in 0.1 s ticks where a test needs exact seconds.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/run_hud.tscn")
const LAYOUT: IslandLayoutData = preload("res://resources/islands/sandbar.tres")
var settings_path: String = UserTmp.path("test_patrol_cues_settings.cfg")
const TIMEOUT_S: float = 5.0
const STEP_S: float = 0.1
const DT: float = 1.0 / 60.0
const TILE: float = 16.0
const NIGHT_S: float = 430.0
const DAY_S: float = 100.0
const NIGHT := DataEnums.DayPhase.NIGHT
const HIDDEN := MovementStep.Stealth.HIDDEN
const VISIBLE := MovementStep.Stealth.VISIBLE

var shell: GameShell
var session: CoopSession
var body: PlayerBody
var spawner: CreatureSpawner
var boat: Creature
var brain: PatrolRoute
var patrol: PatrolData
var net: NetHarness
# Freed before the sessions they read.
var huds: Array[RunHud] = []


func before_each() -> void:
	net = NetHarness.new(self)
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)
	WeatherManager.sky.weather.rolls_enabled = false
	huds.clear()


func after_each() -> void:
	for hud: RunHud in huds:
		if is_instance_valid(hud):
			hud.free()
	huds.clear()
	net.teardown()
	WeatherManager.sky.weather.rolls_enabled = true
	WeatherManager.sky.start_at(0.0)
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))


# --- solo helpers --------------------------------------------------------------------------------

# A solo run on the sandbar at `at_s` seconds since dawn, its one boat found and its clock at 0.
func _start(at_s: float) -> void:
	shell = SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = settings_path
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	session = shell.session
	body = session.body(CoopSession.HOST_ID)
	body.player_input.enabled = false
	await wait_physics_frames(3)
	WeatherManager.stop()
	WeatherManager.sky.start_at(at_s)
	spawner = session.get_node(NodePath(SandbarIsland.CREATURES_NAME)) as CreatureSpawner
	spawner.apply_phase(WeatherManager.phase())
	spawner.set_physics_process(false)
	var boats := spawner.creatures(&"patrol_boat")
	assert_eq(boats.size(), 1, "a solo run on the sandbar has exactly one patrol boat")
	boat = boats[0]
	boat.set_physics_process(false)
	brain = boat.brain as PatrolRoute
	patrol = boat.data.patrol
	_clock(0.0)
	_look().step(0.0)


func _clock(seconds: float) -> void:
	brain.set_clock(seconds)
	boat.advance(0.0)


func _look() -> PatrolLook:
	return boat.get_node(^"PatrolLook") as PatrolLook


# Steps the boat `seconds` in 0.1 s ticks.
func _run(seconds: float) -> void:
	for i: int in roundi(seconds / STEP_S):
		boat.advance(STEP_S)


func _band_has_a_mark(hud: RunHud) -> bool:
	hud.patrol_horizon.tick()
	return hud.patrol_horizon.mark_count() > 0


# The ticks (of 0.1 s) a boat that starts on the horizon shows its mark for, until `limit` ticks.
func _horizon_ticks(hud: RunHud, limit: int) -> int:
	var shown: int = 0
	for i: int in limit:
		if not _band_has_a_mark(hud):
			break
		shown += 1
		boat.advance(STEP_S)
	return shown


# --- the horizon light ----------------------------------------------------------------------------

func test_a_solo_player_sees_the_horizon_light_for_20_s_at_night_and_it_goes_when_the_lap_starts() -> void:
	await _start(NIGHT_S)
	var hud: RunHud = shell.hud
	assert_eq(boat.state_name(), &"HORIZON")
	assert_true(_band_has_a_mark(hud))
	assert_false(hud.patrol_horizon.is_hull(0), "a light at night")
	assert_eq(hud.patrol_horizon.mark_rect(0).size, Vector2(3.0, 2.0))
	var ticks: int = _horizon_ticks(hud, 400)
	assert_eq(ticks, 200, "the light shows for exactly the 20 s of the horizon warning")
	assert_eq(boat.state_name(), &"LAP")
	assert_false(_band_has_a_mark(hud), "and goes when the lap starts")
	_run(101.0)
	assert_eq(boat.state_name(), &"AWAY")
	assert_false(_band_has_a_mark(hud))


func test_by_day_the_horizon_mark_is_a_grey_5_by_2_hull() -> void:
	await _start(DAY_S)
	var hud: RunHud = shell.hud
	assert_eq(WeatherManager.phase(), DataEnums.DayPhase.DAY)
	assert_true(_band_has_a_mark(hud))
	assert_true(hud.patrol_horizon.is_hull(0), "a hull by day")
	assert_eq(hud.patrol_horizon.mark_rect(0).size, Vector2(5.0, 2.0))
	assert_eq(_horizon_ticks(hud, 400), 200)


func test_the_horizon_mark_is_placed_by_the_laps_start_bearing_and_clamped_to_the_band() -> void:
	assert_eq(PatrolHorizon.bearing_x(Vector2(0.0, -100.0)), 320.0, "straight up is the middle")
	assert_eq(PatrolHorizon.bearing_x(Vector2(100.0, 0.0)), 640.0, "east is the right edge")
	assert_eq(PatrolHorizon.bearing_x(Vector2(-100.0, 0.0)), 0.0, "west is the left edge")
	assert_eq(PatrolHorizon.bearing_x(Vector2(0.0, 100.0)), 640.0, "behind clamps to an edge")
	assert_between(PatrolHorizon.bearing_x(Vector2(100.0, -100.0)), 479.9, 480.1, "north-east is three quarters across")
	await _start(NIGHT_S)
	var hud: RunHud = shell.hud
	assert_true(_band_has_a_mark(hud))
	var rect: Rect2 = hud.patrol_horizon.mark_rect(0)
	assert_gte(rect.position.x, 0.0)
	assert_lte(rect.end.x, 640.0, "clamped to the band")
	assert_between(rect.position.y, 0.0, 6.0)
	# The lap starts at the island's most easterly point: east of the player, so right of the middle.
	var start: Vector2 = boat.view().start_px()
	var gap: Vector2 = start - body.global_position
	assert_almost_eq(rect.position.x + rect.size.x / 2.0, clampf(PatrolHorizon.bearing_x(gap), rect.size.x / 2.0, 640.0 - rect.size.x / 2.0), 1.0)
	assert_gt(gap.x, 0.0)
	assert_gt(rect.position.x, 320.0)


# --- the open eye -----------------------------------------------------------------------------------

func test_a_solo_player_with_a_half_meter_shows_a_half_filled_open_eye_and_the_closed_eye_wins() -> void:
	await _start(NIGHT_S)
	var marks: BodyMarks = shell.hud.marks
	marks.tick()
	assert_false(marks.has_open_eye(body), "no eye at 0")
	body.spot_meter.value = 1.0
	body.net._physics_process(DT)
	assert_almost_eq(body.spot_shown, 0.5, 0.0001, "1 s of a 2 s meter")
	marks.tick()
	assert_true(marks.has_open_eye(body))
	assert_almost_eq(marks.eye_fill(body), 0.5, 0.0001, "half filled")
	assert_eq(marks.eye_rect(body).size, Vector2(7.0, 5.0))
	assert_eq(BodyMarks.iris_pixels(0.5), 5, "half of the 9 iris pixels, rounded up")
	assert_eq(BodyMarks.iris_pixels(0.0), 0)
	assert_eq(BodyMarks.iris_pixels(0.01), 1)
	assert_eq(BodyMarks.iris_pixels(1.0), 9)
	assert_false(marks.has_mark(body), "the closed eye is not shown")
	body.stealth_state = HIDDEN
	marks.tick()
	assert_true(marks.has_mark(body), "hidden: the closed eye")
	assert_false(marks.has_open_eye(body), "and the open eye is not shown while the closed one is")
	body.stealth_state = VISIBLE
	body.spot_meter.clear()
	body.net._physics_process(DT)
	marks.tick()
	assert_false(marks.has_open_eye(body), "it goes at 0")
	assert_eq(marks.eye_fill(body), 0.0)


# --- the loudhailer ---------------------------------------------------------------------------------

func test_the_loudhailer_calls_a_formal_spanish_alert_line_and_then_a_give_up_line() -> void:
	await _start(NIGHT_S)
	_clock(patrol.horizon_warning_s + 5.0)
	_look().step(0.0)
	assert_eq(_look().lines_shown, 0)
	brain.spot(body, &"sight")
	assert_eq(boat.alert_serial, 1)
	_look().step(0.0)
	assert_eq(_look().lines_shown, 1)
	var bubble := boat.get_node_or_null(NodePath(CoopSession.BUBBLE_NAME)) as SpeechBubble
	assert_not_null(bubble, "a speech bubble over the boat")
	assert_true(patrol.alert_lines_es.has(bubble.text), "one of the boat's Spanish alert lines")
	assert_eq(bubble.text, patrol.alert_lines_es[1 % patrol.alert_lines_es.size()], "picked by alert_serial mod the count")
	assert_false(bubble.text.contains("pa'"), "the loudhailer is official: formal Spanish")
	assert_eq(bubble.show_s, 3.0)
	bubble._process(2.9)
	assert_false(bubble.is_queued_for_deletion(), "still there at 2.9 s")
	bubble._process(0.2)
	assert_true(bubble.is_queued_for_deletion(), "gone after 3 s")
	# The give-up: hidden, the lock breaks, 20 s of searching, then the boat resumes its lap.
	body.stealth_state = HIDDEN
	_run(22.0)
	assert_eq(boat.state_name(), &"LAP")
	assert_eq(boat.alert_serial, 2)
	_look().step(0.0)
	assert_eq(_look().lines_shown, 2)
	assert_eq(_look().last_line, patrol.give_up_lines_es[2 % patrol.give_up_lines_es.size()], "a give-up line")


func test_the_line_is_picked_by_serial_and_alert_state_in_the_sessions_language() -> void:
	var data := PatrolData.new()
	data.alert_lines_es = PackedStringArray(["a0", "a1", "a2"])
	data.alert_lines_en = PackedStringArray(["e0", "e1", "e2"])
	data.give_up_lines_es = PackedStringArray(["g0", "g1"])
	data.give_up_lines_en = PackedStringArray(["h0", "h1"])
	assert_eq(PatrolLook.line_for(data, "es", true, 4), "a1", "4 mod 3")
	assert_eq(PatrolLook.line_for(data, "es", false, 4), "g0", "4 mod 2")
	assert_eq(PatrolLook.line_for(data, "en", true, 5), "e2")
	assert_eq(PatrolLook.line_for(data, "en", false, 5), "h1")
	assert_eq(PatrolLook.line_for(PatrolData.new(), "es", true, 1), "", "no lines, no bubble")


func test_the_cues_have_no_text_of_their_own() -> void:
	var data := load("res://resources/creatures/patrol_boat.tres") as CreatureData
	assert_eq(PatrolLook.line_for(data.patrol, "es", true, 1), data.patrol.alert_lines_es[1], "the loudhailer's words are PatrolData's")
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child_autofree(hud)
	assert_eq(hud.patrol_horizon.find_children("*", "Label", true, false).size(), 0, "the horizon mark has no label")
	assert_eq(hud.marks.find_children("*", "Label", true, false).size(), 0, "the eyes have no label")


# --- the look ---------------------------------------------------------------------------------------

func test_the_look_draws_a_hull_and_a_cone_rotated_to_the_beam_only_while_the_light_is_on() -> void:
	await _start(NIGHT_S)
	var look: PatrolLook = _look()
	assert_false(look.hull_visible, "no hull on the horizon")
	assert_false(look.light.visible)
	_clock(patrol.horizon_warning_s + 10.0)
	look.step(0.0)
	assert_true(look.hull_visible, "the hull in its lap")
	assert_true(boat.light_on)
	assert_true(look.light.visible, "the light is on at night")
	assert_almost_eq(look.light.rotation, deg_to_rad(boat.beam), 0.0001, "rotated to the beam")
	assert_true(look.light is PointLight2D)
	assert_eq(look.light.texture.get_width(), 160, "10 tiles long")
	assert_eq(look.light.offset.x, 80.0, "its apex on the boat")
	assert_gt(look.light.energy, 0.0)
	# The same lap by day: the hull, no light.
	WeatherManager.sky.start_at(DAY_S)
	spawner.apply_phase(WeatherManager.phase())
	boat.advance(0.1)
	look.step(0.0)
	assert_false(boat.light_on)
	assert_true(look.hull_visible)
	assert_false(look.light.visible, "no beam by day")


func test_the_cone_texture_is_a_60_degree_10_tile_wedge() -> void:
	var cone: ImageTexture = PatrolCone.texture(60.0, 10.0)
	assert_eq(cone.get_width(), 160)
	var image: Image = cone.get_image()
	var middle: int = image.get_height() / 2
	assert_gt(image.get_pixel(100, middle).r, 0.4, "lit on the axis")
	assert_lt(image.get_pixel(5, middle - 20).r, 0.01, "dark outside 30 degrees near the boat")
	var edge_y: int = middle + int(100.0 * tan(deg_to_rad(35.0)))
	assert_lt(image.get_pixel(100, edge_y).r, 0.01, "dark 35 degrees off the axis")
	var inside_y: int = middle + int(100.0 * tan(deg_to_rad(20.0)))
	assert_gt(image.get_pixel(100, inside_y).r, 0.3, "lit 20 degrees off the axis")
	assert_lt(image.get_pixel(159, middle + 30).r, 0.01, "dark beyond the range")
	assert_same(PatrolCone.texture(60.0, 10.0), cone, "built once")
	assert_ne(PatrolCone.texture(45.0, 10.0), cone, "a retuned cone gets its own texture")


func test_a_creature_that_is_not_a_patrol_boat_draws_nothing_of_the_patrol_look() -> void:
	var crab := Creature.make(GameState.content.get_entry(&"creatures", &"land_crab") as CreatureData)
	add_child_autofree(crab)
	var look := crab.get_node(^"PatrolLook") as PatrolLook
	look.step(0.0)
	assert_false(look.hull_visible)
	assert_null(look.light)


# --- host plus client ----------------------------------------------------------------------------------

func _setup(for_session: CoopSession) -> void:
	for_session.terrain = IslandLayout.build(LAYOUT).terrain


func _hud(for_session: CoopSession) -> RunHud:
	var hud := HUD_SCENE.instantiate() as RunHud
	add_child(hud)
	huds.append(hud)
	hud.bind(for_session, net.peer_id(for_session), false)
	return hud


# The host's spawner on the sandbar at night for one player; its boat, with its physics off (the test
# sets the clock) and the spawner's too.
func _spawn_boat(host: CoopSession) -> Creature:
	WeatherManager.sky.start_at(NIGHT_S)
	spawner = CreatureSpawner.new()
	spawner.name = SandbarIsland.CREATURES_NAME
	host.add_child(spawner)
	spawner.setup(host, LAYOUT)
	spawner.party_size = 1
	spawner.world.phase = NIGHT
	spawner.world.weather_override = GameState.content.get_entry(&"weather", &"calm") as WeatherData
	spawner.spawn_permanent()
	var made: Creature = spawner.creatures(&"patrol_boat")[0]
	made.set_physics_process(false)
	spawner.set_physics_process(false)
	brain = made.brain as PatrolRoute
	patrol = made.data.patrol
	return made


func _lap_at(creature: Creature, lap_s: float) -> void:
	brain.set_clock(patrol.horizon_warning_s + lap_s)
	creature.advance(0.0)


func _theirs(client: CoopSession, creature: Creature) -> Creature:
	return client.entities.get_node_or_null(NodePath(creature.name)) as Creature


func _client_has(client: CoopSession, creature: Creature) -> bool:
	return await wait_until(func() -> bool: return _theirs(client, creature) != null, TIMEOUT_S)


# The host and the client share one scene tree here, so the host's world would also see the client
# branch's copies of the bodies (a real host sees only its own). The copies leave the players group.
func _client_bodies_are_not_players(client: CoopSession) -> void:
	for peer: int in client.peer_ids():
		client.body(peer).remove_from_group(PlayerBody.GROUP)


func test_both_peers_show_the_horizon_light_for_the_warning_and_not_once_the_lap_starts() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	var host_hud: RunHud = _hud(host)
	var client_hud: RunHud = _hud(client)
	var made: Creature = _spawn_boat(host)
	_clock_of(made, 5.0)
	assert_true(await _client_has(client, made))
	var both := func() -> bool: return host_hud.patrol_horizon.mark_count() == 1 and client_hud.patrol_horizon.mark_count() == 1
	assert_true(await wait_until(both, TIMEOUT_S), "a mark on both peers' bands during the horizon")
	assert_false(host_hud.patrol_horizon.is_hull(0), "a light at night")
	assert_false(client_hud.patrol_horizon.is_hull(0))
	_lap_at(made, 1.0)
	var neither := func() -> bool: return host_hud.patrol_horizon.mark_count() == 0 and client_hud.patrol_horizon.mark_count() == 0
	assert_true(await wait_until(neither, TIMEOUT_S), "gone on both once the lap starts")


# The boat's clock at `seconds` into its whole loop (not its lap), settled.
func _clock_of(creature: Creature, seconds: float) -> void:
	brain.set_clock(seconds)
	creature.advance(0.0)


# A sand cell the held boat's light covers (BEACH, no roof), in reading order; the centre in pixels.
func _lit_sand(creature: Creature, terrain: GridTerrain) -> Vector2:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in terrain.cells:
		if terrain.cells[cell] == DataEnums.Terrain.BEACH and not terrain.shaded.has(cell):
			cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in cells:
		var centre: Vector2 = IslandLayout.cell_center(cell)
		var tiles: float = creature.position.distance_to(centre) / TILE
		if tiles >= 4.0 and tiles <= 8.0 and brain.lights(centre):
			return centre
	return Vector2(-1.0, -1.0)


func _hold_light_on_sand(creature: Creature, terrain: GridTerrain) -> Dictionary:
	for lap_s: float in [5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0]:
		_lap_at(creature, lap_s)
		var sand: Vector2 = _lit_sand(creature, terrain)
		if sand.x >= 0.0:
			return {"sand": sand, "lap_s": lap_s}
	return {}


func test_both_peers_show_the_open_eye_half_filled_at_1_s_and_not_once_the_meter_is_back_at_0() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	_client_bodies_are_not_players(client)
	var host_hud: RunHud = _hud(host)
	var client_hud: RunHud = _hud(client)
	var made: Creature = _spawn_boat(host)
	var held: Dictionary = _hold_light_on_sand(made, host.terrain as GridTerrain)
	assert_false(held.is_empty(), "the sandbar has open sand the light reaches")
	var id: int = net.peer_id(client)
	host.body(id).global_position = held["sand"]
	host.body(CoopSession.HOST_ID).global_position = Vector2(8.0, 8.0)
	await wait_seconds(0.5)
	host.body(id).spot_meter.clear()
	var lap_s: float = held["lap_s"]
	for i: int in 60:
		await wait_physics_frames(1)
		_lap_at(made, lap_s)
		spawner.watch.step(DT)
	assert_almost_eq(host.body(id).spot_meter.value, 1.0, 0.02, "lit for 1 s")
	var shown := func() -> bool:
		return host_hud.marks.has_open_eye(host.body(id)) and client_hud.marks.has_open_eye(client.body(id))
	assert_true(await wait_until(shown, TIMEOUT_S), "the open eye shows over the lit player on both peers")
	# The client may still hold the sync before last (the spec allows one sync interval of lag), so wait
	# for it to catch up with the host's held value rather than reading the first frame it shows an eye.
	var caught_up := func() -> bool:
		return absf(client_hud.marks.eye_fill(client.body(id)) - host_hud.marks.eye_fill(host.body(id))) <= 0.02
	assert_true(await wait_until(caught_up, TIMEOUT_S), "the client's eye catches up with the host's")
	assert_almost_eq(host_hud.marks.eye_fill(host.body(id)), 0.5, 0.02, "half filled on the host")
	assert_almost_eq(client_hud.marks.eye_fill(client.body(id)), 0.5, 0.02, "and on the client")
	assert_false(host_hud.marks.has_open_eye(host.body(CoopSession.HOST_ID)), "none over the player who is not lit")
	assert_false(client_hud.marks.has_open_eye(client.body(CoopSession.HOST_ID)))
	assert_false(host_hud.marks.has_mark(host.body(id)), "the closed eye is not shown")
	# The boat moves on to dark water: the meter drains at 0.5 per second and the eyes go.
	_lap_at(made, 5.0 if lap_s > 40.0 else 85.0)
	assert_false(brain.lights(held["sand"]), "the light has left the sand")
	for i: int in 150:
		await wait_physics_frames(1)
		spawner.watch.step(DT)
	assert_almost_eq(host.body(id).spot_meter.value, 0.0, 0.0001)
	var gone := func() -> bool:
		return not host_hud.marks.has_open_eye(host.body(id)) and not client_hud.marks.has_open_eye(client.body(id))
	assert_true(await wait_until(gone, TIMEOUT_S), "gone on both peers at 0")


func test_both_peers_show_the_same_loudhailer_line_at_an_alerts_start_and_end() -> void:
	var host := net.add_host(_setup)
	var client := await net.join(_setup)
	_client_bodies_are_not_players(client)
	var made: Creature = _spawn_boat(host)
	_lap_at(made, 5.0)
	assert_true(await _client_has(client, made))
	var theirs: Creature = _theirs(client, made)
	var host_look := made.get_node(^"PatrolLook") as PatrolLook
	var client_look := theirs.get_node(^"PatrolLook") as PatrolLook
	await wait_seconds(0.3)
	host_look.step(0.0)
	client_look.step(0.0)
	var player: PlayerBody = host.body(CoopSession.HOST_ID)
	brain.spot(player, &"sight")
	assert_eq(made.alert_serial, 1)
	var alerted := func() -> bool: return client_look.lines_shown == 1 and theirs.state_name() == &"ALERT_LOCK"
	await wait_until(alerted, TIMEOUT_S)
	host_look.step(0.0)
	client_look.step(0.0)
	assert_eq(host_look.lines_shown, 1)
	assert_eq(client_look.lines_shown, 1)
	assert_eq(client_look.last_line, host_look.last_line, "the same line on both peers")
	assert_true(patrol.alert_lines_es.has(client_look.last_line), "a Spanish alert line")
	# The lock breaks and the 20 s search is run out: the give-up line.
	brain.forget_lock()
	brain._search_s = patrol.alert_s - 0.05
	made.advance(0.1)
	assert_eq(made.alert_serial, 2)
	var ended := func() -> bool: return theirs.alert_serial == 2 and theirs.state_name() == &"LAP"
	assert_true(await wait_until(ended, TIMEOUT_S))
	host_look.step(0.0)
	client_look.step(0.0)
	assert_eq(host_look.lines_shown, 2)
	assert_eq(client_look.lines_shown, 2)
	assert_eq(client_look.last_line, host_look.last_line, "the same give-up line on both peers")
	assert_true(patrol.give_up_lines_es.has(client_look.last_line), "a give-up line")


func test_a_client_joining_mid_lap_draws_the_boat_and_its_cone_in_place_on_its_first_frame() -> void:
	var host := net.add_host(_setup)
	var made: Creature = _spawn_boat(host)
	_lap_at(made, 40.0)
	var first: Dictionary = {}
	var on_ready := func(creature: Creature) -> void:
		var look := creature.get_node(^"PatrolLook") as PatrolLook
		look.step(0.0)
		first["hull"] = look.hull_visible
		first["light_visible"] = look.light.visible
		first["rotation"] = look.light.rotation
		first["beam"] = made.beam
		first["lines"] = look.lines_shown
	var catch_first := func(node: Node) -> void:
		var creature := node as Creature
		if creature != null and creature.name == made.name:
			creature.ready.connect(on_ready.bind(creature), CONNECT_ONE_SHOT)
	net.add_client(func(for_session: CoopSession) -> void:
		_setup(for_session)
		for_session.entities.child_entered_tree.connect(catch_first))
	assert_true(await wait_until(func() -> bool: return not first.is_empty(), TIMEOUT_S), "the boat reached the client")
	assert_true(first["hull"], "the hull is drawn")
	assert_true(first["light_visible"], "and the cone is on")
	assert_lte(absf(wrapf(rad_to_deg(float(first["rotation"])) - float(first["beam"]), -180.0, 180.0)), 3.0, "at the host's aim")
	assert_eq(first["lines"], 0, "a joiner says no line for an alert already under way")
