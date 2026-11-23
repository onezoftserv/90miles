class_name SeaPaceDriver
extends Node
## Runs a sea view's clocks (art-mood-pass "Squall on screen", design D4): one SeaPace, stepped every
## frame toward the current weather's paces. It writes `sea_time` to the sea's material and
## `foam_time` to the Shore layer's material when the view has one. It sits under TerrainView (in
## its scene) and under CrossingSea (added in code). Its process mode is ALWAYS, so under the solo
## pause the sea and the foam keep moving while the day stands still. Drawing only: it reads the sky
## and never writes it.

## The node whose ShaderMaterial gets `sea_time`, and the one that gets `foam_time`, from this node;
## an empty path is skipped.
@export var sea_path: NodePath = ^"../Sea"
@export var shore_path: NodePath = ^"../Shore"

## Defaults to the game's one sky.
var sky: WorldSky
var pace: SeaPace


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pace = SeaPace.new(ArtTuning.standard().pace_ease_s)


func _ready() -> void:
	if sky == null:
		sky = WeatherManager.sky
	_write()


func _process(delta: float) -> void:
	step(delta)


## Runs the clocks `delta` seconds toward the current weather's paces and writes them.
func step(delta: float) -> void:
	var weather: WeatherData = sky.weather.current if sky != null and sky.weather != null else null
	pace.step(delta, weather.sea_pace if weather != null else 1.0, weather.foam_pace if weather != null else 1.0)
	_write()


func _write() -> void:
	_write_clock(sea_path, &"sea_time", pace.sea_time)
	_write_clock(shore_path, &"foam_time", pace.foam_time)


func _write_clock(path: NodePath, parameter: StringName, seconds: float) -> void:
	if path.is_empty():
		return
	var target := get_node_or_null(path) as CanvasItem
	var material := target.material as ShaderMaterial if target != null else null
	if material != null:
		material.set_shader_parameter(parameter, seconds)
