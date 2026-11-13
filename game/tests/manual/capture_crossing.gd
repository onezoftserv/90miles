extends Node
## Manual check for art-pass "Crossing look", run windowed (it needs a real renderer, so never
## headless and never in CI). A solo run through the game shell builds the sandbar's raft and
## launches it, with a long plan and no beats; it saves the view with the rider aboard, the same
## a second later (the sea has scrolled), then with the rider thrown in beside the deck, and one
## with the raft worn:
##   godot --path game res://tests/manual/capture_crossing.tscn -- --out=<dir>
## Writes <dir>/crossing_aboard_0.png, crossing_aboard_1.png, crossing_swimmer.png and
## crossing_worn.png, each the 640×360 view.

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://capture_crossing.cfg"
const SETTLE_FRAMES: int = 30
const PLAN_S: float = 600.0
const BESIDE_PX: float = 6.0
const DAYLIGHT_AFTER_S: float = 60.0

var _out_dir: String = ""


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	if _out_dir.is_empty():
		push_error("capture_crossing: pass --out=<dir>")
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
	# Full daylight, past the dawn blend, so the colours are the art's own.
	WeatherManager.sky.start_at(DayClock.DAY_START_S + DAYLIGHT_AFTER_S)
	var session := shell.session
	var body := session.body(1)
	body.player_input.enabled = false
	var crossing := _launch_raft(session)
	if crossing == null:
		push_error("capture_crossing: the raft did not leave")
		get_tree().quit(1)
		return
	await _frames(SETTLE_FRAMES * 2)
	_save("crossing_aboard_0")
	await get_tree().create_timer(1.0).timeout
	_save("crossing_aboard_1")
	crossing.throw_in(1)
	body.global_position = Vector2(crossing.deck_rect().end.x + BESIDE_PX, crossing.deck_center().y)
	await _frames(SETTLE_FRAMES)
	_save("crossing_swimmer")
	crossing.bring_aboard(1)
	crossing.hit_vessel(45.0)
	await _frames(SETTLE_FRAMES)
	_save("crossing_worn")
	get_tree().quit()


# Builds the raft at the sandbar's site with the solo player's materials and starts its route.
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
	if not session.start_route_for(1, &"raft"):
		return null
	var crossing := session.get_node_or_null(NodePath(Crossing.node_name_for(0))) as Crossing
	if crossing != null:
		crossing.plan = CrossingPlan.create(PLAN_S)
	return crossing


func _frames(count: int) -> void:
	for i: int in count:
		await get_tree().process_frame


func _save(capture: String) -> void:
	var path := _out_dir.path_join(capture + ".png")
	print("capture_crossing: %s (%s)" % [path, error_string(get_viewport().get_texture().get_image().save_png(path))])
