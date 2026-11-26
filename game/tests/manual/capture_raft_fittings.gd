extends Node
## Manual check for island-stop task 3.6, run windowed (it needs a real renderer, so never headless
## and never in CI). A solo run through the game shell travels to the coast cay with a raft at 110
## of 120 holding all three fittings, saves the view of it on the beach, launches it into a quiet
## crossing and saves the view at sea:
##   godot --path game res://tests/manual/capture_raft_fittings.tscn -- --out=<dir>
## Writes <dir>/raft_fittings_beach.png and <dir>/raft_fittings_sea.png, each the 640×360 view.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://capture_raft_fittings.cfg"
const SETTLE_FRAMES: int = 30
const PLAN_S: float = 600.0
const DAYLIGHT_AFTER_S: float = 60.0

var _out_dir: String = ""


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _out_dir.is_empty():
		push_error("capture_raft_fittings: pass --out=<dir>")
		get_tree().quit(1)
		return
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
	var raft := RaftRecord.bare(110.0, 120.0)
	raft.fittings = [&"raft_clavazon", &"raft_defensas", &"raft_toldo"] as Array[StringName]
	session.travel_to("coast_cay", {1: {"health": 100.0, "energy": 100.0}}, raft.to_dict())
	await _frames(SETTLE_FRAMES)
	var beached := session.get_node_or_null(^"Raft") as Raft
	if beached == null:
		push_error("capture_raft_fittings: no raft on the coast cay")
		get_tree().quit(1)
		return
	var body := session.body(1)
	body.player_input.enabled = false
	body.global_position = beached.work_point.global_position
	await _frames(SETTLE_FRAMES * 2)
	_save("raft_fittings_beach")
	body.global_position = beached.global_position
	if not session.start_route_for(1, &"raft"):
		push_error("capture_raft_fittings: the raft did not leave")
		get_tree().quit(1)
		return
	var crossing := shell.crossings[0] as Crossing
	crossing.plan = CrossingPlan.create(PLAN_S)
	await _frames(SETTLE_FRAMES * 2)
	_save("raft_fittings_sea")
	get_tree().quit()


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(capture: String) -> void:
	var path := _out_dir.path_join(capture + ".png")
	print("capture_raft_fittings: %s (%s)" % [path, error_string(get_viewport().get_texture().get_image().save_png(path))])
