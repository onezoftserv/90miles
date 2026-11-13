extends SceneTree
## Manual playthrough for art-pass tasks 4.6, 5.8, 6.5, 7.5, 8.5, 9.3 and 10.1-10.3: it boots the
## real game shell and plays it by input actions only, as a player would, and reads what the art
## nodes draw. Windowed (never in CI) it can save captures; headless it skips the pixel checks:
##   godot --path game -s res://tests/manual/art_pass_run.gd -- --mode=solo [--capture=<dir>]
##   godot --headless --path game -s res://tests/manual/art_pass_run.gd -- --mode=host
##   godot --headless --path game -s res://tests/manual/art_pass_run.gd -- --mode=client --port=<n> [--host-tiles=<hash>]
## The host listens on port 0 and prints "ARTRUN host listening <port>"; the client is given that
## port. Each check prints "ARTRUN PASS|FAIL <what> | <detail>", and the run quits non-zero on a
## fail. Where a step needs game time, weather or materials the run cannot reach by playing, it is
## set through the same hooks the GUT tests use and printed as "ARTRUN set <what>".
## Compiled before the autoloads exist, so it names no project class: duck typing throughout, and
## the project's scripts are loaded at run time for their constants and static functions.

const SHELL_PATH: String = "res://scenes/shell/game_shell.tscn"
const POSE_PATH: String = "res://scripts/art/player_pose.gd"
const STRUCTURE_ART_PATH: String = "res://scripts/art/structure_art.gd"
const PLAN_PATH: String = "res://scripts/crossing/crossing_plan.gd"
const BEAT_PATH: String = "res://scripts/crossing/crossing_beat.gd"
const DRAW_ORDER_PATH: String = "res://tests/helpers/draw_order.gd"
const FLOW_TITLE: int = 0
const FLOW_RUN: int = 3
const FLOW_CREDITS: int = 7
const CREDITS_INDEX: int = 4
const TILE: float = 16.0
const BASE_SIZE: Vector2i = Vector2i(640, 360)
## DataEnums.Terrain: DEEP, SHALLOWS and BRACKISH are water; CLIFF is never walked.
const WATER_KINDS: Array[int] = [0, 1, 2]
const DEEP: int = 0
const CLIFF: int = 13
## DayClock: day starts at 60 s, night at 420 s.
const DAY_S: float = 120.0
const NIGHT_START_S: float = 420.0
## Crossing.Rider
const ABOARD: int = 0
const IN_WATER: int = 2
const STEER_PX: float = 1.0
const AT_PX: float = 3.0
const MOVES: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
const DEADLINE_S: float = 2700.0
const CLIENT_NAME: String = "Papo"
## The integrity the host sets on its raft before it leaves, which a late client must see.
const HOST_RAFT_INTEGRITY: float = 60.0
## Seconds the client waits after leaving before it joins the host's crossing again.
const REJOIN_AFTER_S: float = 5.0
## The solo crossing: a squall throws the rider in, then the shark passes.
const CROSSING_S: float = 30.0
const SQUALL_AT_S: float = 3.0
const SHARK_AT_S: float = 12.0


class Collector extends Logger:
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []
	var _lock: Mutex = Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		_lock.lock()
		var text: String = "%s:%d (%s) %s %s" % [file, line, function, code, rationale]
		if error_type == ERROR_TYPE_WARNING:
			warnings.append(text)
		else:
			errors.append(text)
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func error_list() -> PackedStringArray:
		_lock.lock()
		var copy: PackedStringArray = errors.duplicate()
		_lock.unlock()
		return copy

	func warning_list() -> PackedStringArray:
		_lock.lock()
		var copy: PackedStringArray = warnings.duplicate()
		_lock.unlock()
		return copy


var collector: Collector = Collector.new()
var mode: String = "solo"
var port: int = 0
var host_tiles: String = ""
var capture_dir: String = ""
var shell: Node = null
var session: Node = null
var island: Node2D = null
var hud: Node = null
var strip: Control = null
var prompt: Control = null
var craft_list: Control = null
var body: Node2D = null
var land: AStarGrid2D = null
var passes: int = 0
var fails: int = 0
var done: bool = false
var physics_hz: int = 60
var pose_names: Array = []
var structure_art: Script = null
var draw_order: Script = null


func _init() -> void:
	OS.add_logger(collector)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--capture="):
			capture_dir = arg.trim_prefix("--capture=")
		elif arg.begins_with("--host-tiles="):
			host_tiles = arg.trim_prefix("--host-tiles=")
	physics_hz = Engine.physics_ticks_per_second
	pose_names = ((load(POSE_PATH) as Script).get_script_constant_map()["Pose"] as Dictionary).keys()
	structure_art = load(STRUCTURE_ART_PATH)
	draw_order = load(DRAW_ORDER_PATH)
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
	var settings_path: String = "user://art_pass_run_%s.cfg" % mode
	var config := ConfigFile.new()
	config.set_value("player", "name", CLIENT_NAME if mode == "client" else "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", 2)
	config.set_value("display", "pixel_filter", 0)
	config.save(settings_path)
	shell = (load(SHELL_PATH) as PackedScene).instantiate()
	shell.set("settings_path", settings_path)
	root.add_child(shell)
	create_timer(DEADLINE_S).timeout.connect(_on_deadline)
	_main()


func _main() -> void:
	await process_frame
	await process_frame
	print("ARTRUN art_pass_run mode %s, pid %d, rendering %s" % [mode, OS.get_process_id(), _rendering()])
	if mode == "solo":
		await _solo()
	elif mode == "host":
		await _host()
	elif mode == "client":
		await _client()
	else:
		_check("known mode", false, mode)
	await _finish()


func _on_deadline() -> void:
	if done:
		return
	_check("finished before the %d s deadline" % int(DEADLINE_S), false)
	_report_and_quit()


# --- checks, input and time ----------------------------------------------------------------------

func _check(label: String, ok: bool, detail: String = "") -> bool:
	if ok:
		passes += 1
	else:
		fails += 1
	print("ARTRUN %s %s%s" % ["PASS" if ok else "FAIL", label, (" | " + detail) if not detail.is_empty() else ""])
	return ok


func _note(text: String) -> void:
	print("ARTRUN note %s" % text)


# A step the run cannot reach by playing, set through a test hook.
func _hooked(text: String) -> void:
	print("ARTRUN set %s" % text)


# The game's one sky (WeatherManager.sky), made in the autoload's _ready.
func _sky() -> Object:
	return root.get_node(^"WeatherManager").get("sky")


func _rendering() -> bool:
	return DisplayServer.get_name() != "headless"


func _frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(ceili(seconds * physics_hz))


