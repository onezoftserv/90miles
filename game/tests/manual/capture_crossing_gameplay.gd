extends Node
## Manual check for crossing-gameplay, run windowed (it needs a real renderer, so never headless and
## never in CI). A solo run through the game shell launches the sandbar's raft on a short
## hand-written plan with debris, a rock in line, a coconut, more debris and the reef line. A
## scripted rider paddles east out of the rock's lane, grabs the coconut as it passes, lets the
## current pull the raft back onto the second debris and plugs the leak it opens. The view is saved
## as the beats come down, while paddling, at the grab, with the leak open and at the reef line. It
## prints the raft's integrity and lateral position at each capture, and quits.
##   godot --path game res://tests/manual/capture_crossing_gameplay.tscn [-- --out=<dir>]
## Writes <dir>/gameplay_<name>.png (default dir: user://crossing_gameplay_captures).
## With `rolled` set (capture_crossing_timeline.tscn) it keeps the shell's rolled plan instead, rides
## it idle and prints the timeline second by second: what is on the sea and the rider's choices then
## (crossing-gameplay task 9.2), and the longest gap between decisions outside a squall's blow.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://capture_crossing_gameplay.cfg"
const DAYLIGHT_AFTER_S: float = 60.0
const K := CrossingBeat.Kind

## Keep the shell's rolled plan and print its timeline instead of the scripted capture.
@export var rolled: bool = false

var _out_dir: String = ProjectSettings.globalize_path("user://crossing_gameplay_captures")
var _crossing: Crossing
var _body: PlayerBody


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	WeatherManager.stop()
	var config := ConfigFile.new()
	config.set_value("player", "name", "Yuni")
	config.set_value("display", "fullscreen", false)
	config.set_value("display", "ui_scale", 2)
	config.set_value("display", "pixel_filter", 0)
	config.save(SETTINGS_PATH)
	var shell := SHELL_SCENE.instantiate() as GameShell
	shell.settings_path = SETTINGS_PATH
	add_child(shell)
	await _frames(5)
	shell.start_solo()
	WeatherManager.sky.start_at(DayClock.DAY_START_S + DAYLIGHT_AFTER_S)
	var session := shell.session
	_body = session.body(1)
	_body.player_input.enabled = false
	_crossing = _launch_raft(session)
	if _crossing == null:
		push_error("capture_crossing_gameplay: the raft did not leave")
		get_tree().quit(1)
		return
	if rolled:
		await _timeline()
		get_tree().quit()
		return
	await _until(4.5)
	_save("coming")
	var deck := _crossing.deck_rect()
	_body.global_position = Vector2(deck.end.x - 4.0, deck.get_center().y)
	await _until(6.0)
	_body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	await _until(8.5)
	_save("paddling")
	await _until(9.5)
	_body.intent = MoveIntent.new()
	await _until(9.8)
	_body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	await _until(10.1)
	_save("grab")
	_body.intent = MoveIntent.new()
	print("capture_crossing_gameplay: coconuts carried %d" % _body.inventory.count_id(&"coco"))
	await _until(16.5)
	_save("leak")
	if not _crossing.leaks.list.is_empty():
		_body.global_position = _crossing.leak_position(_crossing.leaks.list[0])
		_body.intent = MoveIntent.create(Vector2.ZERO, false, false, true)
	await _until(19.0)
	_body.intent = MoveIntent.new()
	_save("plugged")
	await _until(23.6)
	_save("reef_line")
	await _until(25.0)
	print("capture_crossing_gameplay: done, integrity %.1f, position %.2f" % [_crossing.integrity.value, _crossing.steer.position])
	get_tree().quit()


# The sandbar's raft, built and launched, on the hand-written plan.
func _launch_raft(session: CoopSession) -> Crossing:
	var site := session.get_node_or_null(^"RaftSite") as BuildSite
	if site == null:
		return null
	var builder := session.body(1)
	builder.global_position = site.global_position
	builder.inventory.add(&"driftwood", 6)
	builder.inventory.add(&"inner_tube", 2)
	builder.inventory.add(&"rope", 3)
	site.deposit(builder)
	site.work(1.0)
	# island-pressure: by day the patrol sees a raft launch. This run is about the crossing, so the
	# sandbar's patrol boats are taken away before it launches.
	for boat: Creature in LaunchSight.boats_of(session):
		boat.get_parent().remove_child(boat)
		boat.queue_free()
	if not session.start_route_for(1, &"raft"):
		return null
	var crossing := session.get_node_or_null(NodePath(Crossing.node_name_for(0))) as Crossing
	if crossing != null and not rolled:
		var tuning := CrossingTuning.standard()
		var beats: Array[RefCounted] = [
			CrossingBeat.create(7.0, K.DEBRIS, -3),
			CrossingBeat.create(9.0, K.ROCK, 1),
			CrossingBeat.create(10.0, K.FLOTSAM, 7, tuning.flotsam_items.find(&"coco")),
			CrossingBeat.create(16.0, K.DEBRIS, 0),
			CrossingBeat.create(24.0, K.ROCK, -3),
			CrossingBeat.create(24.0, K.ROCK, 7),
		]
		crossing.plan = CrossingPlan.create(30.0, beats)
	return crossing


