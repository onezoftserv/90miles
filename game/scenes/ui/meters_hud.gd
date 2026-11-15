class_name MetersHud
extends Control
## The local player's survival HUD (survival-meters "HUD bars"): six labelled bars in the top-left
## corner and a blur over the screen while that player has sunstroke. It only reads one
## SurvivalMeters node, so it shows the same thing on the host and on a client. No ui-shell owns
## the 640x360 layout yet (review item 23); a later layout can move the panel.
## damage-feedback (ui-shell "Hit flash at the screen edges", "Changes show on the bars", "Drain
## glow on the health bar"; design D5, D7, D10): each frame a MeterWatch per bar sorts the bound
## body's changes. A health hit flashes the screen edges (HurtOverlay), stronger for a bigger hit
## and with a floor, at most once per flash_min_gap_s; every sorted change goes to its bar; the
## sound hook hears hits, a drain's start and jumps. Rebinding forgets the old body. Drawing only.

## A sound cue asked of AudioManager (hurt_hit, hurt_big, hurt_drain, use_done); tests listen here.
signal hurt_cued(id: StringName)

var _meters: SurvivalMeters = null
var _tuning: HurtCueTuning = HurtCues.tuning()
var _watches: Dictionary[int, MeterWatch] = {}
# The value each bar's meter had on the last frame, by DataEnums.Meter.
var _last: Dictionary[int, float] = {}
var _overlay: HurtOverlay = HurtOverlay.new()
var _flash_peak: float = 0.0
var _flash_age_s: float = 0.0
var _since_flash_start_s: float = INF
var _flashes_started: int = 0
var _draining: bool = false
var _since_drain_s: float = INF

@onready var _panel: PanelContainer = $Panel
@onready var _bars_box: VBoxContainer = $Panel/Bars
@onready var _blur: ColorRect = $Blur
@onready var _bleeding: Label = $Panel/Bars/Bleeding


## The meters this panel shows, or null.
func shown() -> SurvivalMeters:
	return _meters


func _ready() -> void:
	add_child(_overlay)
	move_child(_overlay, _blur.get_index() + 1)


func _process(delta: float) -> void:
	step(delta)


## Shows `meters` from now on and stops following the node bound before. With null the bars keep
## their last values and the blur is hidden.
func bind(meters: SurvivalMeters) -> void:
	_unbind()
	_forget()
	_meters = meters
	if meters == null:
		_blur.visible = false
		_bleeding.visible = false
		return
	meters.meter_changed.connect(_on_meter_changed)
	meters.sunstroke_changed.connect(_on_sunstroke_changed)
	meters.statuses_changed.connect(_on_statuses_changed)
	for bar: MeterBar in bars():
		bar.show_value(meters.value(bar.meter))
	_blur.visible = meters.sunstroke
	_bleeding.visible = meters.has_status(DataEnums.Status.BLEEDING)


## The rows, top to bottom.
func bars() -> Array[MeterBar]:
	var rows: Array[MeterBar] = []
	for child: Node in _bars_box.get_children():
		var bar := child as MeterBar
		if bar != null:
			rows.append(bar)
	return rows


## The row showing `meter`, or null.
func bar_for(meter: DataEnums.Meter) -> MeterBar:
	for bar: MeterBar in bars():
		if bar.meter == meter:
			return bar
	return null


func blurred() -> bool:
	return _blur.visible


## One frame of the hit, drain and change cues: each bar's meter is sorted, the flash fades and the
## drain is timed. _process calls it; tests step it by hand.
func step(delta: float) -> void:
	var shown_meters: SurvivalMeters = _meters if _meters != null and is_instance_valid(_meters) else null
	var jumped: bool = false
	for bar: MeterBar in bars():
		if shown_meters != null:
			jumped = _sort(bar, shown_meters, delta) or jumped
		bar.step(delta)
	if jumped:
		_cue(&"use_done")
	_step_flash(delta)
	_since_drain_s += delta
	if _draining and _since_drain_s >= _tuning.glow_linger_s:
		_draining = false


## The edge flash's alpha now (0 when none shows).
func flash_strength() -> float:
	return _overlay.strength()


## How many edge flashes have started since this HUD was made.
func flashes_started() -> int:
	return _flashes_started


func hurt_overlay() -> HurtOverlay:
	return _overlay