func _event(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap(action: StringName) -> void:
	_event(action, true)
	await _frames(2)
	_event(action, false)
	await _frames(2)


func _hold(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await _seconds(seconds)
	Input.action_release(action)
	await _frames(2)


# --- the title, the credits and the run -----------------------------------------------------------

func _credits_visit() -> void:
	await _frames(4)
	var title: Control = shell.get("screen")
	if not _check("the game opens on the title", title != null and shell.get("flow") == FLOW_TITLE):
		return
	for i: int in CREDITS_INDEX:
		await _tap(&"ui_down")
	var buttons: Array = title.call("buttons")
	_check("four downs focus Créditos", root.gui_get_focus_owner() == buttons[CREDITS_INDEX], str(root.gui_get_focus_owner()))
	await _tap(&"ui_accept")
	await _frames(6)
	var screen: Control = shell.get("screen")
	_check("Enter on Créditos opens the credits screen", shell.get("flow") == FLOW_CREDITS and screen != null, "flow %s" % shell.get("flow"))
	var texts: Array = screen.call("entry_texts") if screen != null and screen.has_method("entry_texts") else []
	_check("the credits list its packs", texts.size() >= 3, "%d lines" % texts.size())
	await _save_window("credits_visit")
	await _tap(&"ui_cancel")
	await _frames(6)
	title = shell.get("screen")
	_check("Esc returns to the title", shell.get("flow") == FLOW_TITLE and title != null)
	_check("Jugar solo has focus again", title != null and root.gui_get_focus_owner() == (title.call("buttons") as Array)[0], str(root.gui_get_focus_owner()))


func _wait_run(timeout_s: float) -> bool:
	for i: int in ceili(timeout_s * physics_hz):
		if shell.get("flow") == FLOW_RUN and shell.get("hud") != null and shell.get("session") != null:
			session = shell.get("session")
			var found: Variant = session.call("body", session.multiplayer.get_unique_id())
			if found != null:
				body = found
				island = shell.get("island")
				hud = shell.get("hud")
				strip = hud.get("strip")
				prompt = hud.get("prompt")
				craft_list = hud.get("craft_list")
				return true
		await physics_frame
	return false


# Daylight past the dawn blend, and no weather rolls, so the colours are the art's own.
func _set_day(why: String) -> void:
	_sky().call("start_at", DAY_S)
	(_sky().get("weather") as Object).set("rolls_enabled", false)
	_hooked("day clock to %.0f s, weather rolls off (%s)" % [DAY_S, why])


# --- reading the world ----------------------------------------------------------------------------

func _terrain() -> Object:
	return island.get("terrain")


func _kind(cell: Vector2i) -> int:
	var size: Vector2i = (island.get("built") as Object).get("size")
	if not Rect2i(Vector2i.ZERO, size).has_point(cell):
		return DEEP
	return int(_terrain().call("terrain_at", cell))


func _is_water(cell: Vector2i) -> bool:
	return WATER_KINDS.has(_kind(cell))


func _build_land() -> void:
	var size: Vector2i = (island.get("built") as Object).get("size")
	land = AStarGrid2D.new()
	land.region = Rect2i(Vector2i.ZERO, size)
	land.cell_size = Vector2.ONE
	land.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	land.update()
	for y: int in size.y:
		for x: int in size.x:
			var kind: int = _kind(Vector2i(x, y))
			land.set_point_solid(Vector2i(x, y), WATER_KINDS.has(kind) or kind == CLIFF)


func _cell_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / TILE), floori(at.y / TILE))


func _center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE


func _look_of(node: Node) -> Node:
	return node.get_node_or_null(^"Look")


func _pose() -> String:
	var look: Node = _look_of(body)
	return "?" if look == null else str(pose_names[int(look.get("pose"))])


func _creatures(id: StringName) -> Array[Node2D]:
	var found: Array[Node2D] = []
	var entities: Node = session.get_node_or_null(^"Entities")
	if entities == null:
		return found
	for child: Node in entities.get_children():
		var data: Object = child.get("data")
		if data != null and data.get("id") == id and not child.is_queued_for_deletion():
			found.append(child as Node2D)
	return found


func _state_of(creature: Node) -> String:
	var brain: Object = creature.get("brain")
	if brain == null:
		return ""
	var names: Array = brain.call("names")
	var id: int = int(creature.get("state_id"))
	return String(names[id]).to_lower() if id >= 0 and id < names.size() else ""


func _creature_anim(creature: Node) -> String:
	var sprite: AnimatedSprite2D = _look_of(creature).get_node(^"Sprite")
	return String(sprite.animation) if sprite.visible else "<hidden>"


func _nearest(nodes: Array, from: Vector2) -> Node2D:
	var best: Node2D = null
	for node: Variant in nodes:
		var item: Node2D = node as Node2D
		if item != null and (best == null or from.distance_to(item.global_position) < from.distance_to(best.global_position)):
			best = item
	return best


func _count(item_id: StringName) -> int:
	return int(body.get("inventory").call("count_id", item_id))


func _slot_of(item_id: StringName) -> int:
	var slots: Array = body.get("inventory").get("slots")
	for i: int in slots.size():
		if (slots[i] as Object).get("item_id") == item_id:
			return i
	return -1


func _prompt_lines() -> PackedStringArray:
	return prompt.call("lines")


func _item_data(item_id: StringName) -> Object:
	return (root.get_node(^"GameState").get("content") as Object).call("get_entry", &"items", item_id)


func _frame(node: Node) -> String:
	var look: Node = _look_of(node)
	return "<no look>" if look == null else String(look.call("frame"))


# --- walking --------------------------------------------------------------------------------------

func _steer(toward: Vector2) -> void:
	var gap: Vector2 = toward - body.global_position
	_hold_move(&"move_right", gap.x > STEER_PX)
	_hold_move(&"move_left", gap.x < -STEER_PX)
	_hold_move(&"move_down", gap.y > STEER_PX)
	_hold_move(&"move_up", gap.y < -STEER_PX)


func _hold_move(action: StringName, pressed: bool) -> void:
	if pressed and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not pressed and Input.is_action_pressed(action):
		Input.action_release(action)


func _stop() -> void:
	for action: StringName in MOVES:
		Input.action_release(action)


# Walks over land, cell centre to cell centre, holding only the move actions.
func _walk_to(goal: Vector2, within: float = AT_PX) -> bool:
	var start: Vector2 = body.global_position
	var path: Array[Vector2i] = land.get_id_path(_cell_of(start), _cell_of(goal), true)
	var waypoints: Array[Vector2] = []
	for i: int in range(1, path.size() - 1):
		waypoints.append(_center(path[i]))
	waypoints.append(goal)
	return await _follow(waypoints, within, "walk from %s to %s" % [start, goal])


# Steers straight through `waypoints` (water included).
func _follow(waypoints: Array[Vector2], within: float, label: String) -> bool:
	var budget: int = maxi(physics_hz * 6, ceili(body.global_position.distance_to(waypoints[-1]) * 8.0) + waypoints.size() * physics_hz)
	var used: int = 0
	for i: int in waypoints.size():
		var tolerance: float = within if i == waypoints.size() - 1 else AT_PX + 1.0
		while body.global_position.distance_to(waypoints[i]) > tolerance:
			_steer(waypoints[i])
			await physics_frame
			used += 1
			if used >= budget:
				_stop()
				_note("%s stopped at %s after %d frames" % [label, body.global_position, used])
				return false
	_stop()
	await _frames(2)
	return true


# --- captures and pixels --------------------------------------------------------------------------

# The world view as rendered now (640x360), saved as <name>.png when --capture is set; null headless.
func _world_image(name: String = "") -> Image:
	if not _rendering():
		return null
	await RenderingServer.frame_post_draw
	var viewport: SubViewport = shell.get("world_viewport")
	var image: Image = viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	if not name.is_empty() and not capture_dir.is_empty():
		var path: String = capture_dir.path_join(name + ".png")
		_note("captured %s (%s)" % [path, error_string(image.save_png(path))])
	return image


# What the window shows, at the window's size, saved as <name>.png when --capture is set.
func _save_window(name: String) -> Image:
	if not _rendering():
		return null
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var scale: int = maxi(1, int((shell.get("settings") as Object).get("ui_scale")))
	var size: Vector2i = BASE_SIZE * scale
	if image.get_size() != size:
		_note("%s: the window drew %s, enlarged to %s" % [name, image.get_size(), size])
		image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	if not capture_dir.is_empty():
		var path: String = capture_dir.path_join(name + ".png")
		_note("captured %s (%s)" % [path, error_string(image.save_png(path))])
	return image


func _magenta(image: Image) -> int:
	var data: PackedByteArray = image.get_data()
	var count: int = 0
	for i: int in range(0, data.size(), 4):
		if data[i] >= 230 and data[i + 2] >= 230 and data[i + 1] <= 40:
			count += 1
	return count


func _check_no_magenta(image: Image, what: String) -> void:
	if image != null:
		_check("no magenta pixel in %s" % what, _magenta(image) == 0, "%d magenta px" % _magenta(image))


