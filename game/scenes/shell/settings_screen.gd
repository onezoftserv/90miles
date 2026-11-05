class_name SettingsScreen
extends Control
## ui-shell "Settings": the player name, fullscreen and the scale, saved as soon as they change.

signal back_requested
## Fullscreen or the scale changed: the shell re-applies the window.
signal display_changed

const SCALE_LABELS: Array[String] = ["Automática", "1×", "2×", "3×", "4×"]

var settings: GameSettings = GameSettings.new()

@onready var name_field: LineEdit = %Name
@onready var fullscreen_box: CheckBox = %Fullscreen
@onready var scale_picker: OptionButton = %Scale
@onready var back_button: Button = %Back


func _ready() -> void:
	for label: String in SCALE_LABELS:
		scale_picker.add_item(label)
	name_field.max_length = GameSettings.MAX_NAME_LENGTH
	name_field.text_submitted.connect(_on_name)
	name_field.focus_exited.connect(func() -> void: _on_name(name_field.text))
	fullscreen_box.toggled.connect(_on_fullscreen)
	scale_picker.item_selected.connect(_on_scale)
	back_button.pressed.connect(_back)
	name_field.grab_focus()


## Shows `source` and saves into it from now on.
func bind(source: GameSettings) -> void:
	settings = source
	name_field.text = settings.player_name
	fullscreen_box.set_pressed_no_signal(settings.fullscreen)
	scale_picker.select(settings.ui_scale)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_back()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


func _back() -> void:
	_on_name(name_field.text)
	back_requested.emit()


func _on_name(text: String) -> void:
	settings.player_name = text
	name_field.text = settings.player_name
	settings.save()


func _on_fullscreen(on: bool) -> void:
	settings.fullscreen = on
	settings.save()
	display_changed.emit()


func _on_scale(index: int) -> void:
	settings.ui_scale = index
	settings.save()
	display_changed.emit()
