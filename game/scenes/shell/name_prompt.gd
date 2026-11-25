class_name NamePrompt
extends Control
## ui-shell "First-launch name" (run-menu design D7): a paper window over the title asking the
## player's name, once per install. "Listo" or Enter keeps the cleaned name (a blank keeps
## "Balsero"); Esc skips. Either way the install is marked as asked, and "Ajustes" still changes the
## name later. The idea of SPD's first-run welcome, as one short question.

## The window is done: the settings are saved and it can go.
signal closed

const QUESTION: String = "¿Cómo te llamas?"
const DONE_TEXT: String = "Listo"

var settings: GameSettings

@onready var question: Label = %Question
@onready var field: LineEdit = %Field
@onready var done_button: Button = %Done


func _ready() -> void:
	question.text = QUESTION
	done_button.text = DONE_TEXT
	field.max_length = GameSettings.MAX_NAME_LENGTH
	field.placeholder_text = GameSettings.DEFAULT_NAME
	field.text_submitted.connect(func(_text: String) -> void: give())
	done_button.pressed.connect(give)


## Asks for the name that `source` keeps, with the field focused.
func ask(source: GameSettings) -> void:
	settings = source
	field.text = ""
	field.grab_focus()


## Keeps the typed name (cleaned; a blank keeps the default) and closes.
func give() -> void:
	if settings != null:
		settings.player_name = field.text
	_finish()


## Closes keeping the name as it is.
func skip() -> void:
	_finish()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		skip()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


func _finish() -> void:
	if settings != null:
		settings.name_asked = true
		settings.save()
	closed.emit()