# Each world-view pixel's class: 1 land with land all round, 2 water with water all round (deep
# sea away from the foam), 3 a shore cell (land with water beside it), 0 anything else.
func _classes(image: Image) -> PackedByteArray:
	var size: Vector2i = image.get_size()
	var classes := PackedByteArray()
	classes.resize(size.x * size.y)
	var to_island: Transform2D = island.get_global_transform_with_canvas().affine_inverse()
	var memo: Dictionary[Vector2i, int] = {}
	for y: int in size.y:
		for x: int in size.x:
			var cell: Vector2i = _cell_of(to_island * Vector2(x + 0.5, y + 0.5))
			if not memo.has(cell):
				memo[cell] = _cell_class(cell)
			classes[y * size.x + x] = memo[cell]
	return classes


func _cell_class(cell: Vector2i) -> int:
	var water: int = 0
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if _is_water(cell + Vector2i(dx, dy)):
				water += 1
	if water == 0:
		return 1
	if water == 9:
		return 2
	return 0 if _is_water(cell) else 3


func _mean(image: Image, classes: PackedByteArray, wanted: int) -> float:
	var data: PackedByteArray = image.get_data()
	var total: float = 0.0
	var count: int = 0
	for i: int in classes.size():
		if classes[i] == wanted:
			total += (data[i * 4] + data[i * 4 + 1] + data[i * 4 + 2]) / 765.0
			count += 1
	return total / count if count > 0 else -1.0


# Pixels of class `wanted` that differ between two images.
func _changed(a: Image, b: Image, classes: PackedByteArray, wanted: int) -> int:
	var da: PackedByteArray = a.get_data()
	var db: PackedByteArray = b.get_data()
	var count: int = 0
	for i: int in classes.size():
		if classes[i] == wanted and (da[i * 4] != db[i * 4] or da[i * 4 + 1] != db[i * 4 + 1] or da[i * 4 + 2] != db[i * 4 + 2]):
			count += 1
	return count


# Shore cells fully on screen: how many draw foam touching a land colour, and how many changed
# between two images (the foam moving). Foam is a blue-white pixel brighter than the land's mean,
# and land a pixel no bluer than it is red (sand, dune, brush and rock; the sea is blue); both hold
# under the day-night tint, which scales them alike.
func _foam(image: Image, later: Image) -> Dictionary:
	var size: Vector2i = image.get_size()
	var data: PackedByteArray = image.get_data()
	var after: PackedByteArray = later.get_data() if later != null else PackedByteArray()
	var classes: PackedByteArray = _classes(image)
	var bright: float = _mean(image, classes, 1) * 765.0
	var from_island: Transform2D = island.get_global_transform_with_canvas()
	var view := Rect2(Vector2.ZERO, Vector2(size))
	var shore: int = 0
	var touching: int = 0
	var moved: PackedInt32Array = []
	var bare: Array[Vector2i] = []
	var built_size: Vector2i = (island.get("built") as Object).get("size")
	for y: int in built_size.y:
		for x: int in built_size.x:
			var cell := Vector2i(x, y)
			if _cell_class(cell) != 3:
				continue
			var corner: Vector2 = from_island * (Vector2(cell) * TILE)
			if not view.encloses(Rect2(corner, Vector2(TILE, TILE))):
				continue
			shore += 1
			var touches: bool = false
			var changed: int = 0
			for py: int in int(TILE):
				for px: int in int(TILE):
					var at := Vector2i(floori(corner.x) + px, floori(corner.y) + py)
					var i: int = at.y * size.x + at.x
					if not after.is_empty() and (data[i * 4] != after[i * 4] or data[i * 4 + 1] != after[i * 4 + 1] or data[i * 4 + 2] != after[i * 4 + 2]):
						changed += 1
					var foam: bool = data[i * 4 + 2] > data[i * 4] + 20 and data[i * 4] + data[i * 4 + 1] + data[i * 4 + 2] > bright
					if touches or not foam:
						continue
					for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						var next: Vector2i = at + step
						if Rect2i(Vector2i.ZERO, size).has_point(next):
							var j: int = (next.y * size.x + next.x) * 4
							if data[j + 2] < data[j] + 12:
								touches = true
								break
			if touches:
				touching += 1
			else:
				bare.append(cell)
			moved.append(changed)
	return {"shore": shore, "touching": touching, "moved": moved, "bare": bare}


func _check_shore_view(where: String) -> void:
	var first: Image = await _world_image("shore_%s" % where)
	if first == null:
		_note("%s: headless, no pixel checks" % where)
		return
	_check_no_magenta(first, "the %s view" % where)
	await create_timer(0.25).timeout
	var second: Image = await _world_image()
	var foam: Dictionary = _foam(first, second)
	var shore: int = foam["shore"]
	var moved: PackedInt32Array = foam["moved"]
	var moving: int = 0
	var distinct: Dictionary[int, bool] = {}
	for changed: int in moved:
		if changed > 0:
			moving += 1
		distinct[changed] = true
	if shore == 0:
		_note("%s: no shore cell wholly in view" % where)
		return
	_check("%s: the foam touches the sand on every shore cell in view" % where, int(foam["touching"]) == shore, "%d of %d shore cells; without: %s" % [foam["touching"], shore, foam["bare"]])
	_check("%s: the foam moves, and unevenly (cells change by different amounts in 0.25 s)" % where, moving > 0 and distinct.size() > 1, "%d of %d shore cells changed, %d distinct amounts" % [moving, shore, distinct.size()])


# --- solo -----------------------------------------------------------------------------------------

func _solo() -> void:
	await _credits_visit()
	await _tap(&"ui_accept")
	if not _check("Jugar solo entered the run with a body and the HUD", await _wait_run(10.0)):
		return
	_check("solo is offline (no port opened)", session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)
	_check("the run starts on the sandbar", (island.get("layout") as Object).get("id") == &"sandbar")
	_build_land()
	_set_day("4.6 day captures")
	await _frames(30)
	var spawn: Vector2 = body.global_position
	var day: Image = await _world_image("sandbar_day_view")
	_check_no_magenta(day, "the sandbar by day")
	await _check_shore_view("spawn_day")
	await _crescent_walk("day")
	await _lean_to()
	await _pick_up_everything("sandbar")
	await _fire()
	await _rain_catcher()
	await _looks()
	await _shark_offshore()
	await _nest_palm_and_gull()
	await _raft()
	await _night(spawn, day)
	await _pause_check()
	await _crossing()
	await _coast_cay()
	await _binoculars_swim()


# The crescent's ends and middle, walked on foot, with the shore checked at each.
func _crescent_walk(when: String) -> void:
	var size: Vector2i = (island.get("built") as Object).get("size")
	var stops: Array[Vector2i] = []
	for target: Vector2i in [Vector2i(size.x * 2 / 3, size.y / 5), Vector2i(size.x / 3, size.y / 2), Vector2i(size.x * 2 / 3, size.y * 4 / 5)]:
		var best := Vector2i(-1, -1)
		for y: int in size.y:
			for x: int in size.x:
				var cell := Vector2i(x, y)
				if not land.is_point_solid(cell) and _cell_class(cell) == 3 and (best.x < 0 or Vector2(cell).distance_to(Vector2(target)) < Vector2(best).distance_to(Vector2(target))):
					best = cell
		stops.append(best)
	for i: int in stops.size():
		var where: String = "%s_%d" % [when, i]
		if _check("walked the crescent to shore stop %d by %s (cell %s)" % [i, when, stops[i]], await _walk_to(_center(stops[i]))):
			await _frames(10)
			await _check_shore_view(where)


