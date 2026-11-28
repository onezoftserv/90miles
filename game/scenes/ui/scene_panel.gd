class_name ScenePanel
extends Control
## guardacostas-capture design.md §9 (owner decision 11a, spec "The capture scene"), staged by
## art-guardacostas D10 and D11 (specs "Capture staging", "Capture advance cue"): the scene panel, the
## first piece of npcs-dialogue's Dialogue UI. While the session's CaptureScene plays, every peer's HUD
## shows a light card (HudNote, as the sign note) 440 px wide whose bottom sits at y 330 of the 640×360
## view: at its left the speaker's 32×32 portrait in a dark 36×36 frame (an NPC's from its data, a
## player's own figure in their slot's clothing for a plea), then the speaker's name and the current line
## in this peer's language, revealed at 40 chars/s and word-wrapped to at most MAX_LINES. Once the line is
## all shown, a blinking arrow with the interact key shows where a press skips (solo and the host); a
## client, which cannot skip, sees a 1 px bar under the text drain over the line's hold. No choices. The
## host paces the lines; this panel only draws what the scene holds, so every peer shows the same line.

const WIDTH: float = 440.0
## The card's left edge and the y its bottom sits on.
const LEFT: float = 100.0
const BOTTOM: float = 330.0
const PADDING: Vector2 = Vector2(4.0, 3.0)
const LINE_HEIGHT: float = 10.0
## The most lines a scene line may take; a test holds every line of la_captura to it.
const MAX_LINES: int = 7
## The portrait and its dark frame.
const PORTRAIT_SIZE: Vector2 = Vector2(32.0, 32.0)
const FRAME_SIZE: Vector2 = Vector2(36.0, 36.0)
## The text's left edge inside the card: past the frame and a 4 px gap.
const TEXT_LEFT: float = PADDING.x + FRAME_SIZE.x + 4.0
const TEXT_WIDTH: float = WIDTH - TEXT_LEFT - PADDING.x
const CARD_VARIATION: StringName = &"HudNote"
const TEXT_VARIATION: StringName = &"HudNoteText"
const FRAME_VARIATION: StringName = &"HudPanel"
## The advance arrow: the kit's arrow_down, 0.3 s on and 0.2 s off.
const ARROW_TEXTURE: Texture2D = preload("res://assets/art/ui/arrow_down.png")
const ARROW_ON_S: float = 0.3
const ARROW_OFF_S: float = 0.2
const ARROW_TINT: Color = HudStyle.OUTLINE
const KEY_FORMAT: String = "[%s]"
## The client's drain bar.
const DRAIN_COLOR: Color = HudStyle.OUTLINE
const INTERACT_ACTION: StringName = &"interact"

var scene: CaptureScene = null
var locale: String = CoopSession.DEFAULT_LOCALE
var screen_shown: bool = false
## The device the interact key is named for (the HUD passes it on).
var device: InputLabels.Device = InputLabels.Device.KEYBOARD
## Seconds since the current line was shown.
var elapsed_s: float = 0.0

var _session: CoopSession = null
var _serial: int = 0
var _hold_s: float = 0.0
var _card: PanelContainer = PanelContainer.new()
var _frame: PanelContainer = PanelContainer.new()
var _portrait: TextureRect = TextureRect.new()
var _name: Label = Label.new()
var _text: Label = Label.new()
var _arrow: TextureRect = TextureRect.new()
var _key: Label = Label.new()
var _drain: ColorRect = ColorRect.new()
var _hud_text: HudText = HudText.load_default()
# Look id and slot -> the player's portrait texture.
static var _player_portraits: Dictionary[String, Texture2D] = {}


func _init() -> void:
	name = "ScenePanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_card.theme_type_variation = CARD_VARIATION
	_frame.theme_type_variation = FRAME_VARIATION
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP
	_portrait.size = PORTRAIT_SIZE
	_arrow.texture = ARROW_TEXTURE
	_arrow.size = ARROW_TEXTURE.get_size()
	# The kit's arrow is cream; on the light card it takes the card text's dark.
	_arrow.self_modulate = ARROW_TINT
	_drain.color = DRAIN_COLOR
	for node: Control in [_card, _frame, _portrait, _name, _text, _arrow, _key, _drain]:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(node)
	for label: Label in [_name, _text, _key]:
		label.theme_type_variation = TEXT_VARIATION
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_layout(1)


## Follows `session`'s capture scene, in its language.
func bind(session: CoopSession) -> void:
	_session = session
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
		# The hold the host keeps: of the Spanish text, whatever this peer reads.
		_hold_s = CaptureScene.hold_s(scene.current_text("es"))
		_portrait.texture = portrait_for(scene, _session)
		_fit()
	else:
		elapsed_s += delta
	_text.visible_characters = revealed_chars()
	var revealed: bool = revealed_chars() >= _text.text.length()
	var skips: bool = can_skip()
	var lit: bool = fposmod(elapsed_s, ARROW_ON_S + ARROW_OFF_S) < ARROW_ON_S
	_arrow.visible = skips and revealed and lit
	_key.visible = skips and revealed
	_key.text = KEY_FORMAT % InputLabels.label_for(INTERACT_ACTION, device, _hud_text, locale)
	_drain.visible = not skips
	_drain.size.x = roundf(TEXT_WIDTH * drain_fraction())


## The characters of the current line revealed now: 40 a second, all of them at the end.
func revealed_chars() -> int:
	return mini(floori(elapsed_s * CaptureScene.REVEAL_CHARS_PER_S), _text.text.length())


## True where a press of interact skips the line: solo and the host.
func can_skip() -> bool:
	return scene != null and scene.is_inside_tree() and scene.multiplayer.is_server()


