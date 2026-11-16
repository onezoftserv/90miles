extends GutTest
## guardacostas-stealth "Hidden states" with exactly 1 player, offline: a real sandbar run through
## the game shell, the player driven by the named input actions alone (move_*), as test_inventory_hud_
## solo_run.gd does. Walking into the hut makes their stealth state hidden and puts the closed-eye
## mark over them (BodyMarks.has_mark); walking out onto sand removes both. Frames are stepped by
## hand in the engine's order at 30 Hz, so the run is exact and fast.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://test_hidden_solo_settings.cfg"
const DT: float = 1.0 / 30.0
const TILE: float = 16.0
const AT_TARGET_PX: float = 3.0
const AT_WAYPOINT_PX: float = 3.0
const STEER_PX: float = 1.0
const FRAMES_PER_PX: float = 2.0
const MIN_WALK_FRAMES: int = 120
const MOVES: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]

var shell: GameShell
var session: CoopSession
var island: SandbarIsland
var body: PlayerBody
var hud: RunHud
var land: AStarGrid2D
var _pressed: Dictionary[StringName, bool] = {}


func before_each() -> void:
	NetManager.start_solo()
	WeatherManager.stop()
	WeatherManager.sky.start_at(0.0)


func after_each() -> void:
	for action: StringName in _pressed.keys():
		_act(action, false)
	_pressed.clear()
	WeatherManager.sky.weather.rolls_enabled = true
	WeatherManager.stop()
	NetManager.leave()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


# One 30 Hz frame in the engine's order: the input to an intent, the host stepping the body, then
# the HUD and the marks.
func _frame() -> void:
	body.player_input._physics_process(DT)
	body.net._physics_process(DT)
	body._physics_process(DT)
	WeatherManager._process(DT)
	hud._process(DT)
	(body.get_node(^"BodyLook") as BodyLook)._process(DT)
	hud.marks._process(DT)


func _frames(count: int) -> void:
	for i: int in count:
		_frame()


func _act(action: StringName, pressed: bool) -> void:
	if _pressed.get(action, false) == pressed:
		return
	_pressed[action] = pressed
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _build_land() -> void:
	land = AStarGrid2D.new()
	land.region = Rect2i(Vector2i.ZERO, island.built.size)
	land.cell_size = Vector2.ONE
	land.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	land.update()
	for y: int in island.built.size.y:
		for x: int in island.built.size.x:
			var cell := Vector2i(x, y)
			land.set_point_solid(cell, TerrainQuery.is_water(island.terrain.terrain_at(cell)))


func _cell_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / TILE), floori(at.y / TILE))


func _steer(toward: Vector2) -> void:
	var gap: Vector2 = toward - body.global_position
	_act(&"move_right", gap.x > STEER_PX)
	_act(&"move_left", gap.x < -STEER_PX)
	_act(&"move_down", gap.y > STEER_PX)
	_act(&"move_up", gap.y < -STEER_PX)


func _stop() -> void:
	for action: StringName in MOVES:
		_act(action, false)


# Walks over land, cell centre to cell centre, to the middle of `goal_cell`, holding only the move
# actions. Returns false if it took too long.
func _walk_to(goal_cell: Vector2i) -> bool:
	var goal: Vector2 = IslandLayout.cell_center(goal_cell)
	var path := land.get_id_path(_cell_of(body.global_position), goal_cell)
	var waypoints: Array[Vector2] = []
	for i: int in range(1, path.size() - 1):
		waypoints.append(IslandLayout.cell_center(path[i]))
	waypoints.append(goal)
	var budget: int = maxi(MIN_WALK_FRAMES, ceili(body.global_position.distance_to(goal) * FRAMES_PER_PX * 2.0))
	for i: int in waypoints.size():
		var tolerance: float = AT_TARGET_PX if i == waypoints.size() - 1 else AT_WAYPOINT_PX
		while body.global_position.distance_to(waypoints[i]) > tolerance:
			_steer(waypoints[i])
			_frame()
			budget -= 1
			if budget <= 0:
				_stop()
				return false
	_stop()
	_frame()
	return true


func _start() -> void:
	shell = SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child_autofree(shell)
	(shell.screen as TitleScreen).solo_requested.emit()
	session = shell.session
	island = shell.island
	body = session.body(CoopSession.HOST_ID)
	hud = shell.hud
	WeatherManager.sky.weather.rolls_enabled = false
	_build_land()


func _marked() -> bool:
	return hud.marks.has_mark(body)


func test_a_solo_player_is_hidden_in_the_hut_and_visible_outside_it() -> void:
	_start()
	await wait_physics_frames(2)
	assert_true(session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "offline: no port opened")
	var huts := island.built.hut_cells
	assert_gt(huts.size(), 0, "the sandbar has a hut")
	var open_cell: Vector2i = island.built.solo_spawn

	# The landing: open sand, upright, visible, no mark.
	assert_false(island.terrain.is_shaded(open_cell))
	assert_false(TerrainQuery.is_brush(island.terrain.terrain_at(open_cell)), "the landing is not brush")
	_frames(3)
	assert_eq(body.stealth_state, MovementStep.Stealth.VISIBLE, "standing on the landing")
	assert_false(_marked(), "no mark on open sand")

	# Into the hut: roofed, so hidden standing upright, with the closed eye over them.
	var hut_cell: Vector2i = huts[huts.size() / 2]
	assert_true(_walk_to(hut_cell), "the player walked to the hut")
	_frames(3)
	assert_true(island.terrain.is_shaded(body.cell()), "standing on a roofed cell")
	assert_eq(body.stealth_state, MovementStep.Stealth.HIDDEN, "hidden in the hut")
	assert_true(_marked(), "the closed-eye mark shows in the hut")

	# Out again, onto sand: visible and unmarked.
	assert_true(_walk_to(open_cell), "the player walked back out")
	_frames(3)
	assert_false(island.terrain.is_shaded(body.cell()))
	assert_eq(body.stealth_state, MovementStep.Stealth.VISIBLE, "visible outside")
	assert_false(_marked(), "no mark outside")
	await wait_physics_frames(2)
