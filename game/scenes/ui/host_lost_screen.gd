class_name HostLostScreen
extends CanvasLayer
## The "host lost" screen (coop-networking "Disconnect handling"): shown on a client when the
## host goes away. The level decides where "Volver" leads (the title or the lobby, once one
## exists).

## The player asked to leave the screen.
signal back_requested

## What the player can do next (run-menu design D8).
const NEXT_STEP: String = "Vuelve al inicio para unirte otra vez o jugar solo."

@onready var message: Label = %Message
@onready var next_step: Label = %Next
@onready var back_button: Button = %Back


func _ready() -> void:
	next_step.text = NEXT_STEP
	back_button.pressed.connect(back_requested.emit)
	back_button.grab_focus()


## Esc and the gamepad back button leave as "Volver" does.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		back_requested.emit()
		if is_inside_tree():
			get_viewport().set_input_as_handled()
