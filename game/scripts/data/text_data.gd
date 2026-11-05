class_name TextData
extends ItemData
## A found text ("found texts SHALL be items"), saved flat in game/resources/items/. Opens a
## reading panel with handwritten pages (HW content or AI fallbacks); reading is built in, so uses
## stays empty and content sets category and tags TEXT. The id is the text_id for POST /dialogue.
## Sources: npcs-dialogue spec, CHARACTERS.md found texts.

## Reading-panel style.
enum Presentation {
	NOTEBOOK,
	DIARY,
	LETTER,
	WALL,
	NOTE,
	RADIO,
	BOARD,
	LOGBOOK,
}

## Who writes the text.
enum Generation {
	HANDWRITTEN,
	AI,
}

## Run facts DialogueService puts in an AI text's context.
enum ContextFocus {
	RUN_HISTORY,
	PARTY_HUNGER,
	ROUTE_TAKEN,
	PREVIOUS_RUN_DEAD,
	PLAYER_NOTE,
	RANDOM_TONE,
}

## How entries are chosen when the text is read.
enum PickMode {
	RANDOM_ONE,
	NEXT_UNREAD,
	ALL_IN_ORDER,
}

@export_group("Reading")
## Reading-panel style.
@export var presentation: Presentation = Presentation.NOTE
## How entries are chosen when read.
@export var pick_mode: PickMode = PickMode.RANDOM_ONE
## Handwritten pages: the HW content or the AI fallbacks.
@export var entries: Array[TextEntryData] = []
## Morale on the first read; later reads give nothing.
@export var morale_on_first_read: int = 10
## Extra effects on reading, each gated by its own conditions (patrol logbook hint with Tania).
@export var read_effects: Array[EffectData] = []

@export_group("AI")
## HANDWRITTEN, or AI (calls DialogueService in mode text, entries are the fallbacks).
@export var generation: Generation = Generation.HANDWRITTEN
## Text profile path relative to backend/prompts/ (outside res://, so a plain String).
@export var ai_profile_path: String = ""
## Run facts DialogueService puts in the context.
@export var ai_context: Array[ContextFocus] = []

@export_group("Placement")
## Fills the island's single important-text slot.
@export var important: bool = false
## Earliest island index (1-based).
@export var min_island: int = 1
## Max copies per run; 0 means unlimited.
@export var max_per_run: int = 1
## All must hold for the text to be placed or offered.
@export var spawn_conditions: Array[ConditionData] = []
