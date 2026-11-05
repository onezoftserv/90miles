class_name MeterBar
extends HBoxContainer
## One HUD row: a label and a 0-100 bar for one survival meter. The meter, the Spanish label and
## the fill color are set per instance in meters_hud.tscn, so changing them needs no code.

@export var meter: DataEnums.Meter = DataEnums.Meter.NONE
@export var label_text: String = ""
@export var fill_color: Color = Color.WHITE

@onready var label: Label = $Label
@onready var bar: ProgressBar = $Bar


func _ready() -> void:
	label.text = label_text
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override(&"fill", fill)


func show_value(new_value: float) -> void:
	bar.value = new_value


## How full the bar is, 0 to 1.
func fill_ratio() -> float:
	return (bar.value - bar.min_value) / (bar.max_value - bar.min_value)
