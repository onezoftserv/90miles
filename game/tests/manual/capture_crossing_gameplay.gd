extends Node
## Manual check for crossing-gameplay, run windowed (it needs a real renderer, so never headless and
## never in CI). A solo run through the game shell launches the sandbar's raft on a short
## hand-written plan with debris, a rock in line, a coconut and the reef line. A scripted rider
## paddles east out of the rock's lane and lets the current pull the raft back, and the view is
## saved as the beats come down, while paddling, and at the reef line. It prints the raft's
## integrity and lateral position at each capture, and quits.
##   godot --path game res://tests/manual/capture_crossing_gameplay.tscn [-- --out=<dir>]
## Writes <dir>/gameplay_<name>.png (default dir: user://crossing_gameplay_captures).

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://capture_crossing_gameplay.cfg"
const DAYLIGHT_AFTER_S: float = 60.0
const K := CrossingBeat.Kind

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
	await _until(10.0)
	_save("past_the_rock")
	await _until(13.6)
	_save("reef_line")
	await _until(15.0)
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
	if crossing != null:
		var tuning := CrossingTuning.standard()
		var beats: Array[RefCounted] = [
			CrossingBeat.create(7.0, K.DEBRIS, -3),
			CrossingBeat.create(9.0, K.ROCK, 1),
			CrossingBeat.create(10.0, K.FLOTSAM, 4, tuning.flotsam_items.find(&"coco")),
			CrossingBeat.create(14.0, K.ROCK, -3),
			CrossingBeat.create(14.0, K.ROCK, 7),
		]
		crossing.plan = CrossingPlan.create(30.0, beats)
	return crossing


func _until(at_s: float) -> void:
	while _crossing != null and _crossing.elapsed_s < at_s and not _crossing.finished:
		await get_tree().process_frame


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(capture: String) -> void:
	var path := _out_dir.path_join("gameplay_" + capture + ".png")
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("capture_crossing_gameplay: %s (%s) at %.1f s, integrity %.1f, position %.2f" % [path, error_string(result), _crossing.elapsed_s, _crossing.integrity.value, _crossing.steer.position])