# The rolled plan, then one line a second: integrity, position, and each beat on the sea with the
# rider's choice for it; then the gaps between beats.
func _timeline() -> void:
	var plan := _crossing.plan
	var listed: PackedStringArray = []
	for item: RefCounted in plan.events:
		var beat := item as CrossingBeat
		listed.append("%s@%.1f(lane %d)" % [CrossingBeat.Kind.keys()[beat.kind], beat.time_s, beat.lane])
	print("TIMELINE plan %.1f s: %s" % [plan.length_s, ", ".join(listed)])
	var second: int = 0
	var choices := {
		CrossingBeat.Kind.ROCK: "paddle out of its lane",
		CrossingBeat.Kind.DEBRIS: "paddle out, or plug the leak",
		CrossingBeat.Kind.FLOTSAM: "paddle to it and grab, or let it pass",
		CrossingBeat.Kind.SHARK_PASS: "shoo the fin, or climb out",
		CrossingBeat.Kind.SQUALL: "tie down late, then untie",
		CrossingBeat.Kind.SQUALL_WARN: "watch the line",
	}
	var length_s: float = plan.length_s
	var squall_blow_s: float = _crossing.tuning.squall_blow_s
	var integrity: Array[float] = [_crossing.integrity.value]
	_crossing.ended.connect(func(result: CrossingResult) -> void: integrity[0] = 0.0 if result.broken else result.integrity)
	while is_instance_valid(_crossing) and not _crossing.finished:
		await _until(float(second))
		if not is_instance_valid(_crossing) or _crossing.finished:
			break
		var seen: PackedStringArray = []
		for item: RefCounted in plan.events:
			var beat := item as CrossingBeat
			var ahead: float = beat.time_s - _crossing.elapsed_s
			var lead: float = 60.0 if beat.kind == CrossingBeat.Kind.SQUALL else 5.0
			if ahead > 0.0 and ahead <= lead and beat.kind != CrossingBeat.Kind.SQUALL_WARN:
				seen.append("%s in %.1f s: %s" % [CrossingBeat.Kind.keys()[beat.kind], ahead, choices[beat.kind]])
		print("TIMELINE t=%2d integrity %5.1f position %5.2f | %s" % [second, _crossing.integrity.value, _crossing.steer.position, "; ".join(seen) if not seen.is_empty() else "nothing to decide"])
		if second == 20:
			_save("rolled_20s")
		integrity[0] = _crossing.integrity.value
		second += 1
	var times: Array[float] = []
	for item: RefCounted in plan.events:
		var beat := item as CrossingBeat
		if beat.kind != CrossingBeat.Kind.SQUALL_WARN and (times.is_empty() or absf(times[-1] - beat.time_s) > 0.001):
			times.append(beat.time_s)
	var widest: float = times[0] if not times.is_empty() else length_s
	var hit: float = plan.squall_hit_s()
	for index: int in range(1, times.size()):
		if hit >= 0.0 and times[index - 1] >= hit - 0.001 and times[index - 1] < hit + squall_blow_s:
			continue
		widest = maxf(widest, times[index] - times[index - 1])
	print("TIMELINE done: integrity %.1f, %d beats, widest gap between decisions %.1f s (the calm start counted, a squall's blow not)" % [integrity[0], times.size(), widest])


func _until(at_s: float) -> void:
	while is_instance_valid(_crossing) and _crossing.elapsed_s < at_s and not _crossing.finished:
		await get_tree().process_frame


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(capture: String) -> void:
	var path := _out_dir.path_join("gameplay_" + capture + ".png")
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("capture_crossing_gameplay: %s (%s) at %.1f s, integrity %.1f, position %.2f" % [path, error_string(result), _crossing.elapsed_s, _crossing.integrity.value, _crossing.steer.position])
