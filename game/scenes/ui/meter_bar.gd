class_name MeterBar
extends HBoxContainer
## One HUD row on a strict grid (survival-meters "HUD bars", ui-shell "HUD layout"; hud-window-kit
## design D4): the Spanish label in a 56 px column, a 40x7 bar box at a fixed x (a 1 px outline round
## a 38x5 bar filled from the meter's own pre-shaded ramp, its empty part the ramp's darkest step),
## and the value right-aligned. DCSS's `_print_stats_hp` grid and `hp_colour` steps: the label turns
## a steady orange at the warning step and the alert red at the critical one, and never pulses; at the
## critical step the bar's outline and the value pulse instead (SPD's low-health pulse, off the text).
## Brogue's `printProgressBar` edge, in palette steps: a fill edge holding less than half a pixel is a
## shade column, so a sliver never reads as empty. The meter, label, ramp and colours are set per
## instance in meters_hud.tscn, so changing them needs no code.
## ui-shell "Changes show on the bars" and "Drain glow on the health bar" (damage-feedback design
## D5, D10): MetersHud tells it of each change it sorted (`show_change`) and steps it each frame.
## A loss shows its lost part in the alert red, held then shrunk (DCSS's changed-bar colour); a hit
## also shakes the bar box of a bar that `shows_losses`; a drain lights the box's outline of a bar
## that `glows_on_drain`; a jump shows its gained part in the ramp's highlight and flashes the bar
## once. The cue nodes are made here, inside the bar and its box. Drawing only.
## hud-clarity (survival-meters "HUD bars"): a bar with `zones` (Calor) is a thermometer: its empty
## track shows a dark tint per zone (below 50, 50 to 75, 75 and up) instead of the plain empty colour,
## and 1 px notches stand just above and below the box at the warning and critical steps, orange and
## alert red.

## At or below this a meter is critical; heat is the other way round.
const CRITICAL_LOW: float = 25.0
const CRITICAL_HEAT: float = 75.0
## At or below this a meter is at its warning step; heat is the other way round.
const WARN_LOW: float = 50.0
const WARN_HEAT: float = 50.0
const PULSE_HZ: float = 1.0
const PULSE_COLOR: Color = HudStyle.ALERT
## Value slack for float sums.
const EPSILON: float = 0.001
## The shake moves the bar every this many seconds (2 frames at 60).
const SHAKE_STEP_S: float = 1.0 / 30.0
## The bar's fill area, inside the box's 1 px outline.
const FILL_SIZE: Vector2 = Vector2(38.0, 5.0)

## The label's steps (design D4).
enum Step { CALM, WARNING, CRITICAL }

@export var meter: DataEnums.Meter = DataEnums.Meter.NONE
@export var label_text: String = ""
## The ramp's base colour, kept equal to HurtCueTuning.meter_colors (a test checks both).
@export var fill_color: Color = Color.WHITE
## The meter's 1x5 ramp strip (tools/art/ui_kit.json): highlight, base x3, shade.
@export var ramp: Texture2D = null
## The empty part of the bar: the darkest step of the meter's ramp.
@export var empty_color: Color = HudStyle.OUTLINE
## The thermometer's dark track tints, one per zone (below WARN_HEAT, to CRITICAL_HEAT, and up);
## empty for a plain bar.
@export var zones: PackedColorArray = PackedColorArray()
## Losses show their lost part, and a hit shakes the bar (the health row).
@export var shows_losses: bool = false
## A drain lights the bar's frame (the health row).
@export var glows_on_drain: bool = false

## True while the meter is critical.
var pulsing: bool = false
var _pulse_s: float = 0.0
var _highlight: Color = Color.WHITE
var _shade: Color = Color.BLACK

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
var _outline_style: StyleBoxFlat = null

@onready var label: Label = $Label
@onready var value_label: Label = $Value
## The 40x7 box (outline and bar) that shakes.
@onready var box: Control = $Cell/Box
@onready var outline: Panel = $Cell/Box/Outline
@onready var bar: ProgressBar = $Cell/Box/Bar
var _lost: ColorRect = ColorRect.new()
var _gain: ColorRect = ColorRect.new()
var _flash: ColorRect = ColorRect.new()
var _edge: ColorRect = ColorRect.new()
var _zone_rects: Array[ColorRect] = []
var _notches: Array[ColorRect] = []
var _glow: Panel = Panel.new()


