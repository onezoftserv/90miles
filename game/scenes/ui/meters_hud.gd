class_name MetersHud
extends Control
## The local player's survival HUD (survival-meters "HUD bars"): six labelled bars in the top-left
## corner and a blur over the screen while that player has sunstroke. It only reads one
## SurvivalMeters node, so it shows the same thing on the host and on a client. No ui-shell owns
## the 640x360 layout yet (review item 23); a later layout can move the panel.

var _meters: SurvivalMeters = null

@onready var _panel: PanelContainer = $Panel
@onready var _bars_box: VBoxContainer = $Panel/Bars
@onready var _blur: ColorRect = $Blur


## The meters this panel shows, or null.
func shown() -> SurvivalMeters:
	return _meters


## Shows `meters` from now on and stops following the node bound before. With null the bars keep
## their last values and the blur is hidden.
func bind(meters: SurvivalMeters) -> void:
	_unbind()
	_meters = meters
	if meters == null:
		_blur.visible = false
		return
	meters.meter_changed.connect(_on_meter_changed)
	meters.sunstroke_changed.connect(_on_sunstroke_changed)
	for bar: MeterBar in bars():
		bar.show_value(meters.value(bar.meter))
	_blur.visible = meters.sunstroke


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


## Where the bars panel sits on screen, in HUD coordinates.
func panel_rect() -> Rect2:
	return _panel.get_rect()


func _unbind() -> void:
	if _meters != null and is_instance_valid(_meters):
		if _meters.meter_changed.is_connected(_on_meter_changed):
			_meters.meter_changed.disconnect(_on_meter_changed)
		if _meters.sunstroke_changed.is_connected(_on_sunstroke_changed):
			_meters.sunstroke_changed.disconnect(_on_sunstroke_changed)
	_meters = null


func _on_meter_changed(meter: DataEnums.Meter, new_value: float) -> void:
	var bar := bar_for(meter)
	if bar != null:
		bar.show_value(new_value)


func _on_sunstroke_changed(active: bool) -> void:
	_blur.visible = active
