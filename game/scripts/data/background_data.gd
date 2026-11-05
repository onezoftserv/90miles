class_name BackgroundData
extends ContentData
## A player class picked at run start: starting items, own skills, perks and passive modifiers.
## Files live in game/resources/backgrounds/. Sources: GAME_DESIGN §10 and §14.
## Relations other content reads stay on the acting side (CreatureCounterData, ItemData,
## EffectData conditions, NpcData.background_trust_mult), not here.

## Character-select text.
@export_multiline var description_es: String = ""
## English character-select text.
@export_multiline var description_en: String = ""
## Skill line, e.g. 'Pesca: capturas más rápidas, lee la marea'.
@export var skill_summary_es: String = ""
## English skill line, e.g. 'Fishing: faster catches, reads the tide'.
@export var skill_summary_en: String = ""

## Character-select portrait (asset).
@export var portrait: Texture2D = null
## 32×32 frames if the look differs from the default (asset).
@export var sprite_frames: SpriteFrames = null

## Own skills, capped at skill_cap; the others cap at 3 (global rule). Ex-militar has two.
@export var skills: Array[DataEnums.Skill] = []
## Level cap for the own skills.
@export var skill_cap: int = 5
## Own skill level before carry-over (TBD).
@export var starting_skill_level: int = 0
## Item id -> count at run start.
@export var starting_items: Dictionary[StringName, int] = {}
## Yes/no abilities. A keepsake can grant one too.
@export var perks: Array[DataEnums.Perk] = []
## Passive bonuses (build ×2, catch interval 10 s, healing, text finding, noise, melee).
@export var modifiers: Array[ModifierData] = []


func get_reference_fields() -> Dictionary[StringName, StringName]:
	return {
		&"starting_items": &"items",
	}
