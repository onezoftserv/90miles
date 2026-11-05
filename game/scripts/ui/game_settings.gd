class_name GameSettings
extends RefCounted
## ui-shell "Settings": what each install keeps across launches (player name, fullscreen,
## scale, pixel filter), in one ConfigFile. Nothing here is synced to other players. Values read from the file are checked; anything malformed falls
## back to its default.

const DEFAULT_PATH: String = "user://settings.cfg"
const DEFAULT_NAME: String = "Balsero"
const MAX_NAME_LENGTH: int = 16
## Code points a name never keeps: zero-width spaces and joiners, direction marks, bidi
## embeddings and overrides, invisible operators and isolates, and the BOM.
const HIDDEN_RANGES: Array[Vector2i] = [
	Vector2i(0x200B, 0x200F), Vector2i(0x202A, 0x202E), Vector2i(0x2060, 0x206F),
	Vector2i(0xFEFF, 0xFEFF),
]
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
var pixel_filter: PixelFilter.Mode = PixelFilter.Mode.SHARP


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
	var filter_value: Variant = config.get_value("display", "pixel_filter", PixelFilter.Mode.SHARP)
	if filter_value is int and PixelFilter.Mode.values().has(filter_value):
		settings.pixel_filter = filter_value as PixelFilter.Mode
	return settings


func save() -> Error:
	var config := ConfigFile.new()
	config.set_value("player", "name", player_name)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "ui_scale", ui_scale)
	config.set_value("display", "pixel_filter", pixel_filter)
	return config.save(path)


## A name with control, text-direction and invisible characters removed, trimmed and cut to
## MAX_NAME_LENGTH; `fallback` when nothing printable is left.
static func clean_name(raw: String, fallback: String = DEFAULT_NAME) -> String:
	var kept := ""
	for i: int in raw.length():
		if is_printable(raw.unicode_at(i)):
			kept += raw[i]
	kept = kept.strip_edges().left(MAX_NAME_LENGTH).strip_edges()
	return fallback if kept.is_empty() else kept


## False for control characters and for marks that change text direction or draw nothing
## (zero-width spaces and joiners, bidi embeddings, overrides and isolates, the BOM): a name
## must not garble its neighbours or pass for someone else's.
static func is_printable(code: int) -> bool:
	if code < 32 or (code >= 127 and code < 160):
		return false
	for hidden: Vector2i in HIDDEN_RANGES:
		if code >= hidden.x and code <= hidden.y:
			return false
	return true