func _lean_to() -> void:
	var shelter: Node2D = island.get_node_or_null(^"Shelter")
	if not _check("the sandbar has its lean-to", shelter != null):
		return
	var hut: Array = (island.get("built") as Object).get("hut_cells")
	var back: int = 1 << 30
	for cell: Vector2i in hut:
		back = mini(back, cell.y)
	var row: Array[Vector2i] = []
	for cell: Vector2i in hut:
		if cell.y == back:
			row.append(cell)
	row.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var spot: Vector2i = row[row.size() / 2]
	if not _check("walked into the lean-to's back row", await _walk_to(_center(spot))):
		return
	var tarp: Node2D = null
	for child: Node in session.get_node(^"Pickups").get_children():
		if child.get("item_id") == &"tarp":
			tarp = child
	_check("standing in the shade under the lean-to", (_terrain().get("shaded") as Dictionary).has(_cell_of(body.global_position)))
	_check("the player is drawn in front of the lean-to", draw_order.call("drawn_after", body, shelter))
	if tarp != null:
		_check("the tarp lies beside the player, in front of the lean-to", body.global_position.distance_to(tarp.global_position) <= TILE * 2.5 and draw_order.call("drawn_after", tarp, shelter), "%.1f px away" % body.global_position.distance_to(tarp.global_position))
	await _world_image("lean_to")


# --- 7.5: every pick-up, on the ground and in the strip -------------------------------------------

func _pickups() -> Array[Node2D]:
	var found: Array[Node2D] = []
	for child: Node in session.get_node(^"Pickups").get_children():
		var item: Node2D = child as Node2D
		var interactable: Object = item.get("interactable") if item != null else null
		if item != null and not item.is_queued_for_deletion() and interactable != null and interactable.get("enabled"):
			found.append(item)
	return found


func _ground_icon_ok(item: Node2D) -> bool:
	var look: Node = item.get_node_or_null(^"Look")
	var data: Object = _item_data(item.get("item_id"))
	if look == null or data == null:
		return false
	var icon: Sprite2D = look.get("icon")
	return icon != null and icon.texture != null and icon.texture == data.get("sprite") and icon.is_visible_in_tree()


func _strip_icon_ok(item_id: StringName) -> bool:
	var slot: int = _slot_of(item_id)
	if slot < 0:
		return false
	var view: Control = strip.call("slot_view", slot)
	var icon: TextureRect = view.get("icon") if view != null else null
	return icon != null and icon.visible and icon.texture == _item_data(item_id).get("sprite")


func _pick_up_everything(where: String) -> void:
	var all: Array[Node2D] = _pickups()
	var kinds: Dictionary[StringName, bool] = {}
	var bad: PackedStringArray = []
	for item: Node2D in all:
		kinds[item.get("item_id")] = true
		if not _ground_icon_ok(item):
			bad.append("%s at %s" % [item.get("item_id"), _cell_of(item.global_position)])
	_check("%s: every one of the %d pick-ups (%d kinds) shows its icon on the ground" % [where, all.size(), kinds.size()], bad.is_empty() and not all.is_empty(), ", ".join(bad))
	var missed: PackedStringArray = []
	var strip_bad: PackedStringArray = []
	var picked: int = 0
	for attempt: int in 40:
		var left: Array[Node2D] = _pickups()
		if left.is_empty():
			break
		var item: Node2D = _nearest(left, body.global_position)
		var item_id: StringName = item.get("item_id")
		if not await _walk_to(item.global_position):
			missed.append("%s (walk)" % item_id)
			break
		var before: int = _count(item_id)
		await _hold(&"interact", 0.1)
		for i: int in physics_hz:
			if _count(item_id) > before:
				break
			await physics_frame
		if _count(item_id) <= before:
			missed.append("%s (E)" % item_id)
			break
		picked += 1
		await _frames(2)
		if not _strip_icon_ok(item_id):
			strip_bad.append(String(item_id))
	_check("%s: picked up every pick-up by walking and E" % where, missed.is_empty() and _pickups().is_empty(), "%d picked, missed %s, %d left" % [picked, missed, _pickups().size()])
	_check("%s: each picked-up kind shows its icon in the strip" % where, strip_bad.is_empty() and picked > 0, ", ".join(strip_bad))
	await _save_window("%s_strip" % where)


# --- 8.5: fire, rain catcher, raft ------------------------------------------------------------------

func _walk_to_bench() -> bool:
	var bench: Node2D = session.get_node_or_null(^"HutWorkbench")
	if not _check("the hut's workbench exists", bench != null):
		return false
	return _check("walked to the bench", await _walk_to(bench.global_position + Vector2(0.0, 10.0)))


# Opens the bench's list and chooses the row named `row_name` with list_down and E.
func _choose_at_bench(row_name: String) -> bool:
	if not await _walk_to_bench():
		return false
	if craft_list.call("is_open"):
		await _tap(&"pause")
	await _tap(&"interact")
	await _frames(4)
	if not _check("E at the bench opens the crafting list", craft_list.call("is_open")):
		return false
	var rows: PackedStringArray = craft_list.call("row_texts")
	var index: int = rows.find(row_name)
	if not _check("the list offers '%s'" % row_name, index >= 0, "rows %s" % rows):
		await _tap(&"pause")
		return false
	for i: int in index:
		await _tap(&"list_down")
	await _tap(&"interact")
	await _frames(6)
	return _check("E on '%s' closes the list" % row_name, not craft_list.call("is_open"))


func _site(recipe_id: StringName, built: bool = false) -> Node2D:
	for node: Node in get_nodes_in_group(&"build_sites"):
		var site: Node2D = node as Node2D
		var recipe: Object = site.get("recipe") if site != null else null
		if site != null and session.is_ancestor_of(site) and bool(site.get("built")) == built and recipe != null and recipe.get("id") == recipe_id:
			return site
	return null


# A built structure: the host spawns them into the session's Entities.
func _structure(script_name: StringName) -> Node2D:
	for node: Node in session.get_node(^"Entities").get_children() + session.get_children():
		var script: Script = node.get_script()
		if script != null and script.get_global_name() == script_name and not node.is_queued_for_deletion():
			return node as Node2D
	return null


# Works a site by E and staying beside it; the frames seen on the way.
func _work_site(site: Node2D, label: String, limit_s: float) -> PackedStringArray:
	var seen: PackedStringArray = [_frame(site)]
	# Beside the site where the prompt is the site's own, not the bench's.
	var aimed: bool = false
	for offset: Vector2 in [Vector2(0.0, 12.0), Vector2(-12.0, 0.0), Vector2(12.0, 0.0), Vector2(0.0, -12.0), Vector2(0.0, 6.0)]:
		await _walk_to(site.global_position + offset, 3.0)
		await _frames(3)
		var lines: PackedStringArray = _prompt_lines()
		if not lines.is_empty() and lines[0].contains("Construir"):
			aimed = true
			break
	_check("%s: the prompt beside the site reads '[E] Construir …'" % label, aimed, "prompt %s" % _prompt_lines())
	await _tap(&"interact")
	for i: int in ceili(limit_s * physics_hz):
		if not is_instance_valid(site) or site.is_queued_for_deletion() or bool(site.get("built")):
			break
		var now: String = _frame(site)
		if seen[-1] != now:
			seen.append(now)
		await physics_frame
	_note("%s site frames: %s" % [label, seen])
	return seen


func _fire() -> void:
	if not await _choose_at_bench("Fogata"):
		return
	var site: Node2D = _site(&"fire")
	if not _check("a fire site appeared at the player's feet", site != null):
		return
	_check("the unbuilt fire site shows its stake", _frame(site) == "stake", _frame(site))
	await _work_site(site, "fire", 45.0)
	await _frames(4)
	var fire: Node2D = _structure(&"Fire")
	if not _check("the fire was built", fire != null):
		return
	_check("the fire burns: its look plays the lit flicker", _frame(fire) == "lit" and (_look_of(fire).get("sprite") as AnimatedSprite2D).is_playing(), _frame(fire))
	await _world_image("fire_lit")
	fire.call("advance", float(fire.get("burn_left_s")) + 0.1)
	_hooked("the fire burned down (advance by its burn time; a fire's burn time is minutes)")
	await _frames(3)
	_check("the burnt-out fire shows its embers", _frame(fire) == "out", _frame(fire))
	await _world_image("fire_out")


