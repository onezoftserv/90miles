class_name ScenePanel
extends Control
## guardacostas-capture design.md §9 (owner decision 11a, spec "The capture scene"): the minimal scene
## panel, the first piece of npcs-dialogue's Dialogue UI. While the session's CaptureScene plays, every
## peer's HUD shows a light card (HudNote, as the sign note) 400 px wide near the bottom of the
## 640×360 view: the speaker's name, then the current line in this peer's language, revealed at
## 40 chars/s and word-wrapped to at most MAX_LINES. No portraits and no choices. The host paces the
## lines; this panel only draws what the scene holds, so every peer shows the same line.

const WIDTH: float = 400.0
const POSITION: Vector2 = Vector2(120.0, 262.0)
const PADDING: Vector2 = Vector2(4.0, 3.0)
const LINE_HEIGHT: float = 10.0
## The most lines a scene line may take; a test holds every line of la_captura to it.
const MAX_LINES: int = 7
const TEXT_WIDTH: float = WIDTH - 2.0 * PADDING.x
const CARD_VARIATION: StringName = &"HudNote"
const TEXT_VARIATION: StringName = &"HudNoteText"

var scene: CaptureScene = null
var locale: String = CoopSession.DEFAULT_LOCALE
var screen_shown: bool = false
## Seconds since the current line was shown.
var elapsed_s: float = 0.0

var _serial: int = 0
var _card: PanelContainer = PanelContainer.new()
var _name: Label = Label.new()
var _text: Label = Label.new()


func _init() -> void:
	name = "ScenePanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_card.theme_type_variation = CARD_VARIATION
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.position = POSITION
	add_child(_card)
	for label: Label in [_name, _text]:
		label.theme_type_variation = TEXT_VARIATION
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	_name.position = POSITION + PADDING
	_name.size = Vector2(TEXT_WIDTH, LINE_HEIGHT)
	_text.position = POSITION + PADDING + Vector2(0.0, LINE_HEIGHT + 2.0)
	_text.size = Vector2(TEXT_WIDTH, LINE_HEIGHT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Follows `session`'s capture scene, in its language.
func bind(session: CoopSession) -> void:
	scene = session.capture if session != null else null
	locale = CoopSession.locale_of(session)


func _process(delta: float) -> void:
	step(delta)


## One frame: shows the scene's current line (a new one starts its reveal again) and reveals more.
func step(delta: float) -> void:
	var playing: bool = scene != null and is_instance_valid(scene) and scene.playing and scene.current_serial > 0
	visible = playing and not screen_shown
	if not playing:
		_serial = 0
		return
	if scene.current_serial != _serial:
		_serial = scene.current_serial
		elapsed_s = 0.0
		_name.text = scene.current_speaker_name(locale)
		_text.text = scene.current_text(locale)
		_fit()
	else:
		elapsed_s += delta
	_text.visible_characters = revealed_chars()


## The characters of the current line revealed now: 40 a second, all of them at the end.
func revealed_chars() -> int:
	return mini(floori(elapsed_s * CaptureScene.REVEAL_CHARS_PER_S), _text.text.length())


func shown_name() -> String:
	return _name.text


func shown_text() -> String:
	return _text.text


## The card's rectangle in the HUD (a test holds it inside the 640×360 view).
func card_rect() -> Rect2:
	return Rect2(_card.position, _card.size)


# The card fits the name and the wrapped text (measured with the theme's font: the label's own count
# is not laid out yet in the frame its text changes).
func _fit() -> void:
	var lines: int = clampi(wrap_count(_text.text), 1, MAX_LINES)
	_text.size = Vector2(TEXT_WIDTH, LINE_HEIGHT * lines)
	_card.size = Vector2(WIDTH, PADDING.y * 2.0 + LINE_HEIGHT * (lines + 1) + 2.0)


## How many lines `line` takes wrapped to the panel's text width, measured with the theme's font.
static func wrap_count(line: String) -> int:
	var probe := Label.new()
	probe.theme_type_variation = TEXT_VARIATION
	probe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	probe.visible = false
	(Engine.get_main_loop() as SceneTree).root.add_child(probe)
	probe.size = Vector2(TEXT_WIDTH, LINE_HEIGHT)
	probe.text = line
	var count: int = probe.get_line_count()
	probe.queue_free()
	return count


## The host skips a line with interact (in solo, the player); a client cannot, so the line never
## differs between peers.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or scene == null or not event.is_action_pressed(&"interact"):
		return
	if scene.is_inside_tree() and scene.multiplayer.is_server():
		scene.skip()
		get_viewport().set_input_as_handled()
