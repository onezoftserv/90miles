class_name PauseMenu
extends CanvasLayer
## The run menu (ui-shell "Run menu" and "Abandoning a run", coop-networking "Pause"; run-menu
## design D1-D5): "Seguir", "Ajustes", "Controles" and "Abandonar viaje" in every mode. Solo
## freezes the whole simulation ("Pausa"); in co-op and for a host alone nothing pauses ("Menú",
## "La partida sigue.") and only this peer's player is held still, crouch kept. Ajustes, Controles
## and the abandon question open inside it in the dark run look. Esc and the gamepad back button
## close one layer: an open view, else the menu. The back button never opens it (it is also crouch).

## "Abandonar" was confirmed: the shell ends this player's run and goes to the title.
signal abandon_confirmed
## Ajustes changed the display or "Reducir destellos": the shell applies it, as on the title.
signal display_changed
signal flashes_changed

enum Role {
	SOLO,
	HOST,
	CLIENT,
}

const ACTION: StringName = &"pause"
const CANCEL_ACTION: StringName = &"ui_cancel"
const SOLO_TAB: String = "Pausa"
const COOP_TAB: String = "Menú"
const COOP_LINE: String = "La partida sigue."
const ABANDON_QUESTION: String = "¿Abandonar el viaje?"
const ABANDON_ACTION: String = "Abandonar"
const ABANDON_LINES: Dictionary[Role, String] = {
	Role.SOLO: "Este viaje se pierde.",
	Role.HOST: "La partida se cierra para todos.",
	Role.CLIENT: "Sales de la partida. Tu balsero espera 90 s por si vuelves.",
}
const SETTINGS_SCENE: PackedScene = preload("res://scenes/shell/settings_screen.tscn")
const CONTROLS_SCENE: PackedScene = preload("res://scenes/shell/controls_card.tscn")
const CONFIRM_SCENE: PackedScene = preload("res://scenes/ui/confirm_box.tscn")

var session: CoopSession
## The install's settings, handed over by the shell; Ajustes saves into it.
var settings: GameSettings
## The open view (Ajustes, Controles or the question), or null when the buttons show.
var view: Control = null
var _opener: Button = null
var _held_body: PlayerBody = null

@onready var frame: Control = %Frame
@onready var title: Label = %Title
@onready var line: Label = %Line
@onready var resume_button: Button = %Resume
@onready var settings_button: Button = %Settings
@onready var controls_button: Button = %Controls
@onready var abandon_button: Button = %Abandon
@onready var views: Control = %Views


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(resume)
	settings_button.pressed.connect(open_settings)
	controls_button.pressed.connect(open_controls)
	abandon_button.pressed.connect(ask_abandon)


func _unhandled_input(event: InputEvent) -> void:
	var pause: bool = event.is_action_pressed(ACTION)
	var cancel: bool = event.is_action_pressed(CANCEL_ACTION)
	if not pause and not cancel:
		return
	if not visible:
		if pause and open() and is_inside_tree():
			get_viewport().set_input_as_handled()
		return
	if view != null:
		close_view()
	else:
		resume()
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func toggle() -> bool:
	return resume() if visible else open()


## Shows the menu with "Seguir" focused. Solo freezes the run; otherwise this peer's player is held.
func open() -> bool:
	if session == null or not is_instance_valid(session):
		return false
	var frozen: bool = session.set_paused(true)
	title.text = SOLO_TAB if frozen else COOP_TAB
	line.text = COOP_LINE
	line.visible = not frozen
	visible = true
	_hold(not frozen)
	resume_button.grab_focus()
	return true


## Closes the menu (and any view) and lets the run go on.
func resume() -> bool:
	close_view()
	if session != null and is_instance_valid(session):
		session.set_paused(false)
	_hold(false)
	visible = false
	return true


## This peer's part in the run: solo, the host (alone or not) or a client.
func role() -> Role:
	if session == null or not is_instance_valid(session):
		return Role.SOLO
	if session.multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return Role.SOLO
	return Role.HOST if session.multiplayer.is_server() else Role.CLIENT


func open_settings() -> void:
	if settings == null:
		return
	var screen := SETTINGS_SCENE.instantiate() as SettingsScreen
	_open_view(screen, settings_button)
	screen.bind(settings)
	screen.hide_name()
	MenuLook.to_run(screen)
	screen.back_requested.connect(close_view)
	screen.display_changed.connect(display_changed.emit)
	screen.flashes_changed.connect(flashes_changed.emit)


func open_controls() -> void:
	var card := CONTROLS_SCENE.instantiate() as ControlsCard
	_open_view(card, controls_button)
	card.for_run(role() == Role.SOLO)
	MenuLook.to_run(card)
	card.back_requested.connect(close_view)


func ask_abandon() -> void:
	var box := CONFIRM_SCENE.instantiate() as ConfirmBox
	_open_view(box, abandon_button)
	MenuLook.to_run(box)
	box.ask(ABANDON_QUESTION, ABANDON_LINES[role()], ABANDON_ACTION)
	box.confirmed.connect(_on_abandon_confirmed)
	box.cancelled.connect(close_view)


## Closes the open view and gives the focus back to the button that opened it.
func close_view() -> void:
	if view == null:
		return
	var closing: Control = view
	view = null
	closing.visible = false
	closing.queue_free()
	frame.visible = true
	if visible and _opener != null:
		_opener.grab_focus()


func _open_view(opened: Control, opener: Button) -> void:
	close_view()
	_opener = opener
	view = opened
	frame.visible = false
	views.add_child(opened)


func _on_abandon_confirmed() -> void:
	resume()
	abandon_confirmed.emit()


# Holds (or lets go of) this peer's player while the menu is open in co-op (run-menu design D2).
func _hold(on: bool) -> void:
	if is_instance_valid(_held_body):
		_held_body.menu_holds_input = false
	_held_body = null
	if not on or session == null or not is_instance_valid(session):
		return
	var body: PlayerBody = session.body(session.multiplayer.get_unique_id())
	if body != null:
		body.menu_holds_input = true
		_held_body = body