func _rain_catcher() -> void:
	if _count(&"tarp") < 1 or _count(&"driftwood") < 4:
		body.get("inventory").call("add", &"driftwood", maxi(0, 4 - _count(&"driftwood")))
		_hooked("driftwood topped up to 4 for the rain catcher (the sandbar has 8)")
	if not await _choose_at_bench("Recogedor de lluvia"):
		return
	var site: Node2D = _site(&"rain_catcher")
	if not _check("a rain-catcher site appeared", site != null):
		return
	await _work_site(site, "rain catcher", 40.0)
	await _frames(4)
	var catcher: Node2D = _structure(&"RainCatcher")
	if not _check("the rain catcher was built", catcher != null):
		return
	_check("the dry rain catcher shows empty", _frame(catcher) == "empty", _frame(catcher))
	(_sky().get("weather") as Object).call("start_weather", &"squall")
	_hooked("a squall started (WeatherCycle.start_weather)")
	var filled: bool = false
	for i: int in 120 * physics_hz:
		if int(catcher.get("cups")) > 0:
			filled = true
			break
		await physics_frame
	await _frames(2)
	_check("the rain catcher fills in the squall and shows water", filled and _frame(catcher) == "water", "cups %d, frame %s" % [catcher.get("cups"), _frame(catcher)])
	await _world_image("rain_catcher_squall")
	(_sky().get("weather") as Object).call("start_weather", &"calm")
	_hooked("the weather back to calm")


func _raft() -> void:
	var site: Node2D = session.get_node_or_null(^"RaftSite")
	if not _check("the sandbar has its raft site", site != null):
		return
	_check("the untouched raft site shows its marks", _frame(site) == "marked", _frame(site))
	var need: Dictionary = {&"driftwood": 6, &"inner_tube": 2, &"rope": 3}
	var added: PackedStringArray = []
	for item_id: StringName in need:
		var short: int = int(need[item_id]) - _count(item_id)
		if short > 0:
			body.get("inventory").call("add", item_id, short)
			added.append("%s x%d" % [item_id, short])
	if not added.is_empty():
		_hooked("raft materials topped up: %s (the sandbar's driftwood went into the fire and catcher)" % ", ".join(added))
	var at: Vector2 = site.global_position
	var seen: PackedStringArray = await _work_site(site, "raft", 90.0)
	await _frames(4)
	_check("the raft site went marked, materials, half built", seen.has("marked") and seen.has("materials") and seen.has("half_built"), "%s" % seen)
	var raft: Node2D = session.get_node_or_null(^"Raft")
	_check("the raft stands whole in the site's place", raft != null and _frame(raft) == "whole" and raft.global_position.distance_to(at) < 1.0, _frame(raft) if raft != null else "no raft")
	await _world_image("raft_built")


# --- 5.8: the looks -------------------------------------------------------------------------------

func _looks() -> void:
	Input.action_press(&"crouch")
	await _seconds(0.5)
	_check("held crouch on land: the crouch look", _pose() == "CROUCH", _pose())
	await _world_image("look_crouch")
	Input.action_release(&"crouch")
	await _frames(4)
	# Into the sea from the raft site, the nearest shore.
	var site: Node2D = session.get_node_or_null(^"RaftSite")
	var from: Vector2 = site.global_position if site != null else body.global_position
	await _walk_to(from + Vector2(0.0, TILE))
	var start: Vector2i = _cell_of(body.global_position)
	var deep := Vector2i(-1, -1)
	for step: int in range(1, 12):
		var cell: Vector2i = start + Vector2i(step, 0)
		if _kind(cell) == DEEP:
			deep = cell + Vector2i(2, 0)
			break
	if not _check("deep water east of the raft site", deep.x >= 0):
		return
	await _follow([_center(deep)], 4.0, "swim out")
	await _seconds(0.5)
	_check("in the sea: the swim look, cut at the water line", _pose() == "SWIM" or _pose() == "FLOAT", _pose())
	await _world_image("look_swim")
	Input.action_press(&"crouch")
	await _seconds(0.5)
	_check("crouch while swimming: the dive look", _pose() == "DIVE" or _pose() == "SUBMERGED", _pose())
	await _world_image("look_dive")
	Input.action_release(&"crouch")
	await _seconds(0.5)
	await _follow([_center(start)], 4.0, "swim back")
	await _walk_to(from + Vector2(-TILE * 2.0, 0.0))
	body.call("set_downed", true)
	_hooked("the body downed for a moment through PlayerBody.set_downed (solo has no teammate to down it for)")
	await _frames(6)
	_check("downed: the downed look", _pose() == "DOWNED", _pose())
	await _world_image("look_downed")
	body.call("set_downed", false)
	await _frames(6)
	_check("back up: standing", _pose() == "STANDING", _pose())


# --- 6.5: shark, gull, crabs ----------------------------------------------------------------------

func _shark_offshore() -> void:
	var sharks: Array[Node2D] = _creatures(&"reef_shark")
	if not _check("the offshore shark is in the sea", not sharks.is_empty() and _is_water(_cell_of(sharks[0].global_position)), "%d shark(s)" % sharks.size()):
		return
	var shark: Node2D = sharks[0]
	var anims: Dictionary[String, int] = {}
	for i: int in 3 * physics_hz:
		var anim: String = _creature_anim(shark)
		anims[anim] = anims.get(anim, 0) + 1
		await physics_frame
	var look: Node = _look_of(shark)
	var sprite: AnimatedSprite2D = look.get_node(^"Sprite")
	var shadow: CanvasItem = look.get_node(^"Shadow")
	_check("the shark circles offshore playing its own frames", not anims.has("<hidden>") and (anims.has("patrol") or anims.has("circle") or anims.has("move")), "state %s, animations %s" % [_state_of(shark), anims])
	_check("only its fin shows: cut at the water line, no shadow", sprite.material is ShaderMaterial and not shadow.visible)


