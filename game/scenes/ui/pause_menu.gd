class_name PauseMenu
extends CanvasLayer
## The solo pause menu (coop-networking "Pause", approved 2026-11-05): the pause button (Esc,
## gamepad Start) freezes the whole simulation in a solo session and shows this menu; in co-op
## it does nothing. The menu itself keeps running while the tree is paused. Save-and-quit is
## not part of it yet.

const ACTION: StringName = &"pause"

## The session this menu pauses. Set by the level.
var session: CoopSession

@onready var title: Label = %Title
@onready var resume_button: Button = %Resume


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(resume)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(ACTION):
		toggle()
		if is_inside_tree():
			get_viewport().set_input_as_handled()


func toggle() -> bool:
	return resume() if visible else open()


## Pauses and shows the menu. Returns false (and shows nothing) when the session may not pause.
func open() -> bool:
	if session == null or not session.set_paused(true):
		return false
	visible = true
	resume_button.grab_focus()
	return true


## Resumes the simulation and hides the menu.
func resume() -> bool:
	if session != null:
		session.set_paused(false)
	visible = false
	return true