## The red "Sangrando" tag under the bars, shown while the player bleeds (status-sync).
func bleeding_tag() -> Label:
	return _bleeding


## Where the bars panel sits on screen, in HUD coordinates.
func panel_rect() -> Rect2:
	return _panel.get_rect()


func _unbind() -> void:
	if _meters != null and is_instance_valid(_meters):
		if _meters.meter_changed.is_connected(_on_meter_changed):
			_meters.meter_changed.disconnect(_on_meter_changed)
		if _meters.sunstroke_changed.is_connected(_on_sunstroke_changed):
			_meters.sunstroke_changed.disconnect(_on_sunstroke_changed)
		if _meters.statuses_changed.is_connected(_on_statuses_changed):
			_meters.statuses_changed.disconnect(_on_statuses_changed)
	_meters = null


# Sorts `bar`'s meter this frame and hands the change on; returns whether it jumped.
func _sort(bar: MeterBar, meters: SurvivalMeters, delta: float) -> bool:
	var watch: MeterWatch = _watches.get(bar.meter)
	if watch == null:
		watch = MeterWatch.new(_tuning.change_margin, _tuning.steady_forget_s)
		_watches[bar.meter] = watch
	var value: float = meters.value(bar.meter)
	var old: float = _last.get(bar.meter, value)
	_last[bar.meter] = value
	var change: MeterWatch.Change = watch.observe(value, meters.dead, delta)
	if change == MeterWatch.Change.NONE:
		return false
	bar.show_change(old, value, change)
	if bar.meter == DataEnums.Meter.HEALTH:
		if change == MeterWatch.Change.HIT:
			_on_hit(-watch.last_change)
		elif change == MeterWatch.Change.DRAIN:
			_on_drain()
	return change == MeterWatch.Change.JUMP


# A health hit of `amount`: a flash scaled by the share of Salud lost, from a floor, unless one
# started too recently (then it only rises), and the hit sound.
func _on_hit(amount: float) -> void:
	_cue(&"hurt_big" if amount >= _tuning.big_hit - MeterBar.EPSILON else &"hurt_hit")
	if HurtCues.reduce_flashes:
		return
	var strength: float = lerpf(_tuning.flash_floor, 1.0, clampf(amount / _tuning.big_hit, 0.0, 1.0))
	if _since_flash_start_s >= _tuning.flash_min_gap_s:
		_flashes_started += 1
		_since_flash_start_s = 0.0
		_flash_peak = strength
	else:
		_flash_peak = maxf(_flash_now(), strength)
	_flash_age_s = 0.0


func _on_drain() -> void:
	_since_drain_s = 0.0
	if not _draining:
		_draining = true
		_cue(&"hurt_drain")


# The flash's strength now, 0 to 1, before the alpha.
func _flash_now() -> float:
	if _flash_peak <= 0.0:
		return 0.0
	return _flash_peak * clampf(1.0 - _flash_age_s / _tuning.flash_s, 0.0, 1.0)


func _step_flash(delta: float) -> void:
	_since_flash_start_s += delta
	var now: float = _flash_now() if not HurtCues.reduce_flashes else 0.0
	_overlay.show_strength(now * _tuning.flash_alpha)
	if _flash_peak > 0.0:
		_flash_age_s += delta
		if _flash_age_s >= _tuning.flash_s - MeterBar.EPSILON:
			_flash_peak = 0.0


func _cue(id: StringName) -> void:
	AudioManager.play_sfx(id)
	hurt_cued.emit(id)


# Forgets the body shown: no change carries over to the next one.
func _forget() -> void:
	for watch: MeterWatch in _watches.values():
		watch.reset()
	_last.clear()
	for bar: MeterBar in bars():
		bar.clear_change()
	_flash_peak = 0.0
	_since_flash_start_s = INF
	_draining = false
	_since_drain_s = INF
	if _overlay.is_inside_tree():
		_overlay.show_strength(0.0)


func _on_meter_changed(meter: DataEnums.Meter, new_value: float) -> void:
	var bar := bar_for(meter)
	if bar != null:
		bar.show_value(new_value)


func _on_sunstroke_changed(active: bool) -> void:
	_blur.visible = active


func _on_statuses_changed(_flags: int) -> void:
	_bleeding.visible = _meters != null and _meters.has_status(DataEnums.Status.BLEEDING)