func _nest_palm_and_gull() -> void:
	var palms: Node = island.get_node(^"Palms")
	var nests: Array = (island.get("layout") as Object).get("nest_palms")
	var palm: Node2D = _nearest(nests.map(func(index: int) -> Node: return palms.get_child(index)), body.global_position)
	if not _check("a nest palm", palm != null):
		return
	var look: Node = _look_of(palm)
	var before: int = int(look.call("coconuts_drawn"))
	_check("the nest palm shows its nest and its coconut", String(look.call("frame")) != "" and before >= 1, "frame %s, %d coconut(s) drawn" % [look.call("frame"), before])
	var gulls: Array[Node2D] = _creatures(&"seagull")
	var gull: Node2D = _nearest(gulls, palm.global_position)
	_check("a gull perches in the nest palm's crown", gull != null and _state_of(gull) == "perch" and gull.global_position.distance_to(palm.global_position) < TILE, "%d gull(s), state %s" % [gulls.size(), _state_of(gull) if gull != null else ""])
	if not await _walk_to(palm.global_position + Vector2(0.0, 2.0)):
		_check("walked to the nest palm", false)
		return
	await _frames(3)
	var hold_s: float = float(palm.get("hold_s"))
	var coco: int = _count(&"coco")
	var most: int = coco
	var swooper: Node2D = null
	var shadow_below: bool = false
	var shooed: bool = false
	var fled: bool = false
	var selected: bool = false
	var hold_frames: int = ceili((hold_s + 0.4) * physics_hz)
	Input.action_press(&"interact")
	# The climb, then up to 20 s holding the coconut under the nest: a gull swoops on it.
	for i: int in hold_frames + 20 * physics_hz:
		if i == hold_frames:
			Input.action_release(&"interact")
		most = maxi(most, _count(&"coco"))
		if i > hold_frames and not selected and _slot_of(&"coco") >= 0:
			selected = true
			await _tap(StringName("slot_%d" % (_slot_of(&"coco") + 1)))
		for each: Node2D in _creatures(&"seagull"):
			if swooper == null and _state_of(each) == "swoop":
				swooper = each
				_note("a gull swoops %.1f s after the climb began, coconut held %s" % [i / float(physics_hz), _count(&"coco") > coco])
				await _world_image("gull_swoop")
		if swooper != null and is_instance_valid(swooper):
			var state: String = _state_of(swooper)
			var gull_look: Node = _look_of(swooper)
			var shadow: Node2D = gull_look.get_node(^"Shadow")
			shadow_below = shadow_below or (shadow.visible and shadow.global_position.y > (gull_look.get_node(^"Sprite") as Node2D).global_position.y)
			if state == "swoop" and not shooed and i > hold_frames and _prompt_lines().size() > 0 and _prompt_lines()[0].contains("Espantar"):
				await _tap(&"interact")
				shooed = true
			elif state == "flee":
				fled = true
				await _seconds(0.5)
				break
		await physics_frame
	Input.action_release(&"interact")
	_check("held E climbed the nest palm for a coconut", most > coco, "coco %d, most held %d, now %d" % [coco, most, _count(&"coco")])
	_check("the coconut drops from the crown: the palm draws one fewer", int(look.call("coconuts_drawn")) == before - 1, "%d -> %d" % [before, look.call("coconuts_drawn")])
	_check("the nest stays after the climb", String(look.call("frame")) != "")
	_check("a gull swoops on the held coconut", swooper != null)
	_check("in the air its shadow stays on the ground below it", shadow_below)
	_check("a shoo (E on the gull) works, or the gull takes the coconut, and it flies off", fled, "shooed %s, coco %d" % [shooed, _count(&"coco")])
	if swooper != null and is_instance_valid(swooper):
		_note("after the gull: shooed %s, coconut kept %s, gull state %s, animation %s" % [shooed, _count(&"coco") > coco, _state_of(swooper), _creature_anim(swooper)])
	await _world_image("gull_flee")


# --- 4.6 and 6.5 at night; the pause --------------------------------------------------------------

func _night(spawn: Vector2, day: Image) -> void:
	await _walk_to(spawn)
	await _seconds(0.5)
	_sky().call("start_at", NIGHT_START_S - 2.0)
	_hooked("day clock to 2 s before night (played into night from there)")
	await _seconds(3.0)
	var night: Image = await _world_image("sandbar_night_view")
	_check_no_magenta(night, "the sandbar at night")
	if night != null and day != null:
		var classes: PackedByteArray = _classes(night)
		var land_ratio: float = _mean(night, classes, 1) / _mean(day, classes, 1)
		var sea_ratio: float = _mean(night, classes, 2) / _mean(day, classes, 2)
		_check("the night tint darkens land and sea alike", land_ratio < 0.8 and sea_ratio < 0.8 and absf(land_ratio - sea_ratio) < 0.12, "land x%.2f, sea x%.2f" % [land_ratio, sea_ratio])
	await _check_shore_view("spawn_night")
	await _crescent_walk("night")
	# Crabs come out at night.
	var crabs: Array[Node2D] = []
	for i: int in 10 * physics_hz:
		crabs = _creatures(&"land_crab")
		if not crabs.is_empty():
			break
		await physics_frame
	if not _check("crabs come out at night", not crabs.is_empty()):
		return
	# Watching first: a crab on the move plays its scuttle.
	var anims: Dictionary[String, int] = {}
	for i: int in 10 * physics_hz:
		for each: Node2D in _creatures(&"land_crab"):
			var anim: String = _creature_anim(each)
			anims[anim] = anims.get(anim, 0) + 1
		if anims.has("move"):
			break
		await physics_frame
	var crab: Node2D = _nearest(_creatures(&"land_crab"), body.global_position)
	var pinched: bool = false
	for i: int in 25 * physics_hz:
		if not is_instance_valid(crab):
			break
		_steer(crab.global_position)
		var anim: String = _creature_anim(crab)
		anims[anim] = anims.get(anim, 0) + 1
		if _state_of(crab) == "pinch" and anim == "pinch":
			pinched = true
			_stop()
			await _world_image("crab_pinch")
			break
		await physics_frame
	_stop()
	_check("a crab scuttles at night (move frames)", anims.has("move"), "%s" % anims)
	_check("standing by it, the crab raises its claws to pinch", pinched, "state %s" % (_state_of(crab) if is_instance_valid(crab) else "gone"))
	await _walk_to(spawn)


func _pause_check() -> void:
	await _tap(&"pause")
	await _frames(4)
	_check("Esc pauses the solo run", paused, "paused %s" % paused)
	var first: Image = await _world_image("paused_0")
	await create_timer(0.5, true).timeout
	var second: Image = await _world_image("paused_1")
	if first != null and second != null:
		var classes: PackedByteArray = _classes(first)
		_check("paused, the sea keeps moving", _changed(first, second, classes, 2) > 0, "%d sea px changed" % _changed(first, second, classes, 2))
		_check("and nothing on land moves", _changed(first, second, classes, 1) == 0, "%d land px changed" % _changed(first, second, classes, 1))
	await _tap(&"pause")
	await _frames(4)
	if paused:
		session.call("set_paused", false)
		_note("a second Esc did not resume; resumed through the session")
	_check("the run resumes", not paused)


# --- 9.3 and 10.2: the crossing and the coast cay -------------------------------------------------

func _crossing() -> void:
	var raft: Node2D = session.get_node_or_null(^"Raft")
	if not _check("the raft is there to launch", raft != null):
		return
	_set_day("crossing captures")
	await _walk_to(raft.global_position + Vector2(0.0, -4.0), 2.0)
	await _frames(3)
	_note("prompt at the raft: %s" % _prompt_lines())
	Input.action_press(&"interact")
	var crossing: Node2D = null
	for i: int in 6 * physics_hz:
		var crossings: Array = shell.get("crossings")
		if not crossings.is_empty():
			crossing = crossings[0]
			break
		await physics_frame
	Input.action_release(&"interact")
	if not _check("holding E on the raft launched it", crossing != null):
		return
	var beat: Script = load(BEAT_PATH)
	var beats: Array[RefCounted] = [beat.call("create", SQUALL_AT_S, 1), beat.call("create", SHARK_AT_S, 2)]
	crossing.set("plan", (load(PLAN_PATH) as Script).call("create", CROSSING_S, beats))
	_hooked("the crossing's plan: %.0f s, a squall at %.0f s and a shark pass at %.0f s" % [CROSSING_S, SQUALL_AT_S, SHARK_AT_S])
	await _frames(20)
	var deck: Node = crossing.get_node(^"Deck")
	_check("aboard: the deck shows the whole raft over the sea", String(deck.get("frame_name")) == "whole" and (deck as CanvasItem).visible, String(deck.get("frame_name")))
	var image: Image = await _world_image("crossing")
	_check_no_magenta(image, "the crossing")
	for i: int in ceili((SQUALL_AT_S + 1.0) * physics_hz):
		if int(crossing.call("rider_state", 1)) == IN_WATER:
			break
		await physics_frame
	_check("the squall threw the rider in", int(crossing.call("rider_state", 1)) == IN_WATER)
	await _frames(4)
	var shadow: CanvasItem = body.get_node_or_null(^"Look/Shadow")
	_check("in the water: the swim look, no shadow", (_pose() == "SWIM" or _pose() == "FLOAT") and shadow != null and not shadow.visible, _pose())
	await _world_image("crossing_thrown_in")
	# Back to the deck's edge, then hold E for the climb.
	var climbed_at: float = -1.0
	var started: float = float(crossing.get("elapsed_s"))
	Input.action_press(&"interact")
	for i: int in 6 * physics_hz:
		if int(crossing.call("rider_state", 1)) == ABOARD:
			climbed_at = float(crossing.get("elapsed_s")) - started
			break
		if _prompt_lines().is_empty():
			var deck_rect: Rect2 = crossing.call("deck_rect")
			_steer(deck_rect.get_center())
		else:
			_stop()
		await physics_frame
	Input.action_release(&"interact")
	_stop()
	_check("held E climbed back aboard in about 3 s", climbed_at >= 2.9 and climbed_at <= 4.5, "%.2f s" % climbed_at)
	var shark_seen: bool = false
	var shark_line: bool = false
	for i: int in ceili((SHARK_AT_S + 3.0) * physics_hz):
		for shark: Node2D in _creatures(&"reef_shark"):
			if shark.global_position.distance_to(crossing.call("deck_center")) < TILE * 10.0:
				if not shark_seen:
					shark_seen = true
					await _world_image("crossing_shark")
				var sprite: AnimatedSprite2D = _look_of(shark).get_node(^"Sprite")
				shark_line = sprite.visible and sprite.material is ShaderMaterial
		if shark_seen and float(crossing.get("elapsed_s")) > SHARK_AT_S + 1.0:
			break
		await physics_frame
	_check("the shark passes by the deck, drawn at the water line", shark_seen and shark_line)
	var landed: bool = false
	for i: int in ceili((CROSSING_S + 5.0) * physics_hz):
		island = shell.get("island")
		if island != null and (island.get("layout") as Object).get("id") == &"coast_cay" and shell.get("crossings").is_empty():
			landed = true
			break
		await physics_frame
	_check("the crossing ends on the coast cay, still in the run", landed and shell.get("flow") == FLOW_RUN)


