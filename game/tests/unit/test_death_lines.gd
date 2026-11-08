extends GutTest
## endings-progression "Death one-liners" and "One-liner picked by the run seed": the 20 draft
## lines are content (game/resources/dialogue/death_one_liners.tres), and DeathLines picks one by
## (run seed + n) modulo the cause's line count. Solo and co-op read the same lines.

const PATH: String = "res://resources/dialogue/death_one_liners.tres"
const EXPECTED_COUNTS: Dictionary = {
	&"thirst": 4, &"drowning": 4, &"reef_shark": 4, &"land_crab": 2, &"removed": 3, &"other": 3,
}
const MAX_CHARACTERS: int = 120
## Words a soft variant must not contain; a line that has one needs a soft text.
const SWEARS: Array[String] = ["coño", "cojones", "carajo", "pinga", "mierda", "singao", "cabrón", "me cago"]

var _lines: DeathLines


func before_each() -> void:
	_lines = DeathLines.from_catalog(GameState.content)


func _data() -> DialogueData:
	return load(PATH) as DialogueData


func _all_lines() -> Array[DialogueLineData]:
	var found: Array[DialogueLineData] = []
	for state: DialogueStateData in _data().states:
		for line: DialogueLineData in state.lines:
			found.append(line)
	return found


func _id_of(line: DialogueLineData) -> StringName:
	return line.id if line != null else &""


func test_the_file_is_a_death_lines_dialogue_named_after_itself() -> void:
	var data := _data()
	assert_not_null(data)
	assert_eq(data.id, &"death_one_liners")
	assert_eq(data.kind, DialogueData.Kind.DEATH_LINES)


func test_twenty_lines_split_by_cause() -> void:
	var counts: Dictionary = {}
	for state: DialogueStateData in _data().states:
		counts[state.state] = state.lines.size()
	assert_eq(counts, EXPECTED_COUNTS)
	assert_eq(_all_lines().size(), 20)


func test_every_line_is_spanish_and_english_within_120_characters() -> void:
	for line: DialogueLineData in _all_lines():
		for text: String in [line.text_es, line.text_en]:
			assert_gt(text.length(), 0, "%s has its text" % line.id)
			assert_lte(text.length(), MAX_CHARACTERS, "%s fits" % line.id)
		for soft: String in [line.text_es_soft, line.text_en_soft]:
			assert_lte(soft.length(), MAX_CHARACTERS, "%s soft fits" % line.id)


func test_line_ids_name_the_cause_and_count_from_1() -> void:
	var seen: Dictionary = {}
	for state: DialogueStateData in _data().states:
		var n: int = 1
		for line: DialogueLineData in state.lines:
			assert_eq(line.id, StringName("death_%s_%d" % [state.state, n]))
			assert_eq(line.speaker_id, &"narrator")
			assert_false(seen.has(line.id), "%s is unique" % line.id)
			seen[line.id] = true
			n += 1


func _swears(text: String) -> bool:
	var lowered: String = text.to_lower()
	for word: String in SWEARS:
		if lowered.contains(word):
			return true
	return false


func test_lines_that_swear_have_a_clean_soft_variant() -> void:
	var swearing: int = 0
	for line: DialogueLineData in _all_lines():
		if _swears(line.text_es):
			swearing += 1
			assert_gt(line.text_es_soft.length(), 0, "%s has a soft Spanish text" % line.id)
			assert_false(_swears(line.text_es_soft), "%s soft Spanish is clean" % line.id)
		if _swears(line.text_en):
			assert_gt(line.text_en_soft.length(), 0, "%s has a soft English text" % line.id)
			assert_false(_swears(line.text_en_soft), "%s soft English is clean" % line.id)
	assert_gt(swearing, 0, "the check has something to check")


func test_every_state_is_a_cause() -> void:
	for state: DialogueStateData in _data().states:
		var known: bool = DeathCause.FIXED.has(state.state) or GameState.content.has_entry(&"creatures", state.state)
		assert_true(known, "%s is a cause" % state.state)
	var causes: Array[StringName] = []
	causes.append_array(DeathCause.FIXED)
	causes.append(&"reef_shark")
	causes.append(&"land_crab")
	for cause: StringName in causes:
		assert_gte(_lines.count(cause), 2, "%s has lines" % cause)


func test_the_content_validates() -> void:
	assert_eq(ContentValidator.validate(ContentCatalog.new()), PackedStringArray())


func test_the_seed_picks_the_line() -> void:
	assert_eq(_id_of(_lines.line_for(&"thirst", 0, 0)), &"death_thirst_1")
	assert_eq(_id_of(_lines.line_for(&"thirst", 5, 0)), &"death_thirst_2")
	assert_eq(_id_of(_lines.line_for(&"thirst", 0, 1)), &"death_thirst_2")
	assert_eq(_id_of(_lines.line_for(&"thirst", -1, 0)), &"death_thirst_4")
	assert_eq(_id_of(_lines.line_for(&"thirst", 4, 0)), &"death_thirst_1")


func test_a_cause_without_lines_uses_the_other_lines() -> void:
	assert_eq(_id_of(_lines.line_for(&"barracuda", 0, 0)), &"death_other_1")
	assert_eq(_id_of(_lines.line_for(&"barracuda", 4, 0)), &"death_other_2")


func test_text_follows_locale_and_soft() -> void:
	var swearing := _lines.line_for(&"drowning", 3, 0)
	assert_eq(swearing.id, &"death_drowning_4")
	assert_eq(DeathLines.text(swearing, "es"), swearing.text_es)
	assert_eq(DeathLines.text(swearing, "en"), swearing.text_en)
	assert_eq(DeathLines.text(swearing, "es", true), swearing.text_es_soft)
	assert_ne(swearing.text_es_soft, swearing.text_es)
	var clean := _lines.line_for(&"thirst", 0, 0)
	assert_eq(clean.id, &"death_thirst_1")
	assert_eq(DeathLines.text(clean, "es", true), clean.text_es, "no soft text: the normal one")


func test_no_content_gives_no_line() -> void:
	assert_null(DeathLines.from_dialogue(null).line_for(&"thirst", 0, 0))
	assert_eq(DeathLines.text(null), "")
