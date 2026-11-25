class_name ConfirmBox
extends Control
## A yes-or-no question (run-menu design D5): the question, a line saying what follows, "Cancelar"
## (focused, so a held or doubled accept press keeps things as they are, as DCSS's yesno defaults to
## no) and the action button. Drawn on paper; MenuLook.to_run turns it dark inside a run. Esc and the
## gamepad back button cancel.

signal confirmed
signal cancelled

const CANCEL_TEXT: String = "Cancelar"

@onready var question: Label = %Question
@onready var line: Label = %Line
@onready var cancel_button: Button = %Cancel
@onready var confirm_button: Button = %Confirm


func _ready() -> void:
	cancel_button.text = CANCEL_TEXT
	cancel_button.pressed.connect(cancelled.emit)
	confirm_button.pressed.connect(confirmed.emit)


## Shows `question_text`, `line_text` (hidden when empty) and the action `action_text`, with
## "Cancelar" focused.
func ask(question_text: String, line_text: String, action_text: String) -> void:
	question.text = question_text
	line.text = line_text
	line.visible = not line_text.is_empty()
	confirm_button.text = action_text
	visible = true
	cancel_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		cancelled.emit()
		if is_inside_tree():
			get_viewport().set_input_as_handled()