func _coast_cay() -> void:
	island = shell.get("island")
	if island == null or (island.get("layout") as Object).get("id") != &"coast_cay":
		return
	var found: Variant = session.call("body", 1)
	body = found
	_build_land()
	_set_day("coast cay captures")
	await _frames(30)
	_check_no_magenta(await _world_image("coast_cay_landing"), "the coast cay landing")
	await _check_shore_view("coast_cay")
	var settings: Object = shell.get("settings")
	for scale: int in [2, 3]:
		for filter: int in [0, 1]:
			settings.set("ui_scale", scale)
			settings.set("pixel_filter", filter)
			shell.call("apply_display")
			shell.call("apply_pixel_filter")
			await _frames(20)
			var name: String = "route_coast_cay_x%d_%s" % [scale, "sharp" if filter == 0 else "smooth"]
			var image: Image = await _save_window(name)
			_check_no_magenta(image, name)
	settings.set("ui_scale", 2)
	settings.set("pixel_filter", 0)
	shell.call("apply_display")
	shell.call("apply_pixel_filter")
	_hooked("window scale and pixel filter through the settings object (Ajustes offers the same)")
	await _frames(10)
	var sign: Node2D = null
	for child: Node in session.get_children():
		var script: Script = child.get_script()
		if script != null and script.get_global_name() == &"IslandSign":
			sign = _nearest([child] if sign == null else [child, sign], body.global_position)
	if _check("the coast cay has a sign", sign != null):
		_check("the sign shows its post", _frame(sign) == "island_sign", _frame(sign))
		if await _walk_to(sign.global_position + Vector2(0.0, 8.0), 4.0):
			await _frames(3)
			await _tap(&"interact")
			await _frames(6)
			var bubble: Node = sign.get_node_or_null(^"SpeechBubble")
			_check("E reads the sign: its line shows over it", bubble != null, "prompt %s" % _prompt_lines())
			await _world_image("coast_cay_sign")
	await _pick_up_everything("coast cay")


func _binoculars_swim() -> void:
	shell.call("back_to_title")
	await _seconds(1.0)
	await _tap(&"ui_accept")
	if not _check("a second solo run for the binoculars swim", await _wait_run(10.0)):
		return
	_build_land()
	_set_day("the binoculars need a clear day")
	body.get("inventory").call("add", &"binoculars", 1)
	_hooked("binoculars given (no island in v1 has them lying about)")
	await _frames(4)
	var raft_site: Node2D = session.get_node_or_null(^"RaftSite")
	if raft_site != null:
		await _walk_to(raft_site.global_position + Vector2(-TILE, 0.0))
	var slot: int = _slot_of(&"binoculars")
	await _tap(StringName("slot_%d" % (slot + 1)))
	var crossing: Node2D = null
	Input.action_press(&"use_item")
	for i: int in 4 * physics_hz:
		var crossings: Array = shell.get("crossings")
		if not crossings.is_empty():
			crossing = crossings[0]
			break
		await physics_frame
	Input.action_release(&"use_item")
	if not _check("F with the binoculars starts the swim", crossing != null, "item line %s" % (strip.get("item_line") as Label).text):
		return
	crossing.set("plan", (load(PLAN_PATH) as Script).call("create", 8.0, [] as Array[RefCounted]))
	_hooked("the swim's plan: 8 s")
	await _frames(20)
	_check("swimming the whole way: in the water, the swim look, no deck", int(crossing.call("rider_state", 1)) == IN_WATER and (_pose() == "SWIM" or _pose() == "FLOAT") and not (crossing.get_node(^"Deck") as CanvasItem).visible, "%s, deck %s" % [_pose(), (crossing.get_node(^"Deck") as CanvasItem).visible])
	_check_no_magenta(await _world_image("binoculars_swim"), "the binoculars swim")
	var landed: bool = false
	for i: int in 14 * physics_hz:
		var now: Node = shell.get("island")
		if now != null and (now.get("layout") as Object).get("id") == &"coast_cay":
			landed = true
			break
		await physics_frame
	_check("the swim ends on the coast cay", landed)


# --- host plus client -------------------------------------------------------------------------------

# A hash of every cell of every tile layer the island's terrain view draws.
func _tiles_hash() -> String:
	var text := PackedStringArray()
	var view: Node = island.get_node_or_null(^"Terrain")
	if view == null:
		return "<no terrain view>"
	var layers: Array[Node] = view.find_children("*", "TileMapLayer", true, false)
	for layer: Node in layers:
		var map: TileMapLayer = layer as TileMapLayer
		var cells: Array[Vector2i] = map.get_used_cells()
		cells.sort()
		for cell: Vector2i in cells:
			text.append("%s:%s:%s:%s:%d" % [map.name, cell, map.get_cell_source_id(cell), map.get_cell_atlas_coords(cell), map.get_cell_alternative_tile(cell)])
	return "%d-%s" % [layers.size(), "|".join(text).sha256_text().substr(0, 16)]


