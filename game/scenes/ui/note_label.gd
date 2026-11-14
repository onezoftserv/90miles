class_name NoteLabel
extends PanelContainer
## The note on the HUD until the reading panel exists (secret-cay "Note on the HUD until the
## reading panel", "Map hint"; design.md decision 8): a HUD panel top-centre under the needle's
## place, 360 px wide, its text word-wrapped, shown for the tuning's base time plus a time per
## character, then hidden. It is a HudPanel, so the interact prompt keeps clear of it. The chest
## and the hunt reach every peer's label through `show_in`, each in that peer's language.

## A text went up on this label.
signal shown(text: String)

const GROUP: StringName = &"note_labels"
const POSITION: Vector2 = Vector2(140.0, 46.0)
const WIDTH: float = 360.0

var tuning: SecretTuning = SecretTuning.standard()
## The session whose run this HUD shows, or null.
var session: CoopSession = null
## Seconds the current text stays up.
var time_left_s: float = 0.0

@onready var label: Label = $Text


## Shows `text_es` or `text_en` on the note label of every HUD bound to `run_session`, in that
## HUD's language (Spanish unless English is set).
static func show_in(run_session: CoopSession, text_es: String, text_en: String) -> void:
	if run_session == null or not run_session.is_inside_tree():
		return
	var english: bool = CoopSession.locale_of(run_session).begins_with("en")
	var text: String = text_en if english and not text_en.is_empty() else text_es
	for node: Node in run_session.get_tree().get_nodes_in_group(GROUP):
		var note := node as NoteLabel
		if note != null and note.session == run_session:
			note.show_text(text)


func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	position = POSITION
	custom_minimum_size = Vector2(WIDTH, 0.0)
	size = Vector2(WIDTH, 0.0)
	visible = false


## Follows `run_session` from now on.
func bind(run_session: CoopSession) -> void:
	session = run_session


## Shows `text` for note_base_s + note_per_char_s per character.
func show_text(text: String) -> void:
	label.text = text
	time_left_s = tuning.note_base_s + tuning.note_per_char_s * text.length()
	visible = true
	# The label wraps at the panel's inner width, so it is measured at that width before the panel
	# fits its height round it.
	label.size = Vector2(WIDTH - get_theme_stylebox(&"panel").get_minimum_size().x, label.size.y)
	label.update_minimum_size()
	update_minimum_size()
	size = Vector2(WIDTH, get_combined_minimum_size().y)
	position = POSITION
	shown.emit(text)


## The text on show, or "" while hidden.
func shown_text() -> String:
	return label.text if visible else ""


func _process(delta: float) -> void:
	step(delta)


## Counts the text's time down by `delta` and hides it when it runs out.
func step(delta: float) -> void:
	if not visible:
		return
	time_left_s -= delta
	if time_left_s <= 0.0:
		time_left_s = 0.0
		visible = false