## Whether `value` of `which` is critical: heat at CRITICAL_HEAT or more, any other meter at
## CRITICAL_LOW or less.
static func is_critical(which: DataEnums.Meter, value: float) -> bool:
	if which == DataEnums.Meter.HEAT:
		return value >= CRITICAL_HEAT
	return value <= CRITICAL_LOW


## The label's step for `value` of `which`: critical, warning (50 or less, heat 50 or more) or calm.
static func step_of(which: DataEnums.Meter, value: float) -> Step:
	if is_critical(which, value):
		return Step.CRITICAL
	if which == DataEnums.Meter.HEAT:
		return Step.WARNING if value >= WARN_HEAT else Step.CALM
	return Step.WARNING if value <= WARN_LOW else Step.CALM


## The label's steady colour on `step`.
static func step_color(step: Step) -> Color:
	match step:
		Step.WARNING:
			return HudStyle.ORANGE
		Step.CRITICAL:
			return HudStyle.ALERT
	return HudStyle.CREAM


func _ready() -> void:
	label.text = label_text
	_outline_style = (outline.get_theme_stylebox(&"panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	outline.add_theme_stylebox_override(&"panel", _outline_style)
	_style_bar()
	_make_cue_nodes()
	show_value(bar.value)


func _process(delta: float) -> void:
	if not pulsing:
		return
	_pulse_s += delta
	_show_alert((sin(_pulse_s * TAU * PULSE_HZ) + 1.0) / 2.0)


func show_value(new_value: float) -> void:
	bar.value = new_value
	value_label.text = "%d" % roundi(new_value)
	label.add_theme_color_override(&"font_color", step_color(step_of(meter, new_value)))
	pulsing = is_critical(meter, new_value)
	if not pulsing:
		_pulse_s = 0.0
		_show_alert(0.0)
	_place_cues()


## How full the bar is, 0 to 1.
func fill_ratio() -> float:
	return (bar.value - bar.min_value) / (bar.max_value - bar.min_value)


## The label's colour now.
func label_color() -> Color:
	return label.get_theme_color(&"font_color")


## The box outline's colour now.
func outline_color() -> Color:
	return _outline_style.border_color if _outline_style != null else HudStyle.OUTLINE


## The edge column as (x, colour) in the bar, or (-1, transparent) when the fill ends on a whole
## column.
func edge_column() -> Array:
	return [_edge.position.x, _edge.color] if _edge.visible else [-1.0, Color.TRANSPARENT]


## Full columns of the fill: the engine's own rounding (a remainder of half a pixel or more fills one
## more column).
func full_columns() -> int:
	return roundi(fill_ratio() * bar.size.x)


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
					_shake_home_x = box.position.x
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
			box.position.x = _shake_home_x + side * _tuning.shake_px
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


# The fill from the ramp (each row keeps its colour when stretched across), the empty part flat.
func _style_bar() -> void:
	bar.custom_minimum_size = Vector2.ZERO
	if zones.is_empty():
		var empty := StyleBoxFlat.new()
		empty.bg_color = empty_color
		empty.anti_aliasing = false
		bar.add_theme_stylebox_override(&"background", empty)
	else:
		bar.add_theme_stylebox_override(&"background", StyleBoxEmpty.new())
		_make_zones()
	if ramp != null:
		var fill := StyleBoxTexture.new()
		fill.texture = ramp
		bar.add_theme_stylebox_override(&"fill", fill)
		var strip: Image = ramp.get_image()
		if strip != null:
			_highlight = strip.get_pixel(0, 0)
			_shade = strip.get_pixel(0, strip.get_height() - 1)
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = fill_color
		flat.anti_aliasing = false
		bar.add_theme_stylebox_override(&"fill", flat)
		_highlight = fill_color.lerp(Color.WHITE, _tuning.gain_lighten)
		_shade = fill_color.darkened(0.4)


# The pulse at `amount` (0: steady, 1: full alert) on the outline and the value, never the label.
# A drain's glow shows in the outline's place when no pulse runs.
func _show_alert(amount: float) -> void:
	if _outline_style != null:
		_outline_style.border_color = HudStyle.OUTLINE.lerp(PULSE_COLOR, amount)
	value_label.add_theme_color_override(&"font_color", HudStyle.CREAM.lerp(PULSE_COLOR, amount))


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
	box.position.x = _shake_home_x


# The thermometer: a tint per zone under the bar (the fill covers the full part), drawn in the box
# before the bar, and a notch at each step's column, 1 px above and 1 px below the box.
func _make_zones() -> void:
	var edges: Array[float] = [0.0, WARN_HEAT, CRITICAL_HEAT, bar.max_value]
	for i: int in mini(zones.size(), edges.size() - 1):
		var tint := ColorRect.new()
		tint.name = &"Zone%d" % i
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tint.color = zones[i]
		var from: float = floorf(edges[i] / bar.max_value * FILL_SIZE.x)
		var to: float = floorf(edges[i + 1] / bar.max_value * FILL_SIZE.x)
		tint.position = bar.position + Vector2(from, 0.0)
		tint.size = Vector2(to - from, FILL_SIZE.y)
		box.add_child(tint)
		box.move_child(tint, bar.get_index())
		_zone_rects.append(tint)
	var cell := box.get_parent() as Control
	for step: Array in [[WARN_HEAT, HudStyle.ORANGE], [CRITICAL_HEAT, HudStyle.ALERT]]:
		var x: float = box.position.x + bar.position.x + floorf(float(step[0]) / bar.max_value * FILL_SIZE.x)
		for y: float in [box.position.y - 1.0, box.position.y + box.size.y]:
			var notch := ColorRect.new()
			notch.name = &"Notch"
			notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			notch.color = step[1]
			notch.position = Vector2(x, y)
			notch.size = Vector2.ONE
			cell.add_child(notch)
			_notches.append(notch)


## The thermometer's zone tints as rects in the bar's own pixels, left to right; empty for a plain bar.
func zone_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for tint: ColorRect in _zone_rects:
		rects.append(Rect2(tint.position - bar.position, tint.size))
	return rects


## Whether the track's plain empty colour shows (false on a thermometer).
func empty_shown() -> bool:
	return not bar.get_theme_stylebox(&"background") is StyleBoxEmpty


## The notches' columns in the bar's own pixels, one per step.
func notch_xs() -> Array[float]:
	var xs: Array[float] = []
	for notch: ColorRect in _notches:
		var x: float = notch.position.x - box.position.x - bar.position.x
		if not xs.has(x):
			xs.append(x)
	return xs


func _make_cue_nodes() -> void:
	for node: Control in [_edge, _lost, _gain, _flash] as Array[Control]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.visible = false
		bar.add_child(node)
	_edge.name = &"Edge"
	_edge.color = _shade
	_lost.name = &"Lost"
	_lost.color = _tuning.loss_color
	_gain.name = &"Gain"
	_gain.color = _highlight
	_flash.name = &"Flash"
	_flash.color = Color(1.0, 1.0, 1.0, 0.5)
	_glow.name = &"Glow"
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.visible = false
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.border_color = _tuning.glow_color
	frame.anti_aliasing = false
	frame.set_border_width_all(1)
	_glow.add_theme_stylebox_override(&"panel", frame)
	box.add_child(_glow)


func _place_cues() -> void:
	if not is_node_ready():
		return
	var width: float = FILL_SIZE.x
	var span: float = bar.max_value - bar.min_value
	_place_edge(width)
	_lost.visible = _losing()
	if _lost.visible:
		_place(_lost, bar.value, _lost_top, width, span)
	_gain.visible = _gain_left_s > 0.0 and _gain_to > _gain_from
	if _gain.visible:
		_place(_gain, _gain_from, minf(_gain_to, bar.value), width, span)
		_gain.modulate.a = clampf(_gain_left_s / maxf(_tuning.gain_fade_s, EPSILON), 0.0, 1.0)
	_flash.visible = _flash_left_s > 0.0
	_flash.position = Vector2.ZERO
	_flash.size = FILL_SIZE
	_glow.visible = _glow_left_s > 0.0 and not pulsing
	_glow.position = Vector2.ZERO
	_glow.size = box.size


# A remainder under half a pixel draws one shade column at the fill's end; from half a pixel up the
# engine's rounding already fills that column.
func _place_edge(width: float) -> void:
	var exact: float = fill_ratio() * width
	var whole: float = floorf(exact)
	var remainder: float = exact - whole
	_edge.visible = remainder > EPSILON and remainder < 0.5
	if _edge.visible:
		_edge.position = Vector2(whole, 0.0)
		_edge.size = Vector2(1.0, FILL_SIZE.y)


func _place(node: Control, from: float, to: float, width: float, span: float) -> void:
	var left: float = (from - bar.min_value) / span * width
	var right: float = (to - bar.min_value) / span * width
	node.position = Vector2(left, 0.0)
	node.size = Vector2(maxf(right - left, 0.0), FILL_SIZE.y)
