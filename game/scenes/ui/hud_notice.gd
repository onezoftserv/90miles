class_name HudNotice
extends Control
## The refusal line above the selected item's line (inventory-hud "Refused uses", design D1): one
## short Spanish reason on a HUD panel at 120,306 (400×10) for 2 s, then nothing. No log: a new
## line replaces the old one.

const SHOW_S: float = 2.0

var _left_s: float = 0.0

@onready var panel: PanelContainer = $Panel
@onready var line: Label = $Line


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clear()


## Shows `text` for `seconds`.
func show_line(text: String, seconds: float = SHOW_S) -> void:
	line.text = text
	_left_s = seconds
	_set_shown(not text.is_empty() and seconds > 0.0)


## The line on show, or "".
func shown_text() -> String:
	return line.text if panel.visible else ""


func clear() -> void:
	_left_s = 0.0
	line.text = ""
	_set_shown(false)


func _process(delta: float) -> void:
	if _left_s <= 0.0:
		return
	_left_s -= delta
	if _left_s <= 0.0:
		clear()


func _set_shown(value: bool) -> void:
	panel.visible = value
	line.visible = value
