extends GutTest
## coop-networking "Quick chat": the 8 phrases are content (dialogue/quick_chat.tres, a
## QUICK_CHAT dialogue), read in wheel order.

const SPANISH: Array[String] = [
	"¡Dale!", "¡Agua!", "¡Pa'llá no!", "¡Tiburón!", "¡Patrulla!", "¡Ayuda!", "¡Comida aquí!", "¡Vámonos!",
]
const ENGLISH: Array[String] = [
	"¡Dale!", "Water!", "Not that way!", "Shark!", "Patrol!", "Help!", "Food here!", "¡Vámonos!",
]
const IDS: Array[StringName] = [
	&"quick_chat_dale", &"quick_chat_agua", &"quick_chat_palla_no", &"quick_chat_tiburon",
	&"quick_chat_patrulla", &"quick_chat_ayuda", &"quick_chat_comida_aqui", &"quick_chat_vamonos",
]
const FILE := "res://resources/dialogue/quick_chat.tres"


func _phrases() -> QuickChatPhrases:
	return QuickChatPhrases.from_catalog(ContentCatalog.new())


func test_the_file_is_a_quick_chat_dialogue_named_after_itself() -> void:
	var data := load(FILE) as DialogueData
	assert_not_null(data, "quick_chat.tres loads as DialogueData")
	if data == null:
		return
	assert_eq(data.id, &"quick_chat")
	assert_eq(data.kind, DialogueData.Kind.QUICK_CHAT)


func test_eight_phrases_in_spanish_in_wheel_order() -> void:
	var phrases := _phrases()
	assert_eq(phrases.size(), QuickChatPhrases.SLOTS)
	var texts: Array[String] = []
	for slot: int in phrases.size():
		texts.append(phrases.text(slot))
	assert_eq(texts, SPANISH)


func test_english_keeps_the_slang() -> void:
	var phrases := _phrases()
	var texts: Array[String] = []
	for slot: int in phrases.size():
		texts.append(phrases.text(slot, "en"))
	assert_eq(texts, ENGLISH)


func test_line_ids_name_the_voice_clips() -> void:
	var phrases := _phrases()
	var ids: Array[StringName] = []
	for slot: int in phrases.size():
		ids.append(phrases.line_id(slot))
	assert_eq(ids, IDS)
	assert_eq(phrases.voice_path(3), "res://assets/audio/voice/quick_chat_tiburon.ogg")


func test_no_voice_clips_exist_yet() -> void:
	var phrases := _phrases()
	for slot: int in phrases.size():
		assert_null(phrases.voice(slot), "voice lines arrive with Milestone G")


func test_the_content_validates() -> void:
	assert_eq(ContentValidator.validate(ContentCatalog.new()), PackedStringArray())


func test_out_of_range_slots_are_empty() -> void:
	var phrases := _phrases()
	assert_eq(phrases.text(-1), "")
	assert_eq(phrases.text(8), "")
	assert_eq(phrases.line_id(99), &"")
	assert_null(phrases.voice(-1))


func test_a_dialogue_without_the_quick_chat_state_has_no_phrases() -> void:
	var data := DialogueData.new()
	data.kind = DialogueData.Kind.QUICK_CHAT
	assert_eq(QuickChatPhrases.from_dialogue(data).size(), 0)
	assert_eq(QuickChatPhrases.from_dialogue(null).size(), 0)


func test_english_falls_back_to_spanish() -> void:
	var line := DialogueLineData.new()
	line.id = &"quick_chat_test"
	line.text_es = "¡Oye!"
	var state := DialogueStateData.new()
	state.state = QuickChatPhrases.STATE
	state.lines = [line] as Array[DialogueLineData]
	var data := DialogueData.new()
	data.states = [state] as Array[DialogueStateData]
	assert_eq(QuickChatPhrases.from_dialogue(data).text(0, "en"), "¡Oye!")
