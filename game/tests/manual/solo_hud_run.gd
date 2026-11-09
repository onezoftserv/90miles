extends Node
## Manual check for inventory-hud task 8.3: a solo run through the game shell with the HUD up for
## 300 frames, so its output can be read for errors. Nothing is pressed. It prints one line with what
## was on show; headless it then quits, and windowed (the Godot MCP's run_project with this scene)
## it stays on the run until stopped, so the output can still be read:
##   godot --headless --path game res://tests/manual/solo_hud_run.tscn

const SHELL_SCENE: PackedScene = preload("res://scenes/shell/game_shell.tscn")
const SETTINGS_PATH: String = "user://solo_hud_run.cfg"
const RUN_FRAMES: int = 300

var _shell: GameShell
var _frames: int = 0


func _ready() -> void:
	_shell = SHELL_SCENE.instantiate() as GameShell
	_shell.settings_path = SETTINGS_PATH
	add_child(_shell)
	_shell.start_solo()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < RUN_FRAMES:
		return
	set_process(false)
	var hud := _shell.hud
	var strip_shown: bool = hud != null and hud.strip.visible
	print("solo_hud_run: %d frames, HUD %s, strip %s, flow %s" % [_frames, "up" if hud != null else "missing", "shown" if strip_shown else "hidden", GameShell.Flow.keys()[_shell.flow]])
	if DisplayServer.get_name() == "headless":
		_shell.back_to_title()
		get_tree().quit()
