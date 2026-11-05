class_name MeterBar
extends HBoxContainer
## One HUD row: a 0-100 bar for one survival meter with its Spanish name and value inside the
## bar (Brogue's sidebar bars), pulsing red while the meter is critical (Shattered Pixel
## Dungeon's low-health pulse). The meter, the label and the fill color are set per instance
## in meters_hud.tscn, so changing them needs no code.

## At or below this a meter is critical; heat is the other way round.
const CRITICAL_LOW: float = 25.0
const CRITICAL_HEAT: float = 75.0
const PULSE_HZ: float = 1.0
const PULSE_COLOR: Color = Color(1.0, 0.45, 0.4)

@export var meter: DataEnums.Meter = DataEnums.Meter.NONE
@export var label_text: String = ""
@export var fill_color: Color = Color.WHITE

## True while the meter is critical.
var pulsing: bool = false
var _pulse_s: float = 0.0

@onready var bar: ProgressBar = $Bar
@onready var label: Label = $Bar/Label
@onready var value_label: Label = $Bar/Value


## Whether `value` of `which` is critical: heat at CRITICAL_HEAT or more, any other meter at
## CRITICAL_LOW or less.
static func is_critical(which: DataEnums.Meter, value: float) -> bool:
	if which == DataEnums.Meter.HEAT:
		return value >= CRITICAL_HEAT
	return value <= CRITICAL_LOW


func _ready() -> void:
	label.text = label_text
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	bar.add_theme_stylebox_override(&"fill", fill)
	show_value(bar.value)


func _process(delta: float) -> void:
	if not pulsing:
		return
	_pulse_s += delta
	bar.modulate = Color.WHITE.lerp(PULSE_COLOR, (sin(_pulse_s * TAU * PULSE_HZ) + 1.0) / 2.0)


func show_value(new_value: float) -> void:
	bar.value = new_value
	value_label.text = "%d" % roundi(new_value)
	pulsing = is_critical(meter, new_value)
	if not pulsing:
		_pulse_s = 0.0
		bar.modulate = Color.WHITE


## How full the bar is, 0 to 1.
func fill_ratio() -> float:
	return (bar.value - bar.min_value) / (bar.max_value - bar.min_value)
