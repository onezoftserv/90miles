class_name SignNote
extends Control
## The sign note (inventory-hud "Sign note", "Closing the sign note"; ui-shell "HUD layout"; design
## D2, D3): opened by the local player's interact press on a flavour sign, on this peer's HUD only.
## A light card (HudNote: cream fill, dark text) 240 px wide at (200, 22), under the day phase, holds
## the sign's line in the game's language word-wrapped to at most 8 lines, a 4 px gap and the close
## line "[E] Cerrar" with the device's key; its height is fitted to the text as laid out. It never
## pauses. It closes when the player presses interact or pause (it takes both before anything else,
## pause before the pause menu), leaves the sign's reach, goes down or leaves, or a screen shows.
## While it is open, and until interact is let go after it closes, the player's intent carries no
## interact press (`PlayerBody.hud_holds_interact`), so the host never sees a press meant for the note.

signal opened
signal closed

const POSITION: Vector2 = Vector2(200.0, 22.0)
const WIDTH: float = 240.0
## Space inside the card's edge.
const PADDING: Vector2 = Vector2(4.0, 3.0)
const LINE_HEIGHT: float = 10.0
## The gap between the text and the close line.
const GAP: float = 4.0
## The most lines a sign's text may take; a data test holds every sign to it.
const MAX_LINES: int = 8
const TEXT_WIDTH: float = WIDTH - 2.0 * PADDING.x
const TEXT_VARIATION: StringName = &"HudNoteText"
const INTERACT_ACTION: StringName = &"interact"
const PAUSE_ACTION: StringName = &"pause"
const CLOSE_LINE: StringName = &"close_note"

## The local player, or null.
var body: PlayerBody = null
var session: CoopSession = null
var text: HudText = HudText.load_default()
var device: InputLabels.Device = InputLabels.Device.KEYBOARD
## Whether the HUD takes input now (no pause menu, summary or host-lost screen); RunHud answers.
var input_open: Callable = func() -> bool: return true
var screen_shown: bool = false
## The sign the note is open at, or null.
var sign_node: IslandSign = null
var _open: bool = false
# The body whose interact press this note holds, until interact is let go.
var _held_body: PlayerBody = null

@onready var card: PanelContainer = $Card
@onready var text_label: Label = $Text
@onready var close_label: Label = $Close


## How many lines `line` takes wrapped to the card's text width, measured with the theme's font.
static func wrap_count(line: String) -> int:
	var probe := Label.new()
	probe.theme_type_variation = TEXT_VARIATION
	probe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	probe.visible = false
	# In the tree, so the theme's variation (its font) applies as it does to the note's own label.
	(Engine.get_main_loop() as SceneTree).root.add_child(probe)
	probe.size = Vector2(TEXT_WIDTH, LINE_HEIGHT)
	probe.text = line
	var count: int = probe.get_line_count()
	probe.get_parent().remove_child(probe)
	probe.free()
	return count


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Runs while the solo pause freezes the run, so a held interact is let go of there too.
	process_mode = Node.PROCESS_MODE_ALWAYS
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	visible = false


## Follows `player` from now on; an open note closes.
func bind(player: PlayerBody, run_session: CoopSession = null) -> void:
	close()
	_let_go()
	body = player
	session = run_session


func set_device(value: InputLabels.Device) -> void:
	device = value
	if _open:
		close_label.text = _close_line()


func set_screen_shown(value: bool) -> void:
	screen_shown = value
	if value:
		close()


func is_open() -> bool:
	return _open


## Opens the note at `at` for the bound player.
func open(at: IslandSign) -> void:
	if not is_instance_valid(body) or not is_instance_valid(at) or screen_shown or not input_open.call():
		return
	sign_node = at
	_hold()
	_open = true
	_lay_out()
	visible = true
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	sign_node = null
	closed.emit()


## The sign's line as the note shows it; "" while closed.
func text_shown() -> String:
	return text_label.text if _open else ""


## The close line with the device's key ("[E] Cerrar"); "" while closed.
func close_text() -> String:
	return close_label.text if _open else ""


## How many lines the note's text takes as laid out.
func line_count() -> int:
	return text_label.get_line_count()


## The card's rect in HUD pixels.
func card_rect() -> Rect2:
	return card.get_global_rect()


# Pause and interact first, before the pause menu and before anything else takes the press.
func _input(event: InputEvent) -> void:
	if not _open or event.is_echo():
		return
	if event.is_action_pressed(PAUSE_ACTION) or event.is_action_pressed(INTERACT_ACTION):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _open and not _may_stay_open():
		close()
	elif _open:
		close_label.text = _close_line()
	if _held_body != null and not _open and not Input.is_action_pressed(INTERACT_ACTION):
		_let_go()


func _may_stay_open() -> bool:
	if not is_instance_valid(body) or not is_instance_valid(sign_node) or screen_shown or not input_open.call():
		return false
	if body.downed or body.left_island:
		return false
	return body.global_position.distance_to(sign_node.global_position) <= PlayerBody.HOLD_REACH_PX


# The text wrapped to the card, the card as tall as it, the close line under it.
func _lay_out() -> void:
	text_label.size = Vector2(TEXT_WIDTH, LINE_HEIGHT)
	text_label.text = sign_node.line(CoopSession.locale_of(session))
	var lines: int = maxi(text_label.get_line_count(), 1)
	var text_height: float = lines * LINE_HEIGHT
	text_label.size = Vector2(TEXT_WIDTH, text_height)
	text_label.position = POSITION + PADDING
	close_label.text = _close_line()
	close_label.size = Vector2(TEXT_WIDTH, LINE_HEIGHT)
	close_label.position = POSITION + PADDING + Vector2(0.0, text_height + GAP)
	card.position = POSITION
	card.size = Vector2(WIDTH, 2.0 * PADDING.y + text_height + GAP + LINE_HEIGHT)


func _close_line() -> String:
	var locale: String = CoopSession.locale_of(session)
	var key: String = InputLabels.label_for(INTERACT_ACTION, device, text, locale)
	return text.line(CLOSE_LINE, locale) % key


func _hold() -> void:
	if _held_body != body:
		_let_go()
	_held_body = body
	body.hud_holds_interact = true


func _let_go() -> void:
	if is_instance_valid(_held_body):
		_held_body.hud_holds_interact = false
	_held_body = null
