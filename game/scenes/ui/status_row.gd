class_name StatusRow
extends HBoxContainer
## hud-clarity, survival-meters "Bleeding tag on the HUD" and "Sunstroke tag on the HUD": one status
## row in the meters window under the bars, shown only while its status applies: a 7×7 icon, the word
## in the alert red and a 32×7 time bar right-aligned to the bars' value column, a 1 px outline round a
## 30×5 fill that drains as the status runs out (the bleeding's time, the sunstroke's cooling). The
## icon, word and colour are set per instance in meters_hud.tscn. Drawing only.

const FILL_SIZE: Vector2 = Vector2(30.0, 5.0)

## Which status the row shows (MetersHud.status_row looks it up): &"sunstroke" or &"bleeding".
@export var key: StringName = &""
@export var icon_texture: Texture2D = null
@export var word_text: String = ""
@export var fill_color: Color = HudStyle.ALERT

@onready var icon: TextureRect = $Icon
@onready var word: Label = $Word
## The 32×7 box: its outline and the fill.
@onready var bar_box: Control = $Cell/Box
@onready var _fill: ColorRect = $Cell/Box/Fill

var _ratio: float = 0.0


func _ready() -> void:
	icon.texture = icon_texture
	word.text = word_text
	_fill.color = fill_color
	set_active(false)
	show_fill(0.0)


## Shows or hides the row; its word hides with it, so MetersHud.bleeding_tag() still reads the state.
func set_active(active: bool) -> void:
	visible = active
	word.visible = active


## Fills the time bar to `ratio` (0 to 1), in whole pixels.
func show_fill(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	_fill.size = Vector2(ceilf(_ratio * FILL_SIZE.x - 0.0001), FILL_SIZE.y)


## How full the time bar is, 0 to 1.
func fill_ratio() -> float:
	return _ratio
