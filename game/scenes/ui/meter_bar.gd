class_name MeterBar
extends HBoxContainer
## One HUD row: a 0-100 bar for one survival meter with its Spanish name and value inside the
## bar (Brogue's sidebar bars), pulsing red while the meter is critical (Shattered Pixel
## Dungeon's low-health pulse). The meter, the label and the fill color are set per instance
## in meters_hud.tscn, so changing them needs no code.
## ui-shell "Changes show on the bars" and "Drain glow on the health bar" (damage-feedback design
## D5, D10): MetersHud tells it of each change it sorted (`show_change`) and steps it each frame.
## A loss shows its lost part in pale red, held then shrunk (DCSS's changed-bar colour); a hit
## also shakes a bar that `shakes_on_hit`; a drain lights the frame of a bar that `glows_on_drain`;
## a jump shows its gained part in a light tint of the fill and flashes the bar once. The cue nodes
## are made here, inside Bar, under the labels. Drawing only.

## At or below this a meter is critical; heat is the other way round.
const CRITICAL_LOW: float = 25.0
const CRITICAL_HEAT: float = 75.0
const PULSE_HZ: float = 1.0
const PULSE_COLOR: Color = Color(1.0, 0.45, 0.4)
## Value slack for float sums.
const EPSILON: float = 0.001
## The shake moves the bar every this many seconds (2 frames at 60).
const SHAKE_STEP_S: float = 1.0 / 30.0

@export var meter: DataEnums.Meter = DataEnums.Meter.NONE
@export var label_text: String = ""
@export var fill_color: Color = Color.WHITE
## Losses show their lost part, and a hit shakes the bar (the health row).
@export var shows_losses: bool = false
## A drain lights the bar's frame (the health row).
@export var glows_on_drain: bool = false

## True while the meter is critical.
var pulsing: bool = false
var _pulse_s: float = 0.0

var _tuning: HurtCueTuning = HurtCues.tuning()
# The lost part runs from the fill up to _lost_top; below the fill it is gone.
var _lost_top: float = -1.0
var _lost_hold_s: float = 0.0
var _lost_speed: float = 0.0
# The gained part, and how long it has left (hold, then fade).
var _gain_from: float = 0.0
var _gain_to: float = 0.0
var _gain_left_s: float = 0.0
var _flash_left_s: float = 0.0
var _shake_left_s: float = 0.0
var _shake_age_s: float = 0.0
var _shake_home_x: float = 0.0
var _shaken: bool = false
var _glow_left_s: float = 0.0

@onready var bar: ProgressBar = $Bar
@onready var label: Label = $Bar/Label
@onready var value_label: Label = $Bar/Value
var _lost: ColorRect = ColorRect.new()
var _gain: ColorRect = ColorRect.new()
var _flash: ColorRect = ColorRect.new()
var _glow: Panel = Panel.new()


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
	_make_cue_nodes()
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
	_place_cues()


## How full the bar is, 0 to 1.
func fill_ratio() -> float:
	return (bar.value - bar.min_value) / (bar.max_value - bar.min_value)


## A change MetersHud sorted, from `old` (the value it saw the frame before) to `new`.
func show_change(old: float, new: float, kind: MeterWatch.Change) -> void:
	match kind:
		MeterWatch.Change.HIT, MeterWatch.Change.DRAIN:
			if not shows_losses:
				return
			var fresh: bool = not _losing()
			_lost_top = old if fresh else maxf(_lost_top, old)
			if kind == MeterWatch.Change.HIT or fresh:
				_lost_hold_s = _tuning.loss_hold_s
				_lost_speed = 0.0
			if kind == MeterWatch.Change.HIT and not HurtCues.reduce_flashes:
				if not _shaken:
					_shake_home_x = bar.position.x
					_shaken = true
				_shake_left_s = _tuning.shake_s
				_shake_age_s = 0.0
			if kind == MeterWatch.Change.DRAIN and glows_on_drain:
				_glow_left_s = _tuning.glow_linger_s
		MeterWatch.Change.JUMP:
			_gain_from = old
			_gain_to = new
			_gain_left_s = _tuning.gain_hold_s + _tuning.gain_fade_s
			if not HurtCues.reduce_flashes:
				_flash_left_s = _tuning.gain_flash_s
	_place_cues()


## Forgets every change shown (a rebind to another body).
func clear_change() -> void:
	_lost_top = -1.0
	_gain_left_s = 0.0
	_flash_left_s = 0.0
	_glow_left_s = 0.0
	_stop_shake()
	_place_cues()


