class_name TextEntryData
extends DataPart
## One page or variant of a found text, embedded in TextData.entries (game/resources/items/).
## Spanish first, with soft-profanity versions for the settings toggle. The id is local to the
## text. No references. Sources: CHARACTERS.md found texts, GAME_DESIGN.md section 15.

## Unique within the text; also the voice-clip key.
@export var id: StringName = &""
## Date, station or title in Spanish.
@export var heading_es: String = ""
## English heading.
@export var heading_en: String = ""
## Spanish body.
@export_multiline var body_es: String = ""
## English body; keeps key slang untranslated.
@export_multiline var body_en: String = ""
## Spanish body when profanity is softened; empty means body_es is already clean.
@export_multiline var body_es_soft: String = ""
## English body when profanity is softened; empty means body_en is already clean.
@export_multiline var body_en_soft: String = ""
## Variant tag (joke, prayer, shopping_list, curse, radio_marti...).
@export var tone: StringName = &""
## Weight when the text's pick_mode is RANDOM_ONE.
@export var weight: float = 1.0
## The entry is eligible only when all hold.
@export var conditions: Array[ConditionData] = []