func _host() -> void:
	await _credits_visit()
	shell.set("port", 0)
	shell.call("start_host")
	session = shell.get("session")
	if not _check("start_host opened a port and built the session", session != null and not (session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer)):
		return
	var enet: ENetMultiplayerPeer = session.multiplayer.multiplayer_peer as ENetMultiplayerPeer
	print("ARTRUN host listening %d" % enet.host.get_local_port())
	var joined: bool = false
	for i: int in 120 * physics_hz:
		if (session.get("roster") as Dictionary).size() >= 2:
			joined = true
			break
		await physics_frame
	if not _check("a client joined the lobby", joined):
		return
	await _seconds(1.0)
	_check("begin_run started the run", session.call("begin_run") == true)
	if not _check("the host entered the run", await _wait_run(10.0)):
		return
	_build_land()
	_set_day("host-plus-client captures")
	print("ARTRUN host tiles %s" % _tiles_hash())
	var client_peer: int = 0
	for peer_id: int in session.call("peer_ids"):
		if peer_id != 1:
			client_peer = peer_id
	var client_body: Node2D = session.call("body", client_peer)
	var picked: int = 0
	if client_body != null:
		client_body.get("inventory").connect(&"changed", func() -> void: picked += 1)
	# The raft is built at once (the solo run plays the build), so the host can leave the moment
	# the client does, and waits on it while the client looks round.
	var site: Node2D = session.get_node_or_null(^"RaftSite")
	if site != null:
		for item_id: StringName in [&"driftwood", &"inner_tube", &"rope"]:
			body.get("inventory").call("add", item_id, {&"driftwood": 6, &"inner_tube": 2, &"rope": 3}[item_id])
		site.call("deposit", body)
		site.call("work", 1.0)
		_hooked("host raft built at once (BuildSite.deposit and work, as capture_crossing.gd)")
	await _frames(4)
	var raft: Node2D = session.get_node_or_null(^"Raft")
	_check("host: the raft was built", raft != null and _frame(raft) == "whole")
	if raft != null:
		await _walk_to(raft.global_position + Vector2(0.0, -4.0), 2.0)
	var left: bool = false
	for i: int in 300 * physics_hz:
		if session.call("is_dropped", client_peer) or not (session.call("peer_ids") as Array).has(client_peer):
			left = true
			break
		await physics_frame
	_check("host: the client's pick-ups went through the host (its inventory changed here)", picked > 0, "%d change(s)" % picked)
	if not _check("host: the client left", left) or raft == null:
		return
	raft.set("integrity", HOST_RAFT_INTEGRITY)
	_hooked("host raft integrity %.0f" % HOST_RAFT_INTEGRITY)
	Input.action_press(&"interact")
	var crossing: Node2D = null
	for i: int in 6 * physics_hz:
		var crossings: Array = shell.get("crossings")
		if not crossings.is_empty():
			crossing = crossings[0]
			break
		await physics_frame
	Input.action_release(&"interact")
	if not _check("host: holding E launched the raft", crossing != null):
		return
	crossing.set("plan", (load(PLAN_PATH) as Script).call("create", 120.0, [] as Array[RefCounted]))
	_hooked("host crossing plan 120 s, no beats")
	print("ARTRUN host crossing started")
	var rejoined: bool = false
	for i: int in 60 * physics_hz:
		if (session.call("peer_ids") as Array).size() >= 2:
			rejoined = true
			_note("the client came back %.1f s into the crossing" % float(crossing.get("elapsed_s")))
			break
		await physics_frame
	_check("host: the client joined again during the crossing", rejoined)
	_check("host: the deck at %.0f shows worn" % HOST_RAFT_INTEGRITY, String(crossing.get_node(^"Deck").get("frame_name")) == "worn")
	for i: int in 30 * physics_hz:
		if (session.call("peer_ids") as Array).size() <= 1:
			break
		await physics_frame


func _client() -> void:
	await _credits_visit()
	shell.call("_join", "127.0.0.1", port)
	if not _check("the client joined and entered the run", await _wait_run(120.0)):
		return
	_check("the client is not the host", not session.multiplayer.is_server())
	_build_land()
	await _frames(30)
	var tiles: String = _tiles_hash()
	print("ARTRUN client tiles %s" % tiles)
	if not host_tiles.is_empty():
		_check("client: the island matches the host's tile for tile", tiles == host_tiles, "client %s, host %s" % [tiles, host_tiles])
	await _world_image("client_island")
	# Creatures: the same animations from the synced state, none flickering.
	var flicker: Dictionary[String, int] = {}
	var last: Dictionary[String, String] = {}
	var wrong: PackedStringArray = []
	for i: int in 4 * physics_hz:
		for child: Node in session.get_node(^"Entities").get_children():
			if child.get("data") == null:
				continue
			var anim: String = _creature_anim(child)
			var key: String = String(child.name)
			if last.has(key) and last[key] != anim and ((last[key] == "move") != (anim == "move")) and (last[key] == "idle" or anim == "idle"):
				flicker[key] = flicker.get(key, 0) + 1
			last[key] = anim
		await physics_frame
	for key: String in flicker:
		if flicker[key] > 2:
			wrong.append("%s %d" % [key, flicker[key]])
	_check("client: %d creature(s) play their frames with no move/idle flicker" % last.size(), not last.is_empty() and wrong.is_empty(), ", ".join(wrong))
	# Icons and pick-ups through the host.
	var bad: PackedStringArray = []
	for item: Node2D in _pickups():
		if not _ground_icon_ok(item):
			bad.append(String(item.get("item_id")))
	_check("client: every pick-up shows its icon on the ground", bad.is_empty() and not _pickups().is_empty(), ", ".join(bad))
	var got: int = 0
	for attempt: int in 2:
		var item: Node2D = _nearest(_pickups(), body.global_position)
		if item == null or not await _walk_to(item.global_position):
			break
		var item_id: StringName = item.get("item_id")
		var before: int = _count(item_id)
		Input.action_press(&"interact")
		for i: int in 2 * physics_hz:
			if _count(item_id) > before:
				break
			await physics_frame
		Input.action_release(&"interact")
		if _count(item_id) > before and _strip_icon_ok(item_id):
			got += 1
	_check("client: two pick-ups arrived from the host and show their icons in the strip", got == 2, "%d" % got)
	# Structures: the same frames as the host draws from the same state.
	var structures: PackedStringArray = []
	for node: Node in [session.get_node_or_null(^"HutWorkbench"), session.get_node_or_null(^"RaftSite"), session.get_node_or_null(^"Raft")]:
		if node != null:
			structures.append("%s %s" % [node.name, _frame(node)])
	for palm: Node in island.get_node(^"Palms").get_children():
		structures.append("%s %d" % [palm.name, _look_of(palm).call("coconuts_drawn")])
	_note("client structures: %s" % ", ".join(structures))
	await _save_window("client_run")
	shell.call("back_to_title")
	_note("left; joining again in %.0f s" % REJOIN_AFTER_S)
	await _seconds(REJOIN_AFTER_S)
	shell.call("_join", "127.0.0.1", port)
	if not _check("client: joined again", await _wait_run(60.0)):
		return
	var crossing: Node2D = null
	for i: int in 10 * physics_hz:
		var crossings: Array = shell.get("crossings")
		if not crossings.is_empty():
			crossing = crossings[0]
			break
		await physics_frame
	if not _check("client: the host's crossing is there", crossing != null):
		return
	await _frames(20)
	var integrity: float = float((crossing.get("integrity") as Object).get("value"))
	var deck: Node = crossing.get_node(^"Deck")
	_check("client: joining mid-crossing, the deck shows the host's integrity", is_equal_approx(integrity, HOST_RAFT_INTEGRITY) and String(deck.get("frame_name")) == String(structure_art.call("raft_frame", HOST_RAFT_INTEGRITY)), "integrity %.1f, frame %s" % [integrity, deck.get("frame_name")])
	var host_rider: Node2D = crossing.call("body_of", 1)
	_check("client: the host's rider is on the deck, over the sea", host_rider != null and (crossing.call("deck_rect") as Rect2).grow(4.0).has_point(host_rider.global_position) and draw_order.call("drawn_after", host_rider, deck))
	await _world_image("client_crossing")
	shell.call("back_to_title")
	await _seconds(1.0)


# --- the end ----------------------------------------------------------------------------------------

func _finish() -> void:
	if done:
		return
	_stop()
	for action: StringName in [&"interact", &"use_item", &"crouch"]:
		Input.action_release(action)
	if is_instance_valid(shell) and shell.get("flow") != FLOW_TITLE:
		shell.call("back_to_title")
	await _frames(4)
	_report_and_quit()


func _report_and_quit() -> void:
	if done:
		return
	done = true
	var errors: PackedStringArray = collector.error_list()
	var warnings: PackedStringArray = collector.warning_list()
	for text: String in errors:
		print("ARTRUN engine error: ", text)
	for text: String in warnings:
		print("ARTRUN engine warning: ", text)
	_check("no engine or script errors logged (%s)" % mode, errors.is_empty(), "%d error(s), %d warning(s)" % [errors.size(), warnings.size()])
	print("ARTRUN summary %s: %d passed, %d failed" % [mode, passes, fails])
	quit(0 if fails == 0 else 1)
