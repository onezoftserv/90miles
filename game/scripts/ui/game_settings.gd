class_name GameSettings
extends RefCounted
## ui-shell "Settings": what each install keeps across launches (player name, fullscreen,
## scale), in one ConfigFile. Values read from the file are checked; anything malformed falls
## back to its default.

const DEFAULT_PATH: String = "user://settings.cfg"
const DEFAULT_NAME: String = "Balsero"
const MAX_NAME_LENGTH: int = 16
## 0 is automatic; 1 to MAX_SCALE is fixed.
const MAX_SCALE: int = 4

var path: String
var player_name: String = DEFAULT_NAME:
	set(value):
		player_name = clean_name(value)
var fullscreen: bool = false
var ui_scale: int = 0:
	set(value):
		ui_scale = clampi(value, 0, MAX_SCALE)


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path


static func load_from(file_path: String = DEFAULT_PATH) -> GameSettings:
	var settings := GameSettings.new(file_path)
	var config := ConfigFile.new()
	if config.load(file_path) != OK:
		return settings
	var name_value: Variant = config.get_value("player", "name", DEFAULT_NAME)
	if name_value is String:
		settings.player_name = name_value
	var fullscreen_value: Variant = config.get_value("display", "fullscreen", false)
	if fullscreen_value is bool:
		settings.fullscreen = fullscreen_value
	var scale_value: Variant = config.get_value("display", "ui_scale", 0)
	if scale_value is int and scale_value >= 0 and scale_value <= MAX_SCALE:
		settings.ui_scale = scale_value
	return settings


func save() -> Error:
	var config := ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "ui_scale", ui_scale)
	return config.save(path)


## A name with control characters removed, trimmed and cut to MAX_NAME_LENGTH; `fallback` when
## nothing printable is left.
static func clean_name(raw: String, fallback: String = DEFAULT_NAME) -> String:
	var kept := ""
	for i: int in raw.length():
		var code := raw.unicode_at(i)
		if code >= 32 and not (code >= 127 and code < 160):
			kept += raw[i]
	kept = kept.strip_edges().left(MAX_NAME_LENGTH).strip_edges()
	return fallback if kept.is_empty() else kept