## One frame of the change cues.
func step(delta: float) -> void:
	_step_lost(delta)
	if _gain_left_s > 0.0:
		_gain_left_s -= delta
	if _flash_left_s > 0.0:
		_flash_left_s -= delta
	if _glow_left_s > 0.0:
		_glow_left_s -= delta
	if _shake_left_s > 0.0:
		_shake_left_s -= delta
		_shake_age_s += delta
		if _shake_left_s <= 0.0:
			_stop_shake()
		else:
			var side: float = 1.0 if int(floor(_shake_age_s / SHAKE_STEP_S)) % 2 == 0 else -1.0
			bar.position.x = _shake_home_x + side * _tuning.shake_px
	_place_cues()


## The lost part as (from, to) on the 0-100 scale, or ZERO when none shows.
func lost_range() -> Vector2:
	return Vector2(bar.value, _lost_top) if _losing() else Vector2.ZERO


## The gained part as (from, to) on the 0-100 scale, or ZERO when none shows.
func gained_range() -> Vector2:
	return Vector2(_gain_from, minf(_gain_to, bar.value)) if _gain_left_s > 0.0 else Vector2.ZERO


func shaking() -> bool:
	return _shake_left_s > 0.0


func flashing() -> bool:
	return _flash_left_s > 0.0


func glowing() -> bool:
	return _glow_left_s > 0.0


func _losing() -> bool:
	return _lost_top > bar.value + EPSILON


# The lost part holds, then shrinks: linearly over loss_drain_s from where it stood when the hold
# ended, and never slower than its own gap over loss_drain_s, so a drain's part trails the fill.
func _step_lost(delta: float) -> void:
	if not _losing():
		_lost_top = -1.0
		return
	if _lost_hold_s > 0.0:
		_lost_hold_s -= delta
		if _lost_hold_s > 0.0:
			return
		_lost_speed = (_lost_top - bar.value) / _tuning.loss_drain_s
	var gap: float = _lost_top - bar.value
	_lost_top -= maxf(_lost_speed, gap / _tuning.loss_drain_s) * delta
	if not _losing():
		_lost_top = -1.0


func _stop_shake() -> void:
	_shake_left_s = 0.0
	if not _shaken:
		return
	_shaken = false
	bar.position.x = _shake_home_x
	queue_sort()


func _make_cue_nodes() -> void:
	for node: Control in [_lost, _gain, _flash, _glow] as Array[Control]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.visible = false
		bar.add_child(node)
	_lost.name = &"Lost"
	_lost.color = _tuning.loss_color
	_gain.name = &"Gain"
	_gain.color = fill_color.lerp(Color.WHITE, _tuning.gain_lighten)
	_flash.name = &"Flash"
	_flash.color = Color(1.0, 1.0, 1.0, 0.5)
	_glow.name = &"Glow"
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.border_color = _tuning.glow_color
	frame.set_border_width_all(1)
	_glow.add_theme_stylebox_override(&"panel", frame)
	# Under the name and the value, which are the bar's first children.
	for node: Control in [_glow, _flash, _gain, _lost] as Array[Control]:
		bar.move_child(node, 0)


func _place_cues() -> void:
	if not is_node_ready():
		return
	var width: float = bar.size.x
	var span: float = bar.max_value - bar.min_value
	_lost.visible = _losing()
	if _lost.visible:
		_place(_lost, bar.value, _lost_top, width, span)
	_gain.visible = _gain_left_s > 0.0 and _gain_to > _gain_from
	if _gain.visible:
		_place(_gain, _gain_from, minf(_gain_to, bar.value), width, span)
		_gain.modulate.a = clampf(_gain_left_s / maxf(_tuning.gain_fade_s, EPSILON), 0.0, 1.0)
	_flash.visible = _flash_left_s > 0.0
	_flash.position = Vector2.ZERO
	_flash.size = bar.size
	_glow.visible = _glow_left_s > 0.0
	_glow.position = Vector2.ZERO
	_glow.size = bar.size


func _place(node: Control, from: float, to: float, width: float, span: float) -> void:
	var left: float = (from - bar.min_value) / span * width
	var right: float = (to - bar.min_value) / span * width
	node.position = Vector2(left, 0.0)
	node.size = Vector2(maxf(right - left, 0.0), bar.size.y)
