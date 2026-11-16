class_name HudNotice
extends Control
## The refusal line above the selected item's line (inventory-hud "Refused uses", design D1): one
## short Spanish reason on a HUD panel at 120,306 (400×10) for 2 s, then nothing. No log: a new
## line replaces the old one. Between refusals the row shows its resting line, the selected item's
## effect line (inventory-hud "Effect line"; damage-feedback design D11), when it has one.

const SHOW_S: float = 2.0

var _left_s: float = 0.0
var _rest: String = ""

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


## The refusal on show, or "".
func shown_text() -> String:
	return line.text if panel.visible and _left_s > 0.0 else ""


## The resting line: shown whenever no refusal is.
func show_rest(text: String) -> void:
	if _rest == text:
		return
	_rest = text
	if _left_s <= 0.0:
		_show_rest()


## The resting line on show now, or "" (none, or a refusal is over it).
func rest_text() -> String:
	return line.text if panel.visible and _left_s <= 0.0 else ""


## Drops the refusal on show; the resting line comes back.
func clear() -> void:
	_left_s = 0.0
	_show_rest()


func _show_rest() -> void:
	line.text = _rest
	_set_shown(not _rest.is_empty())


func _process(delta: float) -> void:
	if _left_s <= 0.0:
		return
	_left_s -= delta
	if _left_s <= 0.0:
		clear()


func _set_shown(value: bool) -> void:
	panel.visible = value
	line.visible = value
