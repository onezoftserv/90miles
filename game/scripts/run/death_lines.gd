class_name DeathLines
extends RefCounted
## The death one-liners (endings-progression "Death one-liners"): the lines of the DEATH_LINES
## dialogue (game/resources/dialogue/death_one_liners.tres), one state per cause id. A cause picks
## its line from the run seed: (run seed + n) modulo the cause's line count, where n counts the
## players before it with the same cause, so every peer shows the same line. A cause with no lines
## uses the `other` lines. Changing a line is a content edit, not a code edit.

const CONTENT_TYPE: StringName = &"dialogue"
const CONTENT_ID: StringName = &"death_one_liners"

## State (cause id) to its lines in file order. The values are Array[DialogueLineData].
var _by_cause: Dictionary = {}


## The lines of the death-lines content in `catalog`, or none if it is missing.
static func from_catalog(catalog: ContentCatalog) -> DeathLines:
	if catalog == null:
		return DeathLines.new()
	return from_dialogue(catalog.get_entry(CONTENT_TYPE, CONTENT_ID) as DialogueData)


## Every state of `data` keyed by its cause, with the lines that are not null.
static func from_dialogue(data: DialogueData) -> DeathLines:
	var lines := DeathLines.new()
	if data == null:
		return lines
	for state: DialogueStateData in data.states:
		if state == null:
			continue
		var found: Array[DialogueLineData] = lines._by_cause.get(state.state, [] as Array[DialogueLineData])
		for line: DialogueLineData in state.lines:
			if line != null:
				found.append(line)
		lines._by_cause[state.state] = found
	return lines


## How many lines `cause` has of its own.
func count(cause: StringName) -> int:
	var found: Array[DialogueLineData] = _by_cause.get(cause, [] as Array[DialogueLineData])
	return found.size()


## The line the `nth` player (from 0) with `cause` gets under `run_seed`, or null with no content.
func line_for(cause: StringName, run_seed: int, nth: int) -> DialogueLineData:
	var picked: StringName = cause if count(cause) > 0 else DeathCause.OTHER
	var found: Array[DialogueLineData] = _by_cause.get(picked, [] as Array[DialogueLineData])
	if found.is_empty():
		return null
	return found[posmod(run_seed + nth, found.size())]


## The text of `line` in `locale` (English falls back to Spanish). `soft` asks for the clean
## variant, which falls back to the normal text; null gives "".
static func text(line: DialogueLineData, locale: String = "es", soft: bool = false) -> String:
	if line == null:
		return ""
	var english: bool = locale.begins_with("en") and not line.text_en.is_empty()
	var normal: String = line.text_en if english else line.text_es
	var clean: String = line.text_en_soft if english else line.text_es_soft
	return clean if soft and not clean.is_empty() else normal