## True while the advance arrow shows (it blinks once the line is all shown).
func arrow_shown() -> bool:
	return visible and _arrow.visible


## True while the interact key's label shows beside the arrow, and its text.
func key_shown() -> bool:
	return visible and _key.visible


func key_text() -> String:
	return _key.text


## The key's and the arrow's rectangles in the HUD.
func key_rect() -> Rect2:
	return Rect2(_key.position, _key.size)


func arrow_rect() -> Rect2:
	return Rect2(_arrow.position, _arrow.size)


## The colour the arrow is drawn in (its cream times this tint).
func arrow_tint() -> Color:
	return _arrow.self_modulate


## True while the client's drain bar shows, and how much of the line's hold is left, 1 to 0.
func drain_shown() -> bool:
	return visible and _drain.visible


func drain_fraction() -> float:
	if _hold_s <= 0.0:
		return 0.0
	return clampf(1.0 - elapsed_s / _hold_s, 0.0, 1.0)


## The hold the drain bar runs over (the host's, of the Spanish text).
func hold_s() -> float:
	return _hold_s


func shown_name() -> String:
	return _name.text


func shown_text() -> String:
	return _text.text


## The portrait on show (null without one).
func shown_portrait() -> Texture2D:
	return _portrait.texture


## The card's rectangle in the HUD (a test holds it inside the 640×360 view).
func card_rect() -> Rect2:
	return Rect2(_card.position, _card.size)


## The portrait frame's and the portrait's rectangles in the HUD.
func frame_rect() -> Rect2:
	return Rect2(_frame.position, _frame.size)


func portrait_rect() -> Rect2:
	return Rect2(_portrait.position, _portrait.size)


## The portrait for the scene's current line: the NPC's own (NpcData.portrait), or for a player's line
## that player's figure, frame 0 of its look's `idle_down`, its clothing in their slot's colours.
static func portrait_for(capture: CaptureScene, session: CoopSession) -> Texture2D:
	if capture == null:
		return null
	if capture.current_speaker_id == CaptureScene.PLAYER_SPEAKER:
		var body: PlayerBody = session.body(capture.current_speaker_peer) if session != null else null
		return player_portrait(body.look_slot) if body != null else null
	var npc := GameState.content.get_entry(&"npcs", capture.current_speaker_id) as NpcData
	return npc.portrait if npc != null else null


## A player's figure for a plea: the slot's look, frame 0 of `idle_down`, the key ramp swapped to the
## slot's row (row 0 of player_ramps.png is the key ramp, slot n's row n + 1). Cached per look and slot.
static func player_portrait(slot: int) -> Texture2D:
	var art: BodyArt = BodyArt.standard()
	var look: PlayerLookData = art.look_for_slot(slot)
	var key: String = "%s|%d" % [look.cache_key() if look != null else "", slot]
	if _player_portraits.has(key):
		return _player_portraits[key]
	var composed: ComposedLook = LookComposer.compose(look)
	var frame: Texture2D = composed.frames.get_frame_texture(&"idle_down", 0)
	if frame == null:
		return null
	var ramps: Image = ArtTuning.standard().player_ramps.get_image()
	var row: int = clampi(slot, 0, NetPeers.MAX_PLAYERS - 1) + 1
	var image: Image = PaletteSwap.swap_rows(frame.get_image(), ramps, PaletteSwap.KEY_ROW, row)
	var texture := ImageTexture.create_from_image(image)
	_player_portraits[key] = texture
	return texture


# The card fits the name and the wrapped text (measured with the theme's font: the label's own count
# is not laid out yet in the frame its text changes).
func _fit() -> void:
	_layout(clampi(wrap_count(_text.text), 1, MAX_LINES))


# The card: the name row, `lines` text lines and a cue row under them (the arrow and the key at its
# right, the drain bar along it), its bottom on BOTTOM, the frame and portrait at its left and the text
# to their right.
func _layout(lines: int) -> void:
	var height: float = maxf(PADDING.y * 2.0 + LINE_HEIGHT * (lines + 2) + 2.0, FRAME_SIZE.y + PADDING.y * 2.0)
	var top := Vector2(LEFT, BOTTOM - height)
	_card.position = top
	_card.size = Vector2(WIDTH, height)
	_frame.position = top + PADDING
	_frame.size = FRAME_SIZE
	_portrait.position = _frame.position + (FRAME_SIZE - PORTRAIT_SIZE) / 2.0
	_name.position = top + Vector2(TEXT_LEFT, PADDING.y)
	_name.size = Vector2(TEXT_WIDTH, LINE_HEIGHT)
	_text.position = top + Vector2(TEXT_LEFT, PADDING.y + LINE_HEIGHT + 2.0)
	_text.size = Vector2(TEXT_WIDTH, LINE_HEIGHT * lines)
	var bottom_right := Vector2(LEFT + WIDTH - PADDING.x, BOTTOM - PADDING.y)
	_arrow.position = bottom_right - _arrow.size - Vector2(0.0, 1.0)
	_key.size = Vector2(6.0 * HudStyle.GLYPH_PX, LINE_HEIGHT)
	_key.position = Vector2(_arrow.position.x - 2.0 - _key.size.x, bottom_right.y - LINE_HEIGHT)
	_drain.position = Vector2(top.x + TEXT_LEFT, BOTTOM - PADDING.y - LINE_HEIGHT / 2.0)
	_drain.size = Vector2(TEXT_WIDTH, 1.0)


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
	if not visible or scene == null or not event.is_action_pressed(INTERACT_ACTION):
		return
	if scene.is_inside_tree() and scene.multiplayer.is_server():
		scene.skip()
		get_viewport().set_input_as_handled()
