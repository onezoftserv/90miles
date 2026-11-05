class_name QuickChatPhrases
extends RefCounted
## The quick-chat wheel's phrases (coop-networking "Quick chat"): the lines of state
## `quick_chat` in the QUICK_CHAT dialogue content (game/resources/dialogue/quick_chat.tres),
## in wheel order, clockwise from north. Changing a phrase is a content edit, not a code edit.

const CONTENT_TYPE: StringName = &"dialogue"
const CONTENT_ID: StringName = &"quick_chat"
const STATE: StringName = &"quick_chat"
const SLOTS: int = 8
## Voice clips are named after the line id (recorded in Milestone G).
const VOICE_DIR: String = "res://assets/audio/voice/"
const VOICE_EXTENSION: String = "ogg"

var _lines: Array[DialogueLineData] = []


## The phrases of the quick-chat content in `catalog`, or none if it is missing.
static func from_catalog(catalog: ContentCatalog) -> QuickChatPhrases:
	if catalog == null:
		return QuickChatPhrases.new()
	return from_dialogue(catalog.get_entry(CONTENT_TYPE, CONTENT_ID) as DialogueData)


## The first SLOTS lines of state `quick_chat` in `data`.
static func from_dialogue(data: DialogueData) -> QuickChatPhrases:
	var phrases := QuickChatPhrases.new()
	if data == null:
		return phrases
	for state: DialogueStateData in data.states:
		if state != null and state.state == STATE:
			for line: DialogueLineData in state.lines:
				if line != null and phrases._lines.size() < SLOTS:
					phrases._lines.append(line)
			break
	return phrases


func size() -> int:
	return _lines.size()


## The phrase in `locale` ("es" first; English falls back to Spanish), or "" for no phrase.
func text(slot: int, locale: String = "es") -> String:
	var line := _line(slot)
	if line == null:
		return ""
	if locale.begins_with("en") and not line.text_en.is_empty():
		return line.text_en
	return line.text_es


func line_id(slot: int) -> StringName:
	var line := _line(slot)
	return line.id if line != null else &""


## Where the phrase's voice clip lives (it may not exist yet).
func voice_path(slot: int) -> String:
	var id := line_id(slot)
	if id.is_empty():
		return ""
	return VOICE_DIR.path_join("%s.%s" % [id, VOICE_EXTENSION])


## The phrase's voice clip, or null while none has been recorded.
func voice(slot: int) -> AudioStream:
	var path := voice_path(slot)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


func _line(slot: int) -> DialogueLineData:
	if slot < 0 or slot >= _lines.size():
		return null
	return _lines[slot]
